import Foundation

extension Process {
    /// Use instead of `waitUntilExit`, whose run loop can miss the exit on a GCD thread and hang.
    func runObservingExit() throws -> ProcessExit {
        let exit = ProcessExit()
        terminationHandler = { _ in exit.signal() }
        try run()
        return exit
    }
}

/// Blocks without a run loop, and every wait after the exit returns at once.
struct ProcessExit: Sendable {
    private let semaphore = DispatchSemaphore(value: 0)

    fileprivate func signal() {
        semaphore.signal()
    }

    func wait() {
        semaphore.wait()
        semaphore.signal()
    }
}
