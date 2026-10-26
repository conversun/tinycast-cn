import SwiftUI

@MainActor
@Observable
final class ClipboardEditState {
    var text: String

    init(text: String) {
        self.text = text
    }
}

struct ClipboardEditField: View {
    @Environment(\.metrics) private var metrics
    @Bindable var state: ClipboardEditState

    var body: some View {
        ScrollView {
            // Code mode: smart quotes or autocorrect would corrupt a token or a link.
            FormTextArea(
                text: $state.text, selection: .constant(nil), focused: .constant(false),
                minimumHeight: metrics.size.dialogTextHeight,
                label: String(localized: "Clipboard entry"), isCode: true, moveFocus: { _ in }
            )
        }
        .frame(height: metrics.size.dialogTextHeight)
        .background(
            Theme.Colors.controlSurface,
            in: RoundedRectangle(cornerRadius: metrics.radius.row, style: .continuous))
    }
}
