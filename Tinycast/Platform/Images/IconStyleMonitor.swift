import AppKit

/// Watches System Settings → Appearance → **Icon & widget style**; a change stales every icon.
@MainActor
final class IconStyleMonitor {
    /// Measured: the swap lands ~25–120ms after the notification, jittering run to run.
    private static let pollInterval = Duration.milliseconds(40)
    private static let settleLimit = Duration.milliseconds(600)

    private var token: NotificationToken?
    private var settling: Task<Void, Never>?
    private var rendered: Data?

    init() {
        let center = NSWorkspace.shared.notificationCenter
        let observer = center.addObserver(
            forName: .iconAppearanceConfigurationDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.invalidateOnceIconsSwap() }
        }
        token = NotificationToken(observer, center: center)
        settling = Task { [weak self] in
            let fingerprint = await Self.fingerprint()
            self?.rendered = fingerprint
        }
    }

    /// AppKit posts before `NSWorkspace` vends the new style, so wait for pixels, not the signal.
    private func invalidateOnceIconsSwap() {
        settling?.cancel()
        settling = Task { [weak self] in
            let deadline = ContinuousClock.now + Self.settleLimit
            while !Task.isCancelled {
                let current = await Self.fingerprint()
                guard let self, !Task.isCancelled else { return }
                if current != rendered {
                    rendered = current
                    break
                }
                if ContinuousClock.now >= deadline { break }
                try? await Task.sleep(for: Self.pollInterval)
            }
            guard !Task.isCancelled else { return }
            IconCache.invalidateStyled()
        }
    }

    private static func fingerprint() async -> Data? {
        await Task.detached(priority: .userInitiated) { IconCache.styleFingerprint() }.value
    }
}

extension Notification.Name {
    /// Exported by AppKit but undeclared; the only signal that covers every restyle.
    static let iconAppearanceConfigurationDidChange = Notification.Name(
        "NSWorkspaceIconAppearanceConfigurationDidChangeNotification")
}
