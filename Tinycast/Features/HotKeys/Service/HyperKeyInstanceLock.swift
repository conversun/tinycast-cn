import Foundation

/// Lets one Tinycast process — release or Dev — drive the Hyper Key; the kernel frees it on exit.
@MainActor
final class HyperKeyInstanceLock {
    private let url: URL
    private var descriptor: Int32 = -1

    init(url: URL = FileManager.default.temporaryDirectory.appending(path: "com.tinycast.hyper-key.lock")) {
        self.url = url
    }

    isolated deinit {
        release()
    }

    @discardableResult
    func acquire() -> Bool {
        guard descriptor < 0 else { return true }
        let descriptor = open(url.path, O_CREAT | O_RDWR | O_CLOEXEC | O_NOFOLLOW, S_IRUSR | S_IWUSR)
        // Without a lock file there is no other process to defer to.
        guard descriptor >= 0 else { return true }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            close(descriptor)
            return false
        }
        let pid = Array(String(getpid()).utf8)
        ftruncate(descriptor, 0)
        _ = pid.withUnsafeBytes { pwrite(descriptor, $0.baseAddress, $0.count, 0) }
        self.descriptor = descriptor
        return true
    }

    func holder() -> pid_t? {
        (try? String(contentsOf: url, encoding: .utf8)).flatMap { pid_t($0) }
    }

    /// Closing drops the lock; the file stays so every process keeps locking the same inode.
    func release() {
        guard descriptor >= 0 else { return }
        close(descriptor)
        descriptor = -1
    }
}
