import Foundation
import Observation

actor FileSearchProbe {
    private var active = 0
    private var calls: [String] = []
    private var maximumActive = 0
    private let pausedQuery: String?
    private var pauseEnabled: Bool
    private var pausedContinuation: CheckedContinuation<Void, Never>?
    private let paused = AsyncStream<Void>.makeStream()

    init(pausing query: String? = nil) {
        pausedQuery = query
        pauseEnabled = query != nil
    }

    func search(query: String, filter: FileSearchFilter) async -> [FileSearchResult] {
        active += 1
        calls.append(filter == .all ? query : "\(query) [\(filter.title)]")
        maximumActive = max(maximumActive, active)
        if pauseEnabled, query == pausedQuery {
            await withCheckedContinuation { continuation in
                pausedContinuation = continuation
                paused.continuation.yield()
            }
        }
        active -= 1
        let home = URL(fileURLWithPath: "/Users/test")
        return [FileSearchResult(url: home.appending(path: query), isDirectory: false, homeDirectory: home)]
    }

    func snapshot() -> (calls: [String], maximumActive: Int) {
        (calls, maximumActive)
    }

    func waitUntilPaused() async -> Bool {
        var iterator = paused.stream.makeAsyncIterator()
        return await iterator.next() != nil
    }

    func resumePausedSearch() {
        pauseEnabled = false
        pausedContinuation?.resume()
        pausedContinuation = nil
    }
}

