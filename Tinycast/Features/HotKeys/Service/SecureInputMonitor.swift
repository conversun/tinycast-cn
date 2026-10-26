import AppKit
import Carbon.HIToolbox
import IOKit

private typealias NotifyProc =
    @convention(c) (UInt32, UnsafeMutableRawPointer?, Int, UnsafeMutableRawPointer?) -> Void
private typealias NotifyRegistration =
    @convention(c) (NotifyProc, UInt32, UnsafeMutableRawPointer?) -> Int32

private let secureInputDidChange: NotifyProc = { _, _, _, context in
    guard let context else { return }
    let monitor = Unmanaged<SecureInputMonitor>.fromOpaque(context).takeUnretainedValue()
    Task { @MainActor in monitor.refresh() }
}

@MainActor
final class SecureInputMonitor {
    /// WindowServer's notifications for Secure Input turning on and off.
    private static let notificationTypes: [UInt32] = [752, 753]

    private(set) var isActive = false
    var onChange: ((Bool) -> Void)?

    private let notifyProcs = NotifyProcs()

    // The callback holds this object unretained, so the registration must not outlive it.
    isolated deinit {
        guard let remove = notifyProcs?.remove else { return }
        let context = Unmanaged.passUnretained(self).toOpaque()
        for type in Self.notificationTypes { _ = remove(secureInputDidChange, type, context) }
    }

    /// Follows SkyLight's private Secure Input notifications; without them, nothing is reported.
    func start() {
        refresh()
        guard let register = notifyProcs?.register else { return }
        let context = Unmanaged.passUnretained(self).toOpaque()
        for type in Self.notificationTypes { _ = register(secureInputDidChange, type, context) }
    }

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

private struct NotifyProcs {
    let register: NotifyRegistration
    let remove: NotifyRegistration

    init?() {
        guard
            let skyLight = dlopen(
                "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY),
            let register = dlsym(skyLight, "SLSRegisterNotifyProc"),
            let remove = dlsym(skyLight, "SLSRemoveNotifyProc")
        else { return nil }
        self.register = unsafeBitCast(register, to: NotifyRegistration.self)
        self.remove = unsafeBitCast(remove, to: NotifyRegistration.self)
    }
}
