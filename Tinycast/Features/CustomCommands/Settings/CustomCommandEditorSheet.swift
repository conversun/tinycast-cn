import SwiftUI

/// Add / edit sheet for a single custom command, presented from the Commands pane.
struct CustomCommandEditorSheet: View {
    let command: CustomCommand?

    @Environment(\.dismiss) private var dismiss
    @Environment(AppCore.self) private var core
    @State private var name: String
    @State private var shellCommand: String
    @State private var loadsShellEnvironment: Bool
    @State private var requiresConfirmation: Bool
    @State private var showsConfirmation: Bool
    @State private var errorMessage: String?

    init(command: CustomCommand?) {
        self.command = command
        _name = State(initialValue: command?.name ?? "")
        _shellCommand = State(initialValue: command?.command ?? "")
        _loadsShellEnvironment = State(initialValue: command?.loadsShellEnvironment ?? false)
        _requiresConfirmation = State(initialValue: command?.requiresConfirmation ?? false)
        _showsConfirmation = State(initialValue: command?.showsConfirmation ?? false)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            Text(command == nil ? "Add Custom Command" : "Edit Custom Command")
                .font(.title2.weight(.bold))

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Name")
                    .font(.callout.weight(.medium))
                TextField("Sleep Displays", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Command")
                    .font(.callout.weight(.medium))
                TextEditor(text: $shellCommand)
                    .font(.body.monospaced())
                    .scrollContentBackground(.hidden)
                    .padding(Theme.Spacing.sm)
                    .frame(height: Theme.Size.editorTextHeight)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous)
                            .fill(Theme.Colors.cardFill)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous)
                            .strokeBorder(Theme.Colors.cardStroke, lineWidth: 1)
                    )
            }

            Text("Example: /usr/bin/pmset displaysleepnow")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                optionToggle(
                    "Load shell environment", isOn: $loadsShellEnvironment,
                    detail: "Resolves aliases, functions and PATH. Slower to start.")
                optionToggle(
                    "Needs confirmation", isOn: $requiresConfirmation,
                    detail: "Ask before running this command.")
                optionToggle(
                    "Show confirmation", isOn: $showsConfirmation,
                    detail: "Confirm on screen after the command succeeds.")
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(
                        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || shellCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(Theme.Spacing.xxl)
        .frame(width: Theme.Size.editorSheetWidth)
    }

    private func optionToggle(
        _ title: String, isOn: Binding<Bool>, detail: String
    ) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(title)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .toggleStyle(.checkbox)
    }

    private func save() {
        // Editing keeps the UUID, and with it the command's favorite, visibility and hotkey references.
        let draft = CustomCommand(
            id: command?.id ?? UUID(), name: name, command: shellCommand,
            loadsShellEnvironment: loadsShellEnvironment,
            requiresConfirmation: requiresConfirmation,
            showsConfirmation: showsConfirmation)
        do {
            if command == nil {
                try core.customCommandCoordinator.addCustomCommand(draft)
            } else {
                try core.customCommandCoordinator.updateCustomCommand(draft)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
