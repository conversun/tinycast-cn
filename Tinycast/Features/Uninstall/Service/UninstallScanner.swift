import Darwin
import Foundation

/// Every filesystem, stat and permission read. Not compiled by the harness — the decisions it defers to are the pure half.
enum UninstallScanner {
    struct SizeBudget: Sendable {
        /// Generous: an editor's support folder runs to ~90k entries, and stopping short would show "≥ 796 MB" for 1.9 GB.
        /// Roughly a second at 250k, off-main behind a progress state.
        var maxEntries = 250_000
        static let `default` = SizeBudget()
    }

    enum Failure: LocalizedError, Sendable {
        case refused

        var errorDescription: String? {
            switch self {
            case .refused:
                return "Tinycast can’t uninstall this app."
            }
        }
    }

    /// Off-main, and a structured child of its caller: cancelling that releases every walk.
    nonisolated static func scan(
        target: UninstallTarget, otherAppNames: [String], otherBundleIDs: [String],
        isTargetRunning: Bool, roots: [UninstallSearchRoot] = UninstallSearchRoot.all,
        budget: SizeBudget = .default
    ) async throws -> UninstallPlan {
        try await Signposts.interval("UninstallScanner.scan") {
            let home = NSHomeDirectory()
            let environment = UninstallEnvironment(
                home: home, hasFullDiskAccess: detectFullDiskAccess(home: home))
            guard
                let identity = UninstallIdentity.make(
                    target: target, otherAppNames: otherAppNames, otherBundleIDs: otherBundleIDs,
                    ownBundleID: Bundle.main.bundleIdentifier, ownBundleURL: Bundle.main.bundleURL)
            else { throw Failure.refused }

            let bundlePath = target.bundleURL.standardizedFileURL.path
            let bundle = row(
                path: bundlePath, evidence: .bundle, environment: environment,
                displayName: target.bundleURL.deletingPathExtension().lastPathComponent)

            var buckets = [[Row]](repeating: [], count: roots.count)
            try await withThrowingTaskGroup(of: (Int, [Row]).self) { group in
                for (index, root) in roots.enumerated() {
                    group.addTask {
                        try Task.checkCancellation()
                        return (
                            index,
                            rows(
                                in: root, identity: identity, environment: environment,
                                bundlePath: bundlePath)
                        )
                    }
                }
                // At its own index, so `UninstallSearchRoot.all` order outlives completion order.
                for try await (index, found) in group { buckets[index] = found }
            }

            let gathered =
                [bundle].compactMap { $0 } + buckets.flatMap { $0 }
                + (try binRows(environment: environment, bundlePath: bundlePath))

            // One pass, in gathered order: a `Set` shared across tasks is what would race.
            var seen = Set<String>()
            var candidates: [UninstallCandidate] = []
            var walkIndices: [Int] = []
            for row in gathered {
                guard seen.insert(row.candidate.path).inserted else { continue }
                if row.needsWalk { walkIndices.append(candidates.count) }
                candidates.append(row.candidate)
            }

            try await withThrowingTaskGroup(of: (Int, MeasuredSize).self) { group in
                for index in walkIndices {
                    let path = candidates[index].path
                    group.addTask {
                        try Task.checkCancellation()
                        return (index, try directorySize(of: path, budget: budget))
                    }
                }
                for try await (index, size) in group {
                    candidates[index] = resized(candidates[index], to: size)
                }
            }

            // Bundle pinned first; the rest by path, which is the order the list shows.
            let leftovers = candidates.filter { $0.evidence != .bundle }.sorted { $0.path < $1.path }
            return UninstallPlan(
                target: target, candidates: candidates.filter { $0.evidence == .bundle } + leftovers,
                isTargetRunning: isTargetRunning)
        }
    }

    // MARK: - Private

    /// `size` is the one field the second gather writes, and it writes it at this row's own index.
    private struct Row: Sendable {
        let candidate: UninstallCandidate
        let needsWalk: Bool
    }

    private static func rows(
        in root: UninstallSearchRoot, identity: UninstallIdentity,
        environment: UninstallEnvironment, bundlePath: String
    ) -> [Row] {
        let rootPath = root.path(home: environment.home)
        guard let names = childNames(of: rootPath) else { return [] }
        // One stat per root, not per row.
        let parent = parentFacts(of: rootPath)
        return UninstallRules.matches(childNames: names, in: root, identity: identity)
            .compactMap { match -> Row? in
                let path = (rootPath + "/" + match.name as NSString).standardizingPath
                guard
                    UninstallRules.isAcceptableCandidate(
                        path: path, rootPath: rootPath, home: environment.home,
                        bundlePath: bundlePath)
                else { return nil }
                return row(
                    path: path, evidence: match.evidence, environment: environment, parent: parent)
            }
    }

