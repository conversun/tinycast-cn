import AppKit
import Carbon.HIToolbox
import IOKit

@MainActor
final class SecureInputMonitor {
    private(set) var isActive = false
    var onChange: ((Bool) -> Void)?

    /// Polled on the Hyper Key's health tick; reports each transition once.
    func refresh() {
        let active = IsSecureEventInputEnabled()
        guard active != isActive else { return }
        isActive = active
        onChange?(active)
    }

    func report() -> HyperKeyDiagnostics.SecureInput? {
        guard IsSecureEventInputEnabled() else { return nil }
        let owner = ownerProcessID().flatMap { NSRunningApplication(processIdentifier: $0) }
        let likelyOwners = NSWorkspace.shared.runningApplications.compactMap { app -> String? in
            guard let bundleID = app.bundleIdentifier,
                HyperKeyConflictPolicy.secureInputSuspects.contains(bundleID)
            else { return nil }
            return app.localizedName ?? bundleID
        }
        return HyperKeyDiagnostics.SecureInput(
            reportedOwner: owner.flatMap { $0.localizedName ?? $0.bundleIdentifier },
            ownerIsLoginWindow: owner?.bundleIdentifier == "com.apple.loginwindow",
            likelyOwners: Set(likelyOwners).sorted())
    }

    /// The holder's PID, recorded on this user's console session in the IOResources registry.
    private func ownerProcessID() -> pid_t? {
        let resources = IORegistryEntryFromPath(kIOMainPortDefault, "IOService:/IOResources")
        guard resources != IO_OBJECT_NULL else { return nil }
        defer { IOObjectRelease(resources) }
        let sessions =
            IORegistryEntryCreateCFProperty(
                resources, "IOConsoleUsers" as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue() as? [[String: Any]] ?? []
        let userID = getuid()
        return sessions.lazy
            .filter { ($0["kCGSSessionUserIDKey"] as? NSNumber)?.uint32Value == userID }
            .compactMap { ($0["kCGSSessionSecureInputPID"] as? NSNumber)?.int32Value }
            .first
    }
}
