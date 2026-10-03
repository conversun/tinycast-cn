import PDFKit
import SwiftUI

/// A PDF drawn in process, where the wheel reaches it the way it reaches QuickLook's text view.
struct PDFSurface: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> PDFView {
        let view = PreviewPDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        return view
    }

    func updateNSView(_ view: PDFView, context: Context) {
        guard view.document?.documentURL != url else { return }
        view.document = PDFDocument(url: url)
    }

    static func dismantleNSView(_ view: PDFView, coordinator: ()) {
        view.document = nil
    }
}

/// Clicking a page must not move the keyboard off the search field.
private final class PreviewPDFView: PDFView, KeyboardFocusRefusing {}
