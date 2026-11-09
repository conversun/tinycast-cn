import AppKit

@MainActor
final class NotesMenuBarController: NSObject {
    private unowned let coordinator: NotesCoordinator
    private let status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()

    init(coordinator: NotesCoordinator) {
        self.coordinator = coordinator
        super.init()
        status.autosaveName = "Notes"
        menu.addItem(item(.createNote, action: #selector(createNote)))
        menu.addItem(item(.searchNotes, action: #selector(searchNotes)))
        guard let button = status.button else { return }
        button.image = NSImage(
            systemSymbolName: CommandID.showNotes.sfSymbol,
            accessibilityDescription: String(localized: "Notes"))
        button.target = self
        button.action = #selector(click)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    func remove() {
        menu.cancelTracking()
        NSStatusBar.system.removeStatusItem(status)
    }

    private func item(_ command: CommandID, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: command.name, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func click(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent,
            event.type == .rightMouseUp || !event.modifierFlags.isDisjoint(with: [.control, .option])
        else { return coordinator.toggle() }
        // Attached only for this click, so a plain click stays free to toggle the window.
        status.menu = menu
        sender.performClick(nil)
        status.menu = nil
    }

    @objc private func createNote() {
        coordinator.createNote()
    }

    @objc private func searchNotes() {
        coordinator.searchNotes()
    }
}
