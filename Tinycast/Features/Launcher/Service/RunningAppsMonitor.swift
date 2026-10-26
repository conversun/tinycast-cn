import AppKit

@MainActor
@Observable
final class RunningAppsMonitor {
    private(set) var runningBundleIDs: Set<String> = []
    private var runningAppPaths: Set<String> = []
    @ObservationIgnored private var observation: NSKeyValueObservation?

    init() {
        observation = NSWorkspace.shared.observe(
            \.runningApplications, options: .initial
        ) { [weak self] _, _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    func isRunning(_ app: AppEntry) -> Bool {
        app.kind == .application && app.bundleID != nil && runningAppPaths.contains(app.id)
    }

    /// Helpers and agents fire these too, so republish only on a real change.
    private func refresh() {
        let apps = NSWorkspace.shared.runningApplications
        let bundleIDs = Set(apps.compactMap(\.bundleIdentifier))
        let paths = Set(apps.compactMap { $0.bundleURL?.resolvingSymlinksInPath().standardizedFileURL.path })
        if bundleIDs != runningBundleIDs { runningBundleIDs = bundleIDs }
        if paths != runningAppPaths { runningAppPaths = paths }
    }
}
