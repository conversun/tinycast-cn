import Foundation
import Observation

@main
@MainActor
struct UpdateCheckTests {
    static var failures = 0
    static var passes = 0

    static func main() async throws {
        try await stopsBeforeFirstCheck()
        try await cancelsAndRestarts()
        try await checksCNRevisionAndReopensCache()
        try reportsInstalledVersionOnce()
        print("\(passes) passed, \(failures) failed")
        if failures > 0 { exit(1) }
    }

    static func stopsBeforeFirstCheck() async throws {
        let file = makeFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let fixture = FetchFixture()
        let store = makeStore(file: file, fixture: fixture)
        store.onUpdateAvailable = { _ in
            fixture.offers += 1
            return true
        }

        store.start(after: .milliseconds(10))
        store.stop()
        try await Task.sleep(for: .milliseconds(30))
        expect(fixture.requests == 0, "disabling during the startup delay makes no request")
        expect(fixture.offers == 0, "a stopped checker offers no update")
        expect(!FileManager.default.fileExists(atPath: file.path), "stopping creates no cache")
    }

    static func cancelsAndRestarts() async throws {
        let file = makeFile()
        defer { try? FileManager.default.removeItem(at: file) }
        try seedCache(at: file)
        let originalCache = try Data(contentsOf: file)
        let fixture = FetchFixture()
        let store = makeStore(file: file, fixture: fixture)
        store.onUpdateAvailable = { _ in
            fixture.offers += 1
            return true
        }
        defer { store.stop() }

        let firstRequest = StateWait { fixture.requests == 1 }
        store.start(after: .zero)
        try await firstRequest.wait()
        expect(store.isChecking, "the automatic check is in flight")
        let cancelledCheck = StateWait { !store.isChecking }
        store.stop()
        fixture.respond(feed(version: "1.2.0-cn.1"))
        try await cancelledCheck.wait()
        expect(fixture.wasCancelled, "stopping cancels the in-flight automatic check")
        expect(store.latest?.version == AppVersion("1.1.0-cn.1"), "a cancelled response is discarded")
        expect(fixture.offers == 0, "cancellation cannot announce the cached pending update")
        expect(try Data(contentsOf: file) == originalCache, "a cancelled check leaves the cache intact")

        let restartedRequest = StateWait { fixture.requests == 2 }
        store.start(after: .zero)
        try await restartedRequest.wait()
        let announcement = StateWait { fixture.offers == 1 }
        fixture.respond(feed(version: "1.2.0-cn.1"))
        try await announcement.wait()
        expect(!fixture.wasCancelled, "re-enabling starts a fresh check")
        expect(store.update?.version == AppVersion("1.2.0-cn.1"), "the restarted check adopts the release")
        store.start(after: .zero)
        try await Task.sleep(for: .milliseconds(10))
        expect(fixture.requests == 2, "restarting respects the cached check time")
        expect(fixture.offers == 1, "restarting never repeats an announcement already shown")

        store.stop()
        let manualRequest = StateWait { fixture.requests == 3 }
        let manual = Task { await store.check() }
        try await manualRequest.wait()
        let manualCompletion = StateWait { !store.isChecking }
        store.stop()
        fixture.respond(feed(version: "1.3.0-cn.1"))
        try await manualCompletion.wait()
        let answered = await manual.value
        expect(answered, "manual checking still works with automatic checking stopped")
        expect(!fixture.wasCancelled, "stopping the pump does not cancel a manual check")
        expect(store.update?.version == AppVersion("1.3.0-cn.1"), "manual checking receives a newer release")
        expect(fixture.offers == 1, "manual checking does not restart automatic announcements")

        let reopened = makeStore(file: file, fixture: fixture)
        expect(reopened.latest == store.latest, "manual checking persists the release")
    }

