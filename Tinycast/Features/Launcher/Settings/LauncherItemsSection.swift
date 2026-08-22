import SwiftUI

/// One category's Settings sections; never filters by visibility, so hidden rows stay listed.
struct LauncherItemsSection: View {
    let kind: AppEntry.Kind
    let header: String
    let searchPrompt: String

    @Environment(AppIndex.self) private var appIndex
    @Environment(VisibilityStore.self) private var visibility
    @State private var query = ""

    private var entries: [AppEntry] {
        let scoped = appIndex.apps.filter { $0.kind == kind }
        guard !query.isEmpty else { return scoped }
        // Membership only: score order would move the row being edited out from under the caret.
        let matched = Set(appIndex.matches(query).map(\.id))
        return scoped.filter { matched.contains($0.id) }
    }

    var body: some View {
        Section {
            Toggle(isOn: kindBinding) {
                Text("Show in launcher")
                Text("Uncheck an item below to hide just that one.")
            }
        } header: {
            Text(header)
        }

        Section {
            SettingsFilterField(prompt: searchPrompt, query: $query)

            if entries.isEmpty {
                Text(query.isEmpty ? "Nothing here yet." : "No matches for “\(query)”.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                // One row holding a lazy stack: a `Form` realizes every row it is handed.
                LazyVStack(spacing: 0) {
                    ForEach(entries) { entry in
                        if entry.id != entries.first?.id { Divider() }
                        LauncherItemRow(entry: entry)
                            .padding(.vertical, Self.rowPadding)
                    }
                }
                .padding(.vertical, -Self.rowPadding)
            }
        }
        // Rows dim while the category is off but stay interactive, so one can still be re-hidden.
        .opacity(visibility.isKindVisible(kind) ? 1 : 0.45)
    }

    /// A grouped `Form` row's own vertical padding.
    private static let rowPadding: CGFloat = 15

    private var kindBinding: Binding<Bool> {
        Binding(
            get: { visibility.isKindVisible(kind) },
            set: { visibility.setKindVisible($0, for: kind) }
        )
    }
}

private struct LauncherItemRow: View {
    let entry: AppEntry
    @Environment(VisibilityStore.self) private var visibility

    var body: some View {
        SettingsRow(title: entry.name) {
            AppIconView(app: entry).frame(width: 18, height: 18)
        } trailing: {
            AliasField(entry: entry)
            if let action = entry.hotKeyAction {
                ShortcutRecorder(action: action)
            }
            Toggle("", isOn: itemBinding)
                .labelsHidden()
                .toggleStyle(.checkbox)
                .accessibilityLabel("Show \(entry.name) in launcher")
        }
    }

    private var itemBinding: Binding<Bool> {
        Binding(
            get: { visibility.isItemVisible(entry) },
            set: { visibility.setItemVisible($0, for: entry) }
        )
    }
}

/// Dressed like `ShortcutRecorder`; a persistent `TextField` — swapping views broke repeat focus.
private struct AliasField: View {
    let entry: AppEntry
    @Environment(AliasStore.self) private var aliases
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.menu, style: .continuous)
        let placeholder = Text("Add Alias").foregroundStyle(Theme.Colors.textSecondary)
        HStack(spacing: Theme.Spacing.xs) {
            TextField("", text: $draft, prompt: placeholder)
                .textFieldStyle(.plain)
                .labelsHidden()
                .font(Theme.Typography.keyCap)
                .focused($focused)
                // The system ring insets the field editor on focus, hopping the placeholder left.
                .focusEffectDisabled()
                .onSubmit(commit)
                .onExitCommand(perform: revert)
                // The pane's `releasesFocusOnOutsideClick` resigns; this catches it landing.
                .onChange(of: focused) { _, now in
                    if !now { commit() }
                }
            if !draft.isEmpty {
                Button(action: clear) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear alias for \(entry.name)")
            }
        }
        .onAppear { draft = aliases.alias(for: entry.preferenceKey) ?? "" }
        // A backup import replaces the table out from under an unfocused row.
        .onChange(of: aliases.revision) { _, _ in
            if !focused { draft = aliases.alias(for: entry.preferenceKey) ?? "" }
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .frame(width: Theme.Size.shortcutRecorder, height: 24)
        .background(shape.fill(Theme.Colors.cardFill))
        .overlay(
            shape.strokeBorder(
                focused ? Color.accentColor : Theme.Colors.cardStroke, lineWidth: 1)
        )
        .clipShape(shape)
        .accessibilityLabel("Alias for \(entry.name)")
    }

    /// The one commit path — ↵ or focus landing elsewhere; a blank draft removes the alias.
    private func commit() {
        aliases.setAlias(draft, for: entry.preferenceKey)
        draft = aliases.alias(for: entry.preferenceKey) ?? ""
    }

    private func revert() {
        draft = aliases.alias(for: entry.preferenceKey) ?? ""
        focused = false
    }

    private func clear() {
        draft = ""
        commit()
    }
}
