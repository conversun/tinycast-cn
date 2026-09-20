import SwiftUI

/// The custom-size library, inside the Window Management pane beside the commands it extends.
struct CustomWindowSizesSection: View {
    let onEdit: (CustomWindowSize?) -> Void

    @Environment(CustomWindowSizeStore.self) private var store
    @Environment(CustomWindowSizeCoordinator.self) private var coordinator

    var body: some View {
        Section {
            ForEach(store.sizes) { size in
                CustomWindowSizeRow(
                    size: size,
                    onEdit: { onEdit(size) },
                    onDelete: { delete(size) })
            }
            Button {
                onEdit(nil)
            } label: {
                SettingsRowTitle(.windowManagementCustomSizes, "New Custom Size")
            }
        } header: {
            SettingsSectionHeader(.windowManagementCustomSizes)
        }
    }

    private func delete(_ size: CustomWindowSize) {
        Task { await coordinator.deleteCustomWindowSize(id: size.id) }
    }
}

/// One size's shortcut, launcher checkbox and actions, shaped like the window-command row.
private struct CustomWindowSizeRow: View {
    let size: CustomWindowSize
    let onEdit: () -> Void
    let onDelete: () -> Void

    @Environment(VisibilityStore.self) private var visibility

    var body: some View {
        SettingsRow(title: size.name, subtitle: summary) {
            Image(systemName: CustomWindowSize.sfSymbol)
        } trailing: {
            ShortcutRecorder(action: .customWindowSize(id: size.id))

            Button(action: onEdit) {
                Image(systemName: "pencil")
            }
            .buttonStyle(.plain)
            .help("Edit")
            .accessibilityLabel("Edit \(size.name)")

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundStyle(Theme.Colors.destructive)
            }
            .buttonStyle(.plain)
            .help("Delete")
            .accessibilityLabel("Delete \(size.name)")

            Toggle("", isOn: visibilityBinding)
                .labelsHidden()
                .toggleStyle(.checkbox)
                .launcherVisibilityHelp()
                .accessibilityLabel("Show \(size.name) in launcher")
        }
    }

    private var summary: String {
        let base = "\(size.width.label) × \(size.height.label) · \(size.anchor.title.localizedUI)"
        guard size.offset != .zero else { return base }
        let offset = String(localized: "Offset \(size.offset.x), \(size.offset.y) pt")
        return "\(base) · \(offset)"
    }

    private var visibilityBinding: Binding<Bool> {
        Binding(
            get: { visibility.isItemVisible(AppEntry(size)) },
            set: { visibility.setItemVisible($0, for: AppEntry(size)) })
    }
}
