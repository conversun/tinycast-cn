import SwiftUI

struct HyperKeyDiagnosticsSection: View {
    let diagnostics: HyperKeyDiagnostics
    let refresh: () -> Void
    let restart: () -> Void

    var body: some View {
        Section {
            SettingsRow(title: "Active") { yesNo(diagnostics.isActive) }
            SettingsRow(title: "Active Key") {
                DiagnosticValue(
                    text: diagnostics.activeKeyTitle ?? "None",
                    tone: diagnostics.activeKeyTitle == nil ? .invalid : .valid)
            }
            SettingsRow(title: "Event Tap") { optional(diagnostics.eventTapEnabled) }
            SettingsRow(title: "Run Loop Source") { optional(diagnostics.runLoopSourceValid) }
            if let secureInput = diagnostics.secureInput {
                SettingsRow(title: "Secure Input", subtitle: describe(secureInput), subtitleLineLimit: 4) {
                    DiagnosticValue(
                        text: "Active", tone: diagnostics.secureInputCompatibilityActive ? .valid : .invalid)
                }
            }
            if diagnostics.isActive {
                SettingsRow(title: "Remapped Keyboards", alignment: .top) {
                    DiagnosticList(items: remappedItems, empty: ("None", DiagnosticTone.neutral))
                }
            }
            SettingsRow(
                title: "Conflicting Apps", subtitle: "Apps running now that also remap keys.",
                alignment: .top
            ) {
                DiagnosticList(items: conflictItems, empty: ("None", DiagnosticTone.valid))
            }
            SettingsRow(title: "Karabiner Conflict", subtitle: karabinerDetail, subtitleLineLimit: 2) {
                DiagnosticValue(
                    text: diagnostics.karabinerConflict ? "Detected" : "None",
                    tone: diagnostics.karabinerConflict ? .invalid : .valid)
            }
            if !diagnostics.capsLockMappingConflicts.isEmpty {
                SettingsRow(
                    title: "Caps Lock Mapping Conflicts",
                    subtitle:
                        "Modifier Keys in System Settings remaps Caps Lock, which blocks the Hyper Key.",
                    subtitleLineLimit: 2, alignment: .top
                ) {
                    VStack(alignment: .trailing, spacing: Theme.Spacing.xs) {
                        DiagnosticList(items: capsLockConflictItems, empty: nil)
                        Button("Open Keyboard Settings…") {
                            AppLauncher.openSettingsPane(bundleID: "com.apple.Keyboard-Settings.extension")
                        }
                    }
                }
            }
        } header: {
            HStack {
                Text("Hyper Key Diagnostics")
                Spacer()
                Button("Restart Hyper Key", action: restart)
                Button("Refresh", action: refresh)
            }
        }
    }

    private var karabinerDetail: String {
        let keyboards = diagnostics.karabinerVirtualKeyboards
        return keyboards.isEmpty
            ? String(localized: "No Karabiner keyboard found.")
            : String(localized: "Karabiner keyboards: \(keyboards.joined(separator: ", "))")
    }

    private var remappedItems: [(String, DiagnosticTone)] {
        diagnostics.remappedKeyboards.map { ($0, DiagnosticTone.valid) }
    }

    private var conflictItems: [(String, DiagnosticTone)] {
        diagnostics.conflictingApps.map { app in
            (app.name, app.severity == .blocking ? DiagnosticTone.invalid : DiagnosticTone.warning)
        }
    }

    private var capsLockConflictItems: [(String, DiagnosticTone)] {
        diagnostics.capsLockMappingConflicts.map { ($0, DiagnosticTone.invalid) }
    }

    private func yesNo(_ flag: Bool) -> DiagnosticValue {
        DiagnosticValue(text: flag ? "Yes" : "No", tone: flag ? .valid : .invalid)
    }

    private func optional(_ flag: Bool?) -> DiagnosticValue {
        guard let flag else { return DiagnosticValue(text: "N/A", tone: .neutral) }
        return yesNo(flag)
    }

    /// macOS often names the wrong holder, so the likely ones lead and its claim is hedged.
    private func describe(_ secureInput: HyperKeyDiagnostics.SecureInput) -> String {
        var sentences = [
            diagnostics.secureInputCompatibilityActive
                ? String(localized: "Tinycast's Hyper shortcuts use Right Control while Secure Input is on.")
                : String(localized: "Key presses can't reach the Hyper Key while Secure Input is on.")
        ]
        if !secureInput.likelyOwners.isEmpty {
            let owners = secureInput.likelyOwners.joined(separator: String(localized: " or "))
            sentences.append(String(localized: "Probably \(owners)."))
        }
        if let owner = secureInput.reportedOwner {
            sentences.append(String(localized: "macOS names \(owner), which isn't always right."))
        }
        if !diagnostics.secureInputCompatibilityActive {
            sentences.append(
                secureInput.ownerIsLoginWindow
                    ? String(localized: "Logging out and back in turns it off.")
                    : String(localized: "Closing that app turns it off."))
        }
        return sentences.joined(separator: " ")
    }

    private enum DiagnosticTone {
        case valid, invalid, warning, neutral

        var color: Color {
            switch self {
            case .valid: return Theme.Colors.success
            case .invalid: return Theme.Colors.destructive
            case .warning: return Theme.Colors.warning
            case .neutral: return .secondary
            }
        }
    }

    private struct DiagnosticValue: View {
        let text: String
        let tone: DiagnosticTone

        var body: some View {
            HStack(spacing: Theme.Spacing.sm) {
                Text(text.localizedUI).foregroundStyle(tone.color)
                ColorDot(color: tone.color)
            }
        }
    }

    private struct DiagnosticList: View {
        let items: [(String, DiagnosticTone)]
        let empty: (String, DiagnosticTone)?

        var body: some View {
            VStack(alignment: .trailing, spacing: Theme.Spacing.xs) {
                if items.isEmpty, let empty {
                    DiagnosticValue(text: empty.0, tone: empty.1)
                }
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    DiagnosticValue(text: item.0, tone: item.1)
                }
            }
        }
    }
}
