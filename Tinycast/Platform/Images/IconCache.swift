import AppKit

/// Caches app icons by file path, downsampled to a small fixed bitmap and byte-bounded, so list rows don't re-hit `NSWorkspace` or balloon memory.
enum IconCache {
    /// `NSCache` is thread-safe but not `Sendable`, so a detached decode populating what the main actor reads needs the guarantee asserted once here.
    private final class Cache: NSCache<NSString, NSImage>, @unchecked Sendable {}

    // 48pt (2× Retina) is plenty for the ≤24pt draw size, and keeping each icon small caps launcher memory since a scrolled `LazyVStack` pins every row's icon.
    private static let displayPixel: CGFloat = 48

    private static let cache: Cache = {
        let cache = Cache()
        cache.totalCostLimit = 32 * 1024 * 1024
        return cache
    }()

    /// Cache-only lookups (never decode) so a row can paint an already-warm icon on the same frame.
    static func cached(forFile path: String) -> NSImage? { cache.object(forKey: path as NSString) }
    static func cachedSymbol(named name: String) -> NSImage? {
        cache.object(forKey: ("symbol:" + name) as NSString)
    }

    /// A freshly-decoded, thereafter-immutable `NSImage` is safe to move across the actor boundary.
    private struct Decoded: @unchecked Sendable { let image: NSImage? }

    /// Return the decode directly (not a cache re-read) so an `NSCache` purge mid-decode can't strand a row on its placeholder. A missing path returns nil — not `NSWorkspace`'s broken-document icon — and never caches, so an uninstalled app can't leave a broken icon behind.
    static func loadAsync(forFile path: String) async -> NSImage? {
        if let cached = cached(forFile: path) { return cached }
        return await Task.detached(priority: .userInitiated) { () -> Decoded in
            guard FileManager.default.fileExists(atPath: path) else { return Decoded(image: nil) }
            return Decoded(image: icon(forFile: path))
        }.value.image
    }
    static func loadSymbolAsync(named name: String) async -> NSImage? {
        if let cached = cachedSymbol(named: name) { return cached }
        return await Task.detached(priority: .userInitiated) {
            Decoded(image: symbolIcon(named: name))
        }.value.image
    }

    static func icon(forFile path: String) -> NSImage {
        let key = path as NSString
        if let cached = cache.object(forKey: key) { return cached }
        let (icon, cost) = downsampled(NSWorkspace.shared.icon(forFile: path))
        cache.setObject(icon, forKey: key, cost: cost)
        return icon
    }

    /// Command "icons": an SF Symbol on a rounded tile, in the same bitmap shape as app icons so rows treat every entry identically.
    static func symbolIcon(named name: String) -> NSImage {
        let key = "symbol:" + name as NSString
        if let cached = cache.object(forKey: key) { return cached }

        let side = displayPixel
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { _ in
            // Tile inset mirrors the margin macOS app icons carry inside their canvas.
            let tile = NSRect(x: 0, y: 0, width: side, height: side).insetBy(dx: 4, dy: 4)
            NSColor.white.withAlphaComponent(0.09).setFill()
            NSBezierPath(roundedRect: tile, xRadius: 9, yRadius: 9).fill()

            guard let symbol = glyph(named: name, tint: .white.withAlphaComponent(0.85))
            else { return true }
            let size = symbol.size
            symbol.draw(
                in: NSRect(
                    x: (side - size.width) / 2, y: (side - size.height) / 2,
                    width: size.width, height: size.height))
            return true
        }
        let (icon, cost) = downsampled(image)
        cache.setObject(icon, forKey: key, cost: cost)
        return icon
    }

