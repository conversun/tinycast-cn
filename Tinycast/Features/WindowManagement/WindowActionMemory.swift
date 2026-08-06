import CoreGraphics
import Foundation

/// What Tinycast remembers about each window it has moved: the frame to restore, the frame it was left
/// at, and where it sits in a size cycle.
///
/// Cycling and Restore both reduce to one question — *has the user moved this window themselves since
/// our last action?* — so both are answered here. Generic over the key so this stays Foundation-only:
/// the app keys by `AXUIElement`, `Tools/window-command-test.swift` keys by `Int`.
struct WindowActionMemory<Key: Hashable> {
    struct Record: Equatable, Sendable {
        /// Where the window was before Tinycast first touched it.
        var restoreFrame: CGRect
        /// Where we *observed* it after our last write — not what we asked for. See `decide`.
        var appliedFrame: CGRect
        var command: WindowCommand.ID
        var step: Int
        var screenID: Int
        var at: Date
    }

    struct Decision: Equatable, Sendable {
        /// Cycle position for this press, fed straight into `WindowLayout.Input.step`.
        var step: Int
        /// The frame `commit` should persist as this window's restore point.
        var restoreFrame: CGRect
        /// False the first time we see a window: there is nothing to go back to yet, so a Restore press
        /// must do nothing rather than "restore" it to where it already is.
        var canRestore: Bool
        /// Set only when the window still sits exactly where a tile command left it.
        var lastTileCommand: WindowCommand.ID?
    }

    /// Point tolerance for "is this still the frame we left it at" — loose enough for subpixel drift,
    /// tight enough that a deliberate drag always registers.
    static var tolerance: CGFloat { 2 }

    /// Bounded so a long session over many windows can't grow this without limit.
    var capacity: Int
    /// When set, a cycle that has gone cold restarts from the half instead of continuing mid-sequence.
    var cycleTimeout: TimeInterval?

    private var records: [Key: Record] = [:]
    /// Least-recently-used first, so eviction is a `removeFirst`.
    private var order: [Key] = []

    init(capacity: Int = 64, cycleTimeout: TimeInterval? = nil) {
        self.capacity = capacity
        self.cycleTimeout = cycleTimeout
    }

    var count: Int { records.count }

    func record(for key: Key) -> Record? { records[key] }

    /// Resolves the cycle step and restore point for a press. Pure — `commit` performs the write, once
    /// the mover knows what actually landed.
    func decide(
        key: Key, command: WindowCommand.ID, currentFrame: CGRect, currentScreenID: Int,
        cycleEnabled: Bool, now: Date
    ) -> Decision {
        // First time we've seen this window: capture where it was, so Restore works even for windows
        // Tinycast has never moved.
        guard let record = records[key] else {
            return Decision(
                step: 0, restoreFrame: currentFrame, canRestore: false, lastTileCommand: nil)
        }

        // Compare against the frame we *observed*, never the one we asked for: Terminal resizes in whole
        // character cells and never lands exactly on target, so comparing against the target would read
        // as "the user moved it" on every single press and break cycling and Restore for such apps.
        guard approximatelyEqual(currentFrame, record.appliedFrame) else {
            return Decision(
                step: 0, restoreFrame: currentFrame, canRestore: true, lastTileCommand: nil)
        }

        let lastTileCommand =
            WindowLayout.isTileCommand(record.command) ? record.command : nil
        let cycles = WindowCommandCatalog.command(id: command)?.cyclesOnRepeat ?? false
        let expired = cycleTimeout.map { now.timeIntervalSince(record.at) > $0 } ?? false
        let continues =
            cycleEnabled && cycles && command == record.command
            && currentScreenID == record.screenID && !expired
        return Decision(
            step: continues ? (record.step + 1) % 3 : 0, restoreFrame: record.restoreFrame,
            canRestore: true, lastTileCommand: lastTileCommand)
    }

    /// Records what actually landed. `appliedFrame` must be read back from the window, not assumed.
    mutating func commit(
        key: Key, command: WindowCommand.ID, decision: Decision, appliedFrame: CGRect,
        screenID: Int, now: Date
    ) {
        records[key] = Record(
            restoreFrame: decision.restoreFrame, appliedFrame: appliedFrame, command: command,
            step: decision.step, screenID: screenID, at: now)
        touch(key)
    }

    /// Breaks the size-cycle chain while keeping the restore point — what a fullscreen toggle needs,
    /// since macOS restores the pre-fullscreen frame itself but the user's original frame is still the
    /// right Restore target.
    mutating func forgetCycle(key: Key) {
        guard var record = records[key] else { return }
        record.step = 0
        records[key] = record
    }

    mutating func forget(where predicate: (Key) -> Bool) {
        let doomed = records.keys.filter(predicate)
        guard !doomed.isEmpty else { return }
        for key in doomed { records.removeValue(forKey: key) }
        order.removeAll { doomed.contains($0) }
    }

    mutating func forget(key: Key) {
        guard records.removeValue(forKey: key) != nil else { return }
        order.removeAll { $0 == key }
    }

    private mutating func touch(_ key: Key) {
        order.removeAll { $0 == key }
        order.append(key)
        while order.count > capacity, let oldest = order.first {
            order.removeFirst()
            records.removeValue(forKey: oldest)
        }
    }

    private func approximatelyEqual(_ a: CGRect, _ b: CGRect) -> Bool {
        let tolerance = Self.tolerance
        return abs(a.minX - b.minX) <= tolerance && abs(a.minY - b.minY) <= tolerance
            && abs(a.width - b.width) <= tolerance && abs(a.height - b.height) <= tolerance
    }
}
