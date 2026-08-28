import Foundation

/// Reopens the app once this process is gone. `open` on a bundle id that is still running would
/// only re-activate the instance on its way out, so the relaunch has to outlive us.
enum RelaunchRunner {
    static func relaunchAfterExit(_ bundleURL: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        let quoted = bundleURL.path.replacingOccurrences(of: "'", with: "'\\''")
        process.arguments = [
            "-c",
            "while /bin/kill -0 \(getpid()) 2>/dev/null; do /bin/sleep 0.2; done; "
                + "/usr/bin/open '\(quoted)'"
        ]
        // Orphaned on our exit and reparented to launchd, which is the whole point.
        try? process.run()
    }
}
