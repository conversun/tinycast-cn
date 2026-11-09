import Foundation

/// Lets one Tinycast process — release or Dev — drive a key remap; the kernel frees it on exit.
@MainActor
final class RemapInstanceLock {
    private let url: URL
    private var descriptor: Int32 = -1

    init(url: URL) {
        self.url = url
    }

    isolated deinit {
        release()
    }

    var isHeld: Bool { descriptor >= 0 }

    @discardableResult
    func acquire() -> Bool {
        guard descriptor < 0 else { return true }
        let descriptor = open(url.path, O_CREAT | O_RDWR | O_CLOEXEC | O_NOFOLLOW, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { return false }
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
