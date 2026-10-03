import Foundation

/// Paste Sequentially's walk down history, newest first, frozen when the walk begins.
struct PasteSequence: Sendable {
    static let idleTimeout: TimeInterval = 60
    /// Outlasts ⌘V's post delay and the target's read, so the next write cannot beat that read.
    static let settleInterval: TimeInterval = 0.25

    /// Ids rather than items, so an entry deleted mid-walk is skipped instead of pasted.
    private let entryIDs: [ClipboardItem.ID]
    private var nextIndex = 0
    /// The pasteboard as our last write left it; any other count is a copy made since.
    private var changeCount: Int
    private var lastPaste: Date

    init(history: [ClipboardItem], changeCount: Int, now: Date) {
        entryIDs = history.map(\.id)
        self.changeCount = changeCount
        lastPaste = now
    }

    func continues(changeCount: Int, at now: Date) -> Bool {
        changeCount == self.changeCount && now.timeIntervalSince(lastPaste) < Self.idleTimeout
    }

    func isSettling(at now: Date) -> Bool {
        now.timeIntervalSince(lastPaste) < Self.settleInterval
    }

    /// Nil at the end, where the walk stops rather than wrap back to the newest entry.
    mutating func next(in history: [ClipboardItem]) -> ClipboardItem? {
        while nextIndex < entryIDs.endIndex {
            let id = entryIDs[nextIndex]
            nextIndex += 1
            // Newest first on both sides, so the scan stops about as deep as the walk has gone.
            if let item = history.first(where: { $0.id == id }) { return item }
        }
        return nil
    }

    /// Our own write moves the count, so the walk adopts it rather than read it as a new copy.
    mutating func recordPaste(changeCount: Int, at now: Date) {
        self.changeCount = changeCount
        lastPaste = now
    }
}