    static func checksCNRevisionAndReopensCache() async throws {
        let file = makeFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let fixture = FetchFixture()
        let running = AppVersion("1.3.0-cn.1")
        let store = makeStore(file: file, fixture: fixture, runningVersion: running)
        store.onUpdateAvailable = { _ in
            fixture.offers += 1
            return true
        }
        defer { store.stop() }

        let request = StateWait { fixture.requests == 1 }
        let manual = Task { await store.check() }
        try await request.wait()
        let completion = StateWait { !store.isChecking }
        fixture.respond(feed(version: "1.3.0-cn.2"))
        try await completion.wait()
        let answered = await manual.value
        expect(answered, "manual checking answers for a same-upstream CN revision")
        expect(store.update?.version == AppVersion("1.3.0-cn.2"), "a higher CN revision is an update")
        expect(store.update?.version.cnRevision == 2, "the offered update retains its CN revision")
        expect(store.update?.version.isPrerelease == false, "the CN stable update is not a beta")
        expect(store.channel == .stable, "the CN bundle selects the stable channel")
        expect(fixture.offers == 0, "a manual CN revision check makes no automatic announcement")
        expect(store.lastCheckedAt != nil, "the CN revision check records its check time")

        let reopened = makeStore(file: file, fixture: fixture, runningVersion: running)
        expect(reopened.latest == store.latest, "the CN revision release survives a cache roundtrip")
        expect(reopened.update == store.update, "the cached CN revision is still offered as newer")
        expect(reopened.lastCheckedAt == store.lastCheckedAt, "the cache preserves CN check freshness")
        expect(reopened.channel == .stable, "the reopened CN store stays on the stable channel")
        expect(reopened.latest?.version.isPrerelease == false, "the cached CN release stays stable")
        let cache = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any]
        let latest = cache?["latest"] as? [String: Any]
        expect(latest?["version"] as? String == "1.3.0-cn.2", "the cache encodes the CN version")
        expect(latest?["tag"] as? String == "v1.3.0-cn.2", "the cache preserves the CN release tag")
        expect(fixture.requests == 1, "reopening the CN cache makes no additional request")
    }

    static func reportsInstalledVersionOnce() throws {
        let file = makeFile()
        defer { try? FileManager.default.removeItem(at: file) }
        try seedCache(at: file)
        let fixture = FetchFixture()
        guard let installed = AppVersion("1.1.0-cn.1") else { fatalError("the fixture version must parse") }

        makeStore(file: file, fixture: fixture).recordInstall(of: installed)
        let relaunched = makeStore(file: file, fixture: fixture, runningVersion: installed)
        expect(relaunched.latest?.version == installed, "recording an install keeps the cached release")
        expect(
            relaunched.takeInstalledVersion() == installed, "the installed version's first launch reports it")
        expect(relaunched.takeInstalledVersion() == nil, "the report is taken once")
        let later = makeStore(file: file, fixture: fixture, runningVersion: installed)
        expect(later.takeInstalledVersion() == nil, "a later launch reports nothing")

        makeStore(file: file, fixture: fixture).recordInstall(of: installed)
        let unchanged = makeStore(file: file, fixture: fixture)
        expect(unchanged.takeInstalledVersion() == nil, "a launch of another version reports nothing")
        let afterwards = makeStore(file: file, fixture: fixture, runningVersion: installed)
        expect(afterwards.takeInstalledVersion() == nil, "and clears the record")
    }

    static func seedCache(at file: URL) throws {
        guard
            let release = ReleaseFeed.newest(
                from: feed(version: "1.1.0-cn.1"), channel: .stable, architecture: .current)
        else { fatalError("the fixture release must be installable") }
        let cache: [String: Any] = [
            "lastCheckedAt": Date.distantPast.timeIntervalSinceReferenceDate,
            "latest": try JSONSerialization.jsonObject(with: JSONEncoder().encode(release))
        ]
        try JSONSerialization.data(withJSONObject: cache).write(to: file)
    }

    static func makeStore(
        file: URL, fixture: FetchFixture, runningVersion: AppVersion? = AppVersion("1.0.0-cn.1")
    ) -> UpdateCheckStore {
        UpdateCheckStore(
            channel: ReleaseChannel(bundleID: "com.conversun.tinycast-cn"),
            runningVersion: runningVersion, fileURL: file,
            fetch: { await fixture.fetch() })
    }

    static func makeFile() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("update-check-test-\(UUID().uuidString).json")
    }

    static func feed(version: String) -> Data {
        Data(
            """
            [{"tag_name":"v\(version)","prerelease":false,"draft":false,"assets":[
                {"name":"Tinycast-CN-Universal-\(version).zip","size":100,
                 "browser_download_url":"https://example.com/update.zip"}
            ]}]
            """.utf8)
    }

    static func expect(_ condition: Bool, _ message: String) {
        if condition {
            passes += 1
        } else {
            failures += 1
            print("FAIL: \(message)")
        }
    }

    @MainActor
    final class StateWait {
        enum Failure: Error { case timedOut }

        private let condition: () -> Bool
        private var continuation: CheckedContinuation<Void, any Error>?
        private var result: Bool?
        private var timeout: Task<Void, Never>?

        init(_ condition: @escaping () -> Bool) {
            self.condition = condition
            track()
            if result == nil {
                timeout = Task { [weak self] in
                    do { try await Task.sleep(for: .seconds(2)) } catch { return }
                    self?.finish(false)
                }
            }
        }

        private func track() {
            guard result == nil else { return }
            let ready = withObservationTracking {
                condition()
            } onChange: { [weak self] in
                Task { @MainActor in self?.track() }
            }
            if ready { finish(true) }
        }

        private func finish(_ ready: Bool) {
            guard result == nil else { return }
            result = ready
            timeout?.cancel()
            timeout = nil
            if ready {
                continuation?.resume()
            } else {
                continuation?.resume(throwing: Failure.timedOut)
            }
            continuation = nil
        }

        func wait() async throws {
            if let result {
                guard result else { throw Failure.timedOut }
                return
            }
            try await withCheckedThrowingContinuation { continuation = $0 }
        }
    }

    @MainActor
    @Observable
    final class FetchFixture {
        var requests = 0
        var offers = 0
        var wasCancelled = false
        @ObservationIgnored
        private var response: CheckedContinuation<Data?, Never>?

        func fetch() async -> Data? {
            requests += 1
            let data = await withCheckedContinuation { response = $0 }
            wasCancelled = Task.isCancelled
            return data
        }

        func respond(_ data: Data) {
            let pending = response
            response = nil
            pending?.resume(returning: data)
        }
    }
}
