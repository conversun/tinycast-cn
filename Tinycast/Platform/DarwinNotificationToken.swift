import Foundation
import notify

/// RAII handle for a Darwin notification, delivered on the main queue until the token goes away.
final class DarwinNotificationToken {
    private var token = NOTIFY_TOKEN_INVALID

    init(_ name: String, handler: @escaping @MainActor @Sendable () -> Void) {
        notify_register_dispatch(name, &token, .main) { _ in
            MainActor.assumeIsolated { handler() }
        }
    }

    deinit {
        notify_cancel(token)
    }
}
