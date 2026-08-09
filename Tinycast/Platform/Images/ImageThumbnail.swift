import AppKit
import ImageIO

/// Downsampled, memory-capped image loading: ImageIO decodes to exactly the size needed.
enum ImageThumbnail {
    /// `NSCache` is thread-safe but not `Sendable`, so assert the guarantee once here.
    private final class ImageCache: NSCache<NSString, NSImage>, @unchecked Sendable {}

    /// Row thumbnails, byte-bounded and kept warm, so re-opening draws instantly.
    private static let rowCache: ImageCache = {
        let cache = ImageCache()
        cache.totalCostLimit = 8 * 1024 * 1024
        return cache
    }()

    /// Large previews, byte-bounded and purged on close, so browsing memory stays flat.
    private static let previewCache: ImageCache = {
        let cache = ImageCache()
        cache.totalCostLimit = 48 * 1024 * 1024
        return cache
    }()

    /// Longest-edge size at or below which a decode is a "row" thumbnail; larger is a "preview".
    private static let rowThreshold: CGFloat = 128

    private static func pick(_ maxPixel: CGFloat) -> NSCache<NSString, NSImage> {
        maxPixel <= rowThreshold ? rowCache : previewCache
    }

    private static func cacheKey(_ url: URL, _ maxPixel: CGFloat) -> NSString {
        "\(url.path)#\(Int(maxPixel))" as NSString
    }

    /// Frees the preview bitmaps on dismiss; row thumbnails stay warm for a re-open.
    static func purgePreviews() {
        previewCache.removeAllObjects()
    }

    /// Cache-only, never touching disk, so a warm thumbnail renders on the same frame.
    static func cached(_ url: URL, maxPixel: CGFloat) -> NSImage? {
        pick(maxPixel).object(forKey: cacheKey(url, maxPixel))
    }

    /// A freshly-decoded, thereafter-immutable `NSImage` is safe to move across the actor boundary.
    private struct Decoded: @unchecked Sendable { let image: NSImage? }

    /// Returns the decode directly, so an eviction mid-decode can't strand a placeholder.
    static func loadAsync(_ url: URL, maxPixel: CGFloat) async -> NSImage? {
        if let cached = cached(url, maxPixel: maxPixel) { return cached }
        return await Task.detached(priority: .userInitiated) {
            Decoded(image: load(url, maxPixel: maxPixel))
        }.value.image
    }

    /// A thumbnail capped at `maxPixel`, cached per path and size; decodes synchronously.
    static func load(_ url: URL, maxPixel: CGFloat) -> NSImage? {
        let cache = pick(maxPixel)
        let key = cacheKey(url, maxPixel)
        if let cached = cache.object(forKey: key) { return cached }

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else { return nil }

        let image = NSImage(
            cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        // Cost = the decoded bitmap's real byte footprint, so `totalCostLimit` bounds actual RAM.
        cache.setObject(image, forKey: key, cost: cgImage.bytesPerRow * cgImage.height)
        return image
    }

    /// Pixel dimensions read from image metadata — no full decode.
    static func pixelSize(of url: URL) -> CGSize? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = props[kCGImagePropertyPixelWidth] as? Int,
            let height = props[kCGImagePropertyPixelHeight] as? Int
        else { return nil }
        return CGSize(width: width, height: height)
    }
}
