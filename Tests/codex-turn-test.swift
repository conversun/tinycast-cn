import Foundation

/// The Stop path over the app-server. `CodexTurnRunner` learns a turn's ID twice — from the
/// `turn/started` notification and from the `turn/start` response — and either can be arbitrarily
/// late, so Stop can land while the turn the server is already running has no name here yet. These
/// cases drive the real client against a stub server stalled in exactly that window.
@main
@MainActor
struct CodexTurnTests {
    static var failures = 0
    static var passes = 0

    static func expect(_ condition: Bool, _ message: String) {
        if condition {
            passes += 1
        } else {
            failures += 1
            print("FAIL: \(message)")
        }
    }

    static func main() async {
        await stopBeforeTurnStartedStillInterrupts()
        await aTurnNamedTwiceIsInterruptedOnce()

        print("\(passes) passed, \(failures) failed")
        if failures > 0 { exit(1) }
    }

    /// The regression: Stop arrives before anything has named the turn, and the `turn/start`
    /// response never comes. `turn/started` is then the only thing that can name it, so a runner
    /// that stops listening to the thread it just dropped leaves the turn running on the server.
    static func stopBeforeTurnStartedStillInterrupts() async {
        guard let server = StubServer(mode: "hold-turn") else {
            expect(false, "the stub app-server installs")
            return
        }
        defer { server.tearDown() }

        let turn = server.startTurn()
        guard await server.awaitMark("turn-start-received") else {
            expect(false, "the stub app-server is asked to start a turn")
            return
        }

        turn.cancel()
        let dropped = await server.awaitCondition { !server.runner.isActive }
        expect(dropped, "Stop drops a turn that nothing has named yet")

        // Only now does the server name the turn — after the runner has already let the thread go.
        server.mark("stop-landed")
        let interrupted = await server.awaitLog("interrupt:thread-1:turn-1")
        expect(interrupted, "a Stop that beat turn/started still interrupts the turn that starts")
    }

    /// Both names arrive for the same Stopped turn. Interrupting per name would send two.
    static func aTurnNamedTwiceIsInterruptedOnce() async {
        guard let server = StubServer(mode: "hold-both") else {
            expect(false, "the stub app-server installs")
            return
        }
        defer { server.tearDown() }

        let turn = server.startTurn()
        guard await server.awaitMark("turn-start-received") else {
            expect(false, "the stub app-server is asked to start a turn")
            return
        }

        turn.cancel()
        _ = await server.awaitCondition { !server.runner.isActive }
        server.mark("stop-landed")

        let interrupted = await server.awaitLog("interrupt:thread-1:turn-1")
        expect(interrupted, "a Stopped turn is interrupted as soon as its ID arrives")
        // Give a second interrupt every chance to show up before ruling it out.
        _ = await server.awaitCondition(timeout: .milliseconds(400)) { server.interrupts > 1 }
        expect(server.interrupts == 1, "the turn's second name spends no second interrupt")
    }
}

/// A `CodexTurnRunner` wired to a real `CodexAppServerClient`, wired in turn to the stub server in
/// `Tests/ai-fixtures/codex-stub.py`. The wiring is the manager's own: `connect` starts the process,
/// and every notification the client does not claim goes to the runner.
@MainActor
final class StubServer {
    let root: URL
    let client: CodexAppServerClient
    let runner: CodexTurnRunner

    init?(mode: String) {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appending(path: "codex-turn-\(UUID().uuidString)", directoryHint: .isDirectory)
        let executable = root.appending(path: "bin/codex")
        do {
            try FileManager.default.createDirectory(
                at: executable.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.copyItem(
                at: URL(fileURLWithPath: "Tests/ai-fixtures/codex-stub.py"), to: executable)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o755], ofItemAtPath: executable.path)
        } catch {
            print("the stub app-server could not be installed: \(error)")
            return nil
        }

        // `CodexExecutableLocator` walks PATH out of the current environment, so the stub only has
        // to sit in front of any real `codex` this machine has.
        let inherited = ProcessInfo.processInfo.environment["PATH"] ?? ""
        setenv("PATH", "\(executable.deletingLastPathComponent().path):\(inherited)", 1)
        setenv("TC_STUB_ROOT", root.path, 1)
        setenv("TC_STUB_MODE", mode, 1)

        let client = CodexAppServerClient(
            codexHome: root.appending(path: "home", directoryHint: .isDirectory),
            workspace: root.appending(path: "work", directoryHint: .isDirectory))
        let runner = CodexTurnRunner(client: client)
        runner.connect = {
            try await client.start()
            return []
        }
        client.onNotification = { method, params in
            runner.handle(method: method, params: params)
        }

        self.root = root
        self.client = client
        self.runner = runner
    }

    /// What the app does: a task iterating the provider stream, where Stop is its cancellation.
    func startTurn() -> Task<Void, Never> {
        let stream = runner.stream(
            AIRequest(messages: [AIMessage(role: .user, text: "Hello")]),
            model: "gpt-5-codex", effort: nil)
        return Task {
            do {
                for try await _ in stream {}
            } catch {}
        }
    }

    var received: String {
        (try? String(contentsOf: root.appending(path: "received.log"), encoding: .utf8)) ?? ""
    }

    var interrupts: Int {
        received.split(separator: "\n").count { $0.hasPrefix("interrupt:") }
    }

    func mark(_ name: String) {
        FileManager.default.createFile(atPath: root.appending(path: name).path, contents: nil)
    }

    func awaitMark(_ name: String) async -> Bool {
        await awaitCondition {
            FileManager.default.fileExists(atPath: self.root.appending(path: name).path)
        }
    }

    func awaitLog(_ line: String) async -> Bool {
        await awaitCondition { self.received.contains(line) }
    }

    /// Polls instead of sleeping a fixed span, so a passing case costs what it actually needs and
    /// a failing one still ends.
    func awaitCondition(
        timeout: Duration = .seconds(10), _ condition: @MainActor () -> Bool
    ) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(5))
        }
        return condition()
    }

    func tearDown() {
        client.stop()
        try? FileManager.default.removeItem(at: root)
    }
}
