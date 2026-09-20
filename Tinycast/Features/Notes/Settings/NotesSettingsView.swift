import SwiftUI

struct NotesSettingsView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        return Form {
            Section {
                Toggle(isOn: $settings.notesEnabled) {
                    SettingsRowTitle(.notesNotes, "Enable Notes")
                    Text("Plain Markdown in a floating editor.")
                }
                Toggle(isOn: $settings.notesRendersMarkdown) {
                    SettingsRowTitle(.notesNotes, "Render Markdown")
                    Text("Formats as you type.")
                }
                .settingsEnabled(settings.notesEnabled)
                Toggle(isOn: $settings.notesShowsFormattingBar) {
                    SettingsRowTitle(.notesNotes, "Show Formatting Bar")
                }
                .settingsEnabled(settings.notesEnabled && settings.notesRendersMarkdown)
            } header: {
                SettingsSectionHeader(.notesNotes)
            }

            FeatureCommandsSection(owner: .notes, anchor: .notesCommands)
                .settingsEnabled(settings.notesEnabled)
        }
        .formStyle(.grouped)
        .settingsScrollTarget(.notes)
    }
}