    /// Most tiles draw an SF Symbol, pre-tinted via `SymbolConfiguration`; names SF Symbols lacks (Bluetooth, a SIG trademark) fall back to a template asset tinted by compositing.
    private static func glyph(named name: String, tint: NSColor) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: 21, weight: .medium)
            .applying(.init(paletteColors: [tint]))
        if let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(config) {
            return symbol
        }
        guard let asset = NSImage(named: name) else { return nil }
        // A 24pt box lands the asset's ink at the ~22pt optical height the SF Symbols above draw at pointSize 21.
        let assetSize = NSSize(width: 24, height: 24)
        return NSImage(size: assetSize, flipped: false) { rect in
            asset.draw(in: rect)
            tint.set()
            rect.fill(using: .sourceAtop)
            return true
        }
    }

    /// The share of its square canvas a macOS **app** icon paints. Measured: folders paint 98% of the
    /// width and documents 69%, so a column mixing types reads ragged until they're scaled to match.
    private static let artworkExtent: CGFloat = 0.83

    /// Cache-only lookup for `loadFittedAsync`.
    static func cachedFitted(forFile path: String) -> NSImage? {
        cache.object(forKey: fittedKey(path))
    }

    /// Like `loadAsync`, but normalized so the painted artwork spans `artworkExtent` whatever the file
    /// type. An app icon comes back untouched; a folder or document shrinks to the same visual size.
    static func loadFittedAsync(forFile path: String) async -> NSImage? {
        if let cached = cachedFitted(forFile: path) { return cached }
        return await Task.detached(priority: .userInitiated) { () -> Decoded in
            guard FileManager.default.fileExists(atPath: path) else { return Decoded(image: nil) }
            return Decoded(image: fittedIcon(forFile: path))
        }.value.image
    }

    private static func fittedKey(_ path: String) -> NSString { ("fit:" + path) as NSString }

    private static func fittedIcon(forFile path: String) -> NSImage {
        let key = fittedKey(path)
        if let cached = cache.object(forKey: key) { return cached }
        let source = NSWorkspace.shared.icon(forFile: path)
        // Drawing the source into a `side`-square box makes its artwork span `side * extent`; solving
        // for `side * extent == displayPixel * artworkExtent` leaves an app icon exactly as it was.
        let extent = paintedExtent(source) ?? artworkExtent
        let side = displayPixel * artworkExtent / extent
        let inset = (displayPixel - side) / 2
        let (icon, cost) = rasterized(
            source, into: NSRect(x: inset, y: inset, width: side, height: side))
        cache.setObject(icon, forKey: key, cost: cost)
        return icon
    }

    /// The larger dimension of the icon's non-transparent artwork, as a fraction of its canvas.
    /// Measured at the raster's own 2× resolution: a 1× grid smears antialiased edges into the
    /// bounding box and over-reads the extent, which would shrink app icons that should stay put.
    private static func paintedExtent(_ source: NSImage) -> CGFloat? {
        let pixels = Int(displayPixel * 2)
        guard
            let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                bytesPerRow: 0, bitsPerPixel: 0),
            let ctx = NSGraphicsContext(bitmapImageRep: rep)
        else { return nil }
        rep.size = NSSize(width: pixels, height: pixels)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ctx
        source.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
        NSGraphicsContext.restoreGraphicsState()

        var minX = pixels, maxX = -1, minY = pixels, maxY = -1
        for y in 0..<pixels {
            for x in 0..<pixels {
                // A faint antialiased edge isn't artwork; 0.06 keeps a drop shadow from counting.
                guard let colour = rep.colorAt(x: x, y: y), colour.alphaComponent > 0.06 else {
                    continue
                }
                minX = min(minX, x)
                maxX = max(maxX, x)
                minY = min(minY, y)
                maxY = max(maxY, y)
            }
        }
        guard maxX >= 0 else { return nil }
        let side = max(maxX - minX + 1, maxY - minY + 1)
        return CGFloat(side) / CGFloat(pixels)
    }

    /// Rasterize the multi-rep workspace icon into one `displayPixel`-square bitmap, returning it and its decoded byte cost.
    private static func downsampled(_ source: NSImage) -> (NSImage, Int) {
        rasterized(source, into: NSRect(origin: .zero, size: NSSize(width: displayPixel, height: displayPixel)))
    }

    /// Draws `source` into `frame` on a `displayPixel`-square canvas.
    private static func rasterized(_ source: NSImage, into frame: NSRect) -> (NSImage, Int) {
        // Fixed 2× (not `NSScreen.main`, which is main-thread-only) so this can rasterize on a detached decode; 96px covers the ≤24pt draw on any display.
        let pixels = Int(displayPixel * 2)
        let fallbackCost = Int(displayPixel * displayPixel * 4)
        guard
            let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                bytesPerRow: 0, bitsPerPixel: 0)
        else { return (source, fallbackCost) }
        rep.size = NSSize(width: displayPixel, height: displayPixel)
        guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else {
            return (source, fallbackCost)
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ctx
        ctx.imageInterpolation = .high
        source.draw(in: frame)
        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: rep.size)
        image.addRepresentation(rep)
        return (image, rep.bytesPerRow * rep.pixelsHigh)
    }
}