    /// Serial: four directories of cheap symlink reads, and nothing here needs a walk.
    private static func binRows(environment: UninstallEnvironment, bundlePath: String) throws
        -> [Row]
    {
        var rows: [Row] = []
        for directory in UninstallSearchRoot.binDirectories {
            try Task.checkCancellation()
            let rootPath = (directory as NSString).expandingTildeInPath
            guard let names = childNames(of: rootPath) else { continue }
            let parent = parentFacts(of: rootPath)
            for name in names {
                let path = (rootPath + "/" + name as NSString).standardizingPath
                guard let target = try? FileManager.default.destinationOfSymbolicLink(atPath: path)
                else { continue }
                // A relative link resolves against its own directory, not the cwd.
                let resolved =
                    target.hasPrefix("/")
                    ? target : (rootPath as NSString).appendingPathComponent(target)
                guard UninstallRules.isBundleSymlink(target: resolved, bundlePath: bundlePath),
                    let row = row(
                        path: path, evidence: .binSymlink, environment: environment, parent: parent)
                else { continue }
                rows.append(row)
            }
        }
        return rows
    }

    private static func resized(_ candidate: UninstallCandidate, to size: MeasuredSize)
        -> UninstallCandidate
    {
        UninstallCandidate(
            path: candidate.path, name: candidate.name, locationLabel: candidate.locationLabel,
            evidence: candidate.evidence, isDirectory: candidate.isDirectory, size: size,
            protection: candidate.protection)
    }

    private static func childNames(of directory: String) -> [String]? {
        // Not `.skipsHiddenFiles`: dot-named leftovers are the ones a user would never find.
        try? FileManager.default.contentsOfDirectory(atPath: directory)
    }

    private static func row(
        path: String, evidence: UninstallEvidence, environment: UninstallEnvironment,
        displayName: String? = nil, parent: ParentFacts? = nil
    ) -> Row? {
        guard let scanned = inspect(path, parent: parent) else { return nil }
        let protection = UninstallProtectionRules.classify(scanned.facts, environment: environment)
        guard protection != .missing else { return nil }
        // A symlink is trashed as the link, so it never costs more than its own bytes.
        let walkable = scanned.isDirectory && !scanned.facts.isSymbolicLink
        return Row(
            candidate: UninstallCandidate(
                path: path,
                name: displayName ?? (path as NSString).lastPathComponent,
                locationLabel: UninstallRules.abbreviate(
                    (path as NSString).deletingLastPathComponent, home: environment.home),
                evidence: evidence,
                isDirectory: scanned.isDirectory,
                size: walkable ? .zero : MeasuredSize(bytes: scanned.byteSize),
                protection: protection),
            needsWalk: walkable)
    }

    /// `lstat`, never `stat`: a symlink is judged as the link, not as whatever it points at.
    private static func inspect(_ path: String, parent: ParentFacts?)
        -> (facts: PathFacts, isDirectory: Bool, byteSize: Int64)?
    {
        var info = stat()
        guard lstat(path, &info) == 0 else { return nil }
        let parent = parent ?? parentFacts(of: (path as NSString).deletingLastPathComponent)
        let volumeIsReadOnly =
            (try? URL(fileURLWithPath: path).resourceValues(forKeys: [.volumeIsReadOnlyKey]))?
            .volumeIsReadOnly ?? false
        let facts = PathFacts(
            path: path,
            isSymbolicLink: (info.st_mode & S_IFMT) == S_IFLNK,
            volumeIsReadOnly: volumeIsReadOnly,
            isSystemRestricted: info.st_flags & UInt32(SF_RESTRICTED | SF_IMMUTABLE) != 0,
            isUserImmutable: info.st_flags & UInt32(UF_IMMUTABLE) != 0,
            isOwnedByCurrentUser: info.st_uid == geteuid(),
            parentIsWritable: parent.isWritable,
            parentIsSticky: parent.isSticky)
        return (facts, (info.st_mode & S_IFMT) == S_IFDIR, Int64(info.st_blocks) * 512)
    }

    /// The permission that actually governs a trash, resolved once per root.
    private static func parentFacts(of directory: String) -> ParentFacts {
        var info = stat()
        let sticky = stat(directory, &info) == 0 && (info.st_mode & S_ISVTX) != 0
        return ParentFacts(
            isWritable: FileManager.default.isWritableFile(atPath: directory), isSticky: sticky)
    }

    private struct ParentFacts {
        let isWritable: Bool
        let isSticky: Bool
    }

    /// On-disk bytes, like Finder. The error handler keeps counting past an unreadable subtree instead of abandoning the row.
    private static func directorySize(of path: String, budget: SizeBudget) throws -> MeasuredSize {
        let url = URL(fileURLWithPath: path)
        let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey]
        guard
            let enumerator = FileManager.default.enumerator(
                at: url, includingPropertiesForKeys: keys, options: [],
                errorHandler: { _, _ in true })
        else { return .zero }

        var size = MeasuredSize()
        var entries = 0
        for case let item as URL in enumerator {
            // The long pole: cancellation has to land inside the walk, not just between walks.
            try Task.checkCancellation()
            entries += 1
            if entries > budget.maxEntries {
                size.isLowerBound = true
                break
            }
            let values = try? item.resourceValues(forKeys: Set(keys))
            size.bytes += Int64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? 0)
        }
        return size
    }

    /// Detected, never requested: TCC denies this read silently, no prompt. It can only under-report, which just leaves a row locked.
    private static func detectFullDiskAccess(home: String) -> Bool {
        let descriptor = open(home + "/Library/Application Support/com.apple.TCC/TCC.db", O_RDONLY)
        guard descriptor >= 0 else { return false }
        close(descriptor)
        return true
    }
}
