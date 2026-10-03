import AppKit
import SwiftUI

/// Text QuickLook would show as an icon, set the way its own text preview sets a `.swift`.
struct PlainTextSurface: NSViewRepresentable {
    let text: String

    /// QuickLook's text preview, measured: the fixed-pitch font at 11pt behind a 3pt inset.
    private static let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.userFixedPitchFont(ofSize: 11)
            ?? .monospacedSystemFont(ofSize: 11, weight: .regular),
        .foregroundColor: NSColor.textColor
    ]
    private static let inset = NSSize(width: 3, height: 3)

    /// The text last set, so a re-render compares Swift strings rather than bridging the view's.
    final class Coordinator {
        var shown: String?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }
        // Unselectable, as QuickLook's is: a selectable view would take the search field's caret.
        textView.isEditable = false
        textView.isSelectable = false
        textView.textContainerInset = Self.inset
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard context.coordinator.shown != text,
            let textView = scrollView.documentView as? NSTextView
        else { return }
        context.coordinator.shown = text
        textView.textStorage?.setAttributedString(
            NSAttributedString(string: text, attributes: Self.attributes))
        textView.scroll(.zero)
    }
}