@main
@MainActor
struct FileSearchSessionTests {
    nonisolated(unsafe) static var failures = 0
    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() {
            failures += 1
            print("FAIL: \(message)")
        }
    }

    static func main() async {
        let timeout = Task {
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled else { return }
            print("FAIL: the async operation completed before the timeout")
            exit(1)
        }
        defer { timeout.cancel() }
        await coalescesQueuedQueries()
        await serializesRunningQueries()
        await cancellationPreventsPendingWork()
        await idleCancellationKeepsTheSessionUsable()
        await refreshRerunsThePublishedQuery()
        await blankScreenOpensOnKeptRecents()
        await recentRefreshLeavesTheOpenListAlone()
        await blankQueryLoadsRecents()
        await filterChangeRerunsTheQuery()

        print(failures == 0 ? "File search session tests passed" : "\(failures) tests failed")
        exit(failures == 0 ? 0 : 1)
    }

    static func coalescesQueuedQueries() async {
        let probe = FileSearchProbe(pausing: "a")
        let session = makeSession(probe: probe)
        session.search("a")
        guard await probe.waitUntilPaused() else { return expect(false, "the first query starts") }
        session.search("an")
        session.search("annual")
        await waitUntil({ session.state == .ready && session.results.first?.name == "annual" }) {
            await probe.resumePausedSearch()
        }

        let snapshot = await probe.snapshot()
        expect(snapshot.calls == ["a", "annual"], "keystrokes queued behind a search collapse")
    }

    static func serializesRunningQueries() async {
        let probe = FileSearchProbe(pausing: "first")
        let session = makeSession(probe: probe)
        session.search("first")
        let firstStarted = await probe.waitUntilPaused()
        expect(firstStarted, "the first query starts")
        guard firstStarted else { return }
        session.search("second")
        await waitUntil({ session.state == .ready && session.results.first?.name == "second" }) {
            await probe.resumePausedSearch()
        }

        let snapshot = await probe.snapshot()
        expect(snapshot.calls == ["first", "second"], "the superseding query still runs")
        expect(snapshot.maximumActive == 1, "searches never overlap")
    }

    static func cancellationPreventsPendingWork() async {
        let probe = FileSearchProbe(pausing: "running")
        let session = makeSession(probe: probe)
        session.search("running")
        guard await probe.waitUntilPaused() else { return expect(false, "the query starts") }
        session.search("queued")
        let cancelled = session.cancel()
        await probe.resumePausedSearch()
        await cancelled?.value

        let snapshot = await probe.snapshot()
        expect(snapshot.calls == ["running"], "cancelling drops the queued search")
        expect(session.state == .idle && session.results.isEmpty, "cancellation clears the session")
    }

    static func idleCancellationKeepsTheSessionUsable() async {
        let probe = FileSearchProbe()
        let session = makeSession(probe: probe)
        session.cancel()
        expect(session.state == .idle && session.results.isEmpty, "an idle cancel changes nothing")
        await waitUntil({ session.state == .ready && session.results.first?.name == "report" }) {
            session.search("report")
        }
        session.cancel()
        session.cancel()
        expect(session.state == .idle && session.results.isEmpty, "a repeated cancel stays idle")
        await waitUntil({ session.state == .ready && session.results.first?.name == "report" }) {
            session.search("report")
        }

        let snapshot = await probe.snapshot()
        expect(snapshot.calls == ["report", "report"], "a cancelled query runs again when retyped")
    }

    static func refreshRerunsThePublishedQuery() async {
        let probe = FileSearchProbe(pausing: "")
        let session = makeSession(probe: probe)
        let prepared = session.refresh()
        guard await probe.waitUntilPaused() else { return expect(false, "the recent query starts") }
        await waitUntil({ session.state == .ready }) {
            session.search("report")
            await probe.resumePausedSearch()
        }
        await prepared?.value
        var refreshed: Task<Void, Never>?
        await waitUntil({ session.state == .ready }) {
            refreshed = session.refresh()
        }
        await refreshed?.value

        let snapshot = await probe.snapshot()
        expect(
            snapshot.calls == ["", "report", "report", ""],
            "an idle session prepares recents, and an open one re-asks its query and refreshes them")
    }

    static func blankScreenOpensOnKeptRecents() async {
        let probe = FileSearchProbe()
        let session = makeSession(probe: probe)
        await session.refresh()?.value
        await waitUntil({ session.state == .ready }) {
            session.search("")
            expect(
                session.state == .ready && !session.results.isEmpty,
                "prepared recents show before any search returns")
        }
        session.cancel()
        session.search("")
        expect(!session.results.isEmpty, "recents survive the palette closing")
        session.search("report")
        expect(
            session.results.first?.name != "report",
            "a typed query still waits for its own results")
    }

    static func recentRefreshLeavesTheOpenListAlone() async {
        let probe = FileSearchProbe()
        let session = makeSession(probe: probe)
        await waitUntil({ session.state == .ready }) {
            session.search("report")
        }
        await session.refreshRecent().value
        expect(session.results.first?.name == "report", "a Recent refresh leaves the open list alone")
        session.cancel()
        session.search("")
        expect(!session.results.isEmpty, "the next blank screen opens on the refreshed rows")
    }

    static func blankQueryLoadsRecents() async {
        let probe = FileSearchProbe()
        let session = makeSession(probe: probe)
        await waitUntil({ session.state == .ready }) {
            session.search("")
        }
        await waitUntil({ session.state == .ready && session.results.first?.name == "report" }) {
            session.search("report")
        }

        let snapshot = await probe.snapshot()
        expect(
            snapshot.calls == ["", "report"],
            "the blank screen is a request of its own, not the absence of one")
    }

    static func filterChangeRerunsTheQuery() async {
        let probe = FileSearchProbe()
        let session = makeSession(probe: probe)
        await waitUntil({ session.state == .ready }) {
            session.search("report")
        }
        await waitUntil({ session.state == .ready }) {
            session.search("report", filter: .images)
        }
        await session.search("report", filter: .images)?.value

        let snapshot = await probe.snapshot()
        expect(
            snapshot.calls == ["report", "report [Images]"],
            "narrowing the filter re-runs the same words, and re-stating it runs nothing")
    }

    static func makeSession(probe: FileSearchProbe) -> FileSearchSession {
        FileSearchSession { query, filter in
            await probe.search(query: query, filter: filter)
        }
    }

    @MainActor
    final class StateWait {
        private let condition: () -> Bool
        private let changes = AsyncStream<Void>.makeStream()

        init(_ condition: @escaping () -> Bool) {
            self.condition = condition
            track()
        }

        private func track() {
            withObservationTracking {
                _ = condition()
            } onChange: { [changes] in
                changes.continuation.yield()
            }
        }

        func wait() async {
            var iterator = changes.stream.makeAsyncIterator()
            while await iterator.next() != nil {
                if condition() { return }
                track()
            }
        }
    }

    static func waitUntil(
        _ condition: @escaping @MainActor () -> Bool,
        performing action: () async -> Void
    ) async {
        let observation = StateWait(condition)
        await action()
        await observation.wait()
        expect(condition(), "the async operation completed before the timeout")
    }
}
