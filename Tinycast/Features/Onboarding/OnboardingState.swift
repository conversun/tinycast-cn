import Foundation

/// First-run marker stored as a file in Application Support (not UserDefaults) so a full uninstall — including leftover/`--zap` cleanup — clears it and a reinstall re-runs onboarding; a UserDefaults flag gets resurrected by cfprefsd and survives removal.
enum OnboardingState {
    private static let markerURL = AppPaths.applicationSupport()
        .appendingPathComponent("onboarded")

    /// True once onboarding has been shown.
    static var hasOnboarded: Bool {
        FileManager.default.fileExists(atPath: markerURL.path)
    }

    /// Records that onboarding has been shown; called at show-time so it stays one-time even if the user quits mid-flow.
    static func markShown() {
        try? Data().write(to: markerURL)
    }
}
