import AppKit

/// The message pill, shared by every feature that reports a transient confirmation.
@MainActor
final class MessageHUDController {
    private let presenter: HUDPresenter

    init(settings: AppSettings) {
        presenter = HUDPresenter(
            anchor: .edgeInset(Theme.Size.hudEdgeOffset),
            dwell: Theme.Duration.messageHUD,
            screen: { settings.openOnCursorScreen ? .underCursor : .main })
    }

    func show(message: String, tone: DialogTone = .success) {
        presenter.show(MessageHUDView(message: message, tone: tone))
    }
}
