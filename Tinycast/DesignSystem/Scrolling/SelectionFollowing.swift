import SwiftUI

extension View {
    /// Publishes this row's frame while it holds the selection, so `scrollFollowsSelection` can see
    /// where the selection actually is. Only the selected row measures, so a sweep costs nothing.
    func selectionFrame(_ selected: Bool) -> some View {
        overlay {
            if selected {
                GeometryReader { geometry in
                    Color.clear
                        .preference(
                            key: SelectionFrameKey.self, value: geometry.frame(in: .scrollView))
                }
            }
        }
    }

    /// Keeps the keyboard selection inside the band between the floating bars, re-checking as the
    /// geometry settles instead of firing one `scrollTo` and hoping. Minimal scroll-to-visible reads
    /// the strip behind the bottom bar as visible, so a row landing there was never scrolled into
    /// view, and nothing looked again until the next key press. Needs `selectionFrame` on the rows.
    ///
    /// - Parameters:
    ///   - row: the selected row's scroll id, or nil when the screen has no selection.
    ///   - atOrigin: the selection sits on the first row, which restores the origin so that its
    ///     section header shows rather than scrolling the row flush to the top.
    func scrollFollowsSelection(
        _ scroll: ScrollIntent, row: String?, atOrigin: Bool, proxy: ScrollViewProxy
    ) -> some View {
        modifier(SelectionFollowing(scroll: scroll, row: row, atOrigin: atOrigin, proxy: proxy))
    }
}

private struct SelectionFrameKey: PreferenceKey {
    static var defaultValue: CGRect? { nil }

    static func reduce(value: inout CGRect?, nextValue: () -> CGRect?) {
        value = value ?? nextValue()
    }
}

private struct SelectionFollowing: ViewModifier {
    let scroll: ScrollIntent
    let row: String?
    let atOrigin: Bool
    let proxy: ScrollViewProxy

    @State private var band = Band(insetTop: 0, height: 0)
    @State private var selection: CGRect?
    /// True from a `follow` until the selection is inside the band: the pointer owns the list again
    /// the moment it is, so a wheel scroll afterwards can never be pulled back.
    @State private var following = false

    /// The geometry the rule reads: the band's height, and the inset whose settling moves the rest.
    private struct Band: Equatable {
        var insetTop: CGFloat
        var height: CGFloat
    }

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: Band.self) {
                Band(insetTop: $0.contentInsets.top, height: $0.containerSize.height)
            } action: { old, new in
                band = new
                // The header's inset settles a beat after the scroll view mounts, taking the
                // resting offset with it, so a standing `top` has to be restated.
                if scroll.kind == .top, old.insetTop != new.insetTop { proxy.scrollToOrigin() }
                align()
            }
            .onPreferenceChange(SelectionFrameKey.self) { frame in
                selection = frame
                align()
            }
            .onChange(of: scroll) { _, scroll in
                switch scroll.kind {
                case .top:
                    following = false
                    proxy.scrollToOrigin()
                case .follow:
                    following = true
                    align()
                }
            }
    }

    private func align() {
        guard following, let row else { return }
        if atOrigin {
            following = false
            return proxy.scrollToOrigin()
        }
        // Scrolled far enough by hand and the lazy stack has dropped the selected row, leaving
        // nothing to measure: bring it back by id, then re-check once it reports its frame.
        guard let selection else {
            return proxy.scrollTo(row, anchor: nil)
        }
        guard
            let edge = SelectionReveal.edge(
                rowTop: selection.minY, rowBottom: selection.maxY, band: band.height)
        else {
            following = false
            return
        }
        proxy.scrollTo(row, anchor: edge == .top ? .top : .bottom)
    }
}
