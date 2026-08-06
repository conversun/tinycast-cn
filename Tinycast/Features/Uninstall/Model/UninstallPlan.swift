import Foundation

/// Bytes, plus whether the walk hit its budget so a huge tree can honestly read "at least".
struct MeasuredSize: Hashable, Sendable {
    var bytes: Int64 = 0
    var isLowerBound = false

    static let zero = MeasuredSize()

    var formatted: String {
        // Without this an empty folder renders as "Zero kB", which reads as a bug.
        let size = bytes.formatted(.byteCount(style: .file, spellsOutZero: false))
        return isLowerBound ? "≥ " + size : size
    }
}

/// One item an uninstall would trash: the bundle itself, or a leftover attributed to it.
struct UninstallCandidate: Identifiable, Hashable, Sendable {
    /// Standardized, and what `UninstallSelection` stores.
    let path: String
    /// Row title, with `.app` stripped from the bundle.
    let name: String
    /// Row subtitle: the enclosing directory, tilde-abbreviated.
    let locationLabel: String
    let evidence: UninstallEvidence
    let isDirectory: Bool
    let size: MeasuredSize
    let protection: UninstallProtection

    var id: String { path }
    var url: URL { URL(fileURLWithPath: path) }
    var isLocked: Bool { !protection.isRemovable }
    var lockReason: String? { protection.lockReason }
}

/// Everything attributable to one app, bundle pinned first.
struct UninstallPlan: Equatable, Sendable {
    let target: UninstallTarget
    let candidates: [UninstallCandidate]
    let isTargetRunning: Bool

    var removableIDs: Set<UninstallCandidate.ID> {
        Set(candidates.lazy.filter { !$0.isLocked }.map(\.id))
    }

    var lockedCount: Int { candidates.count { $0.isLocked } }

    var totalBytes: Int64 { candidates.reduce(0) { $0 + $1.size.bytes } }

    /// Everything removable, name matches included: they're exact, confined, and only ever cost a drag back out of the Trash.
    var defaultSelection: UninstallSelection {
        UninstallSelection(plan: self, checked: removableIDs)
    }
}

/// The only thing holding a checked set, and it can only hold removable ids. Every mutation funnels through one
/// intersection with `plan.removableIDs`, so "a locked candidate is never checked" is one line to review.
struct UninstallSelection: Equatable, Sendable {
    private(set) var checked: Set<UninstallCandidate.ID>

    init(plan: UninstallPlan, checked: Set<UninstallCandidate.ID> = []) {
        self.checked = checked.intersection(plan.removableIDs)
    }

    mutating func toggle(_ id: UninstallCandidate.ID, in plan: UninstallPlan) {
        if checked.contains(id) {
            checked.remove(id)
        } else if plan.removableIDs.contains(id) {
            checked.insert(id)
        }
    }

    func isChecked(_ id: UninstallCandidate.ID) -> Bool { checked.contains(id) }

    var count: Int { checked.count }

    func bytes(in plan: UninstallPlan) -> Int64 {
        plan.candidates.reduce(0) { $0 + (checked.contains($1.id) ? $1.size.bytes : 0) }
    }

    func candidates(in plan: UninstallPlan) -> [UninstallCandidate] {
        plan.candidates.filter { checked.contains($0.id) }
    }
}
