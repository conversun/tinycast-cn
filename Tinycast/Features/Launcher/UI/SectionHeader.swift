import SwiftUI

/// Section label above a group of rows, shared by every palette list.
struct SectionHeader: View {
    let title: String
    /// The first header hugs the top; later ones get spacing above, reading as below.
    var isFirst = false
    var body: some View {
        Text(title.localizedUI)
            .font(Theme.Typography.sectionHeader)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.top, isFirst ? Theme.Spacing.xs : Theme.Spacing.sectionSpacing)
            .padding(.bottom, Theme.Spacing.sectionHeaderBottom)
    }
}
