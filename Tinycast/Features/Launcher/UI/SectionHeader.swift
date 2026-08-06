import SwiftUI

/// Section label above a group of rows, shared by every palette list so they use one identical header + row layout.
struct SectionHeader: View {
    let title: String
    /// The list's first header hugs the top; every later header gets `sectionSpacing` above it, which reads as bottom padding on the section that just ended.
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
