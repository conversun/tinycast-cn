import AppKit

extension ClipDragPayload {
    /// The row tile is already cached at this size, so the preview costs no decode.
    private static let previewPixel: CGFloat = 64

    /// A link writes two types from one item, so the receiver takes whichever it reads.
    var dragItem: RowDragItem {
        switch self {
        case .file(let url):
            let tile =
                ImageThumbnail.cached(url, maxPixel: Self.previewPixel)
                ?? FilePreviewThumbnail.cached(url, maxPixel: Self.previewPixel)
            return .file(url, image: tile)
        case .link(let url, let text):
            let item = NSPasteboardItem()
            item.setString(url.absoluteString, forType: .URL)
            item.setString(text, forType: .string)
            return RowDragItem(writer: item, image: Self.textImage(text))
        case .text(let text):
            return RowDragItem(writer: text as NSString, image: Self.textImage(text))
        }
    }

    /// Drawn, not snapshotted: SwiftUI draws into layers, so `cacheDisplay` returns a clear bitmap.
    private static func textImage(_ copy: String) -> NSImage {
        let line = copy.replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespaces)
        let string = NSAttributedString(
            string: String(line.prefix(60)),
            attributes: [
                .font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor.labelColor
            ])
        let inset = NSSize(width: 10, height: 6)
        let text = string.size()
        let size = NSSize(
            width: min(text.width, 320) + inset.width * 2, height: text.height + inset.height * 2)
        return NSImage(size: size, flipped: false) { rect in
            NSColor.controlBackgroundColor.withAlphaComponent(0.95).setFill()
            NSBezierPath(
                roundedRect: rect, xRadius: Theme.Radius.thumbnail, yRadius: Theme.Radius.thumbnail
            ).fill()
            string.draw(
                in: NSRect(
                    x: inset.width, y: inset.height, width: rect.width - inset.width * 2,
                    height: text.height))
            return true
        }
    }
}
