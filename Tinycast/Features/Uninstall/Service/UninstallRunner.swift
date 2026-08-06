import Foundation

struct UninstallFailedItem: Hashable, Sendable {
    let name: String
    let reason: String
}

struct UninstallReport: Sendable {
    let trashed: [UninstallCandidate]
    let failed: [UninstallFailedItem]

    var trashedCount: Int { trashed.count }
    var freedBytes: Int64 { trashed.reduce(0) { $0 + $1.size.bytes } }
    var hasFailures: Bool { !failed.isEmpty }
    /// Gates the reference cleanup: a leftovers-only run leaves the app installed.
    var removedBundle: Bool { trashed.contains { $0.evidence == .bundle } }
}

/// `FileManager.trashItem` is the only removal call in this feature — `removeItem` never appears, so an uninstall stays undoable.
/// Presenting the outcome is `AppCore`'s job; this reports and never shows UI.
enum UninstallRunner {
    static func moveToTrash(_ candidates: [UninstallCandidate]) async -> UninstallReport {
        // A locked candidate should never have been checked; skip rather than attempt.
        let removable = candidates.filter { !$0.isLocked }
        // Bundle last: on partial failure it's still there to re-run from, and the launcher entry that reaches this screen survives.
        let ordered =
            removable.filter { $0.evidence != .bundle } + removable.filter { $0.evidence == .bundle }

        return await Task.detached(priority: .userInitiated) {
            var trashed: [UninstallCandidate] = []
            var failed: [UninstallFailedItem] = []
            for candidate in ordered {
                do {
                    try FileManager.default.trashItem(at: candidate.url, resultingItemURL: nil)
                    trashed.append(candidate)
                } catch {
                    failed.append(
                        UninstallFailedItem(
                            name: candidate.name, reason: error.localizedDescription))
                }
            }
            return UninstallReport(trashed: trashed, failed: failed)
        }.value
    }
}
