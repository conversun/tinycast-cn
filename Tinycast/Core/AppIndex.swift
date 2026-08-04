import AppKit
import Combine

struct AppEntry: Identifiable, Hashable, Sendable {
    enum Kind: String, Sendable {
        case application
        case systemSettings
        case command
        case customCommand
        case snippet
        case systemAction
        case windowCommand
        case quicklink
    }

    let id: String  // file path (or "command:…" id) — always unique
    let name: String  // clean display name, never includes ".app"
    let url: URL
    let bundleID: String?
    let kind: Kind
    /// Extra strings this entry matches on as strongly as its name — a snippet's keyword. Empty for every other kind.
    var matchAliases: [String] = []
    /// Per-item SF Symbol, for the one kind whose glyph is the user's choice rather than its kind's. Nil elsewhere.
    var symbolName: String?
    /// Spotlight's `kMDItemAlternateNames`, ranked below the display name. Applications only.
    var alternateNames: [String] = []
    /// `CFBundleExecutable`, matched literally as a last resort. Applications only.
    var executableName: String?
    /// Latin readings of a Han-script name, ranked under Spotlight's own aliases.
    let romanizedAliases: [String]

    /// Readings are derived here rather than at the call sites, so no entry kind can be added without them.
    init(
        id: String, name: String, url: URL, bundleID: String?, kind: Kind,
        matchAliases: [String] = [], symbolName: String? = nil,
        alternateNames: [String] = [], executableName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.bundleID = bundleID
        self.kind = kind
        self.matchAliases = matchAliases
        self.symbolName = symbolName
        self.alternateNames = alternateNames
        self.executableName = executableName
        self.romanizedAliases = Pinyin.aliases(for: name)
    }

    /// Stable identity for learned ranking, favorites, and other per-entry preferences.
    var preferenceKey: String { bundleID ?? id }

    var searchFields: SearchFields {
        SearchFields(
            names: [name] + matchAliases, alternateNames: alternateNames,
            romanizedNames: romanizedAliases, bundleID: bundleID,
            executableName: executableName)
    }

    var kindLabel: String {
        switch kind {
        case .application: return "Application"
        case .systemSettings: return "System Setting"
        case .command: return "Command"
        case .customCommand: return "Custom Command"
        case .snippet: return "Snippet"
        case .systemAction: return "System Action"
        case .windowCommand: return "Window Command"
        case .quicklink: return "Quicklink"
        }
    }

    /// The global-hotkey action for this entry, or `nil` for built-in commands and unaddressable bundles.
    var hotKeyAction: HotKeyAction? {
        switch kind {
        case .application:
            return bundleID.map { .app(bundleID: $0) }
        case .systemSettings:
            return bundleID.map { .settingsPane(bundleID: $0) }
        case .customCommand:
            return CustomCommand.id(fromEntryID: id).map { .customCommand(id: $0) }
        case .systemAction:
            return SystemActionCatalog.action(forEntryID: id).map { .systemAction(id: $0.id) }
        case .windowCommand:
            return WindowCommandCatalog.command(forEntryID: id).map { .windowCommand(id: $0.id) }
        case .quicklink:
            return Quicklink.id(fromEntryID: id).map { .quicklink(id: $0) }
        case .command, .snippet:
            return nil
        }
    }

    /// Synthetic command entries have no file behind them to reveal. A quicklink's own entry is
    /// synthetic too — revealing the *destination* is an action on the record, in its own menu.
    var canRevealInFinder: Bool { kind == .application || kind == .systemSettings || kind == .snippet }

    /// Synthetic entries draw an SF Symbol tile; everything else uses its file icon.
    var isSymbolIcon: Bool { kind != .application && kind != .systemSettings }

    var symbolIconName: String {
        if let symbolName { return symbolName }
        switch kind {
        case .quicklink: return Quicklink.sfSymbol
        case .snippet: return "text.quote"
        case .customCommand: return CustomCommand.sfSymbol
        case .command: return CommandRegistry.command(for: self)?.sfSymbol ?? "questionmark"
        case .systemAction: return SystemActionCatalog.action(forEntryID: id)?.sfSymbol ?? "questionmark"
        case .windowCommand:
            return WindowCommandCatalog.command(forEntryID: id)?.sfSymbol ?? "questionmark"
        case .application, .systemSettings: return "questionmark"
        }
    }

    var icon: NSImage {
        isSymbolIcon
            ? IconCache.symbolIcon(named: symbolIconName) : IconCache.icon(forFile: url.path)
    }
}

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

@MainActor
final class AppIndex: ObservableObject {
    @Published private(set) var apps: [AppEntry] = []

    private var snippetEntries: [AppEntry] = []

    private struct MatchCache {
        let query: String
        let rankingRevision: Int
        let result: [AppEntry]
    }

    /// One-entry memo so repeated renders for the same query reuse the ranking instead of re-matching every frame.
    private var matchCache: MatchCache?

    private static let systemActionEntries: [AppEntry] = SystemActionCatalog.all
        .map { command in
            AppEntry(
                id: command.entryID, name: command.name,
                url: URL(string: "tinycast://system-action/" + command.id.rawValue)!,
                bundleID: nil, kind: .systemAction)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

    private static let allWindowCommandEntries: [AppEntry] = WindowCommandCatalog.all
        .map { command in
            AppEntry(
                id: command.entryID, name: command.name,
                url: URL(string: "tinycast://window-command/" + command.id.rawValue)!,
                bundleID: nil, kind: .windowCommand)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

    private var discoveredEntries: [AppEntry] = []
    private var customCommandEntries: [AppEntry] = []
    private var windowCommandEntries: [AppEntry] = []
    private var quicklinkEntries: [AppEntry] = []
    /// Built-in commands minus the quicklink ones while the feature is off.
    private var commandEntries: [AppEntry] = CommandRegistry.all
    private var alternateNameCache = SpotlightNames.Cache()
    private var isRefreshing = false
    /// Set when a refresh is requested mid-scan, so a scope edit landing during an in-flight scan isn't silently dropped.
    private var refreshPending = false
    private let ranking: LauncherRankingStore
    private var settings: AppSettings?
    private var cancellables: Set<AnyCancellable> = []

    init(ranking: LauncherRankingStore) {
        self.ranking = ranking
    }

    /// Replaces the user-authored command slice without rescanning disk so Settings edits reach launcher search immediately.
    func setCustomCommands(_ commands: [CustomCommand]) {
        let entries = commands.map { command in
            AppEntry(
                id: command.entryID, name: command.name,
                url: URL(string: "tinycast://custom-command/" + command.id.uuidString)!,
                bundleID: nil, kind: .customCommand)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        guard entries != customCommandEntries else { return }
        customCommandEntries = entries
        publishEntries()
    }

    /// Replaces the quicklink slice and, in the same publish, the built-in commands that only make
    /// sense while the feature is on — one call so a toggle can't leave the two out of step.
    func setQuicklinks(_ quicklinks: [Quicklink], commandsVisible: Bool) {
        let entries = quicklinks
            .filter(\.showsInRootSearch)
            .sorted(by: Quicklink.precedes)
            .map { quicklink in
                AppEntry(
                    id: quicklink.entryID, name: quicklink.name,
                    url: URL(string: "tinycast://quicklink/" + quicklink.id.uuidString)!,
                    bundleID: nil, kind: .quicklink,
                    symbolName: quicklink.iconSymbol
                        ?? QuicklinkDestination.detect(quicklink.link)?.defaultSymbol)
            }
        let commands = commandsVisible
            ? CommandRegistry.all
            : CommandRegistry.all.filter { entry in
                CommandRegistry.command(for: entry).map { !$0.isQuicklinkCommand } ?? true
            }
        guard entries != quicklinkEntries || commands != commandEntries else { return }
        quicklinkEntries = entries
        commandEntries = commands
        publishEntries()
    }

    /// Shows or hides the whole window-command slice; the catalog is static, so this is the on/off switch
    /// rather than a content update.
    func setWindowCommandsVisible(_ visible: Bool) {
        let entries = visible ? Self.allWindowCommandEntries : []
        guard entries != windowCommandEntries else { return }
        windowCommandEntries = entries
        publishEntries()
    }

    func updateSnippets(_ records: [StoredSnippet]) {
        let entries = records
            .filter { $0.snippet.isEnabled }
            .map { record in
                AppEntry(
                    id: "snippet:\(record.id)",
                    name: record.snippet.name,
                    url: record.fileURL,
                    bundleID: nil,
                    kind: .snippet,
                    matchAliases: [record.snippet.keyword].compactMap { $0 })
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        guard entries != snippetEntries else { return }
        snippetEntries = entries
        publishEntries()
    }

    /// Wires the search scopes, re-indexing when the user edits them so Settings changes land without waiting for the next launcher open.
    func start(settings: AppSettings) {
        self.settings = settings
        settings.$searchScopes
            .dropFirst()
            // @Published emits synchronously on the main actor (hence assumeIsolated), before the property is written, so the scan is deferred to a task that reads the settled value.
            .sink { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    Task { await self.refresh() }
                }
            }
            .store(in: &cancellables)
    }

    /// Re-scan (called on every launcher open); overlapping reopens collapse into one trailing scan and `apps` is only re-published when the set changed, so an unchanged reopen does no UI work.
    func refresh() async {
        guard !isRefreshing else {
            refreshPending = true
            return
        }
        isRefreshing = true
        defer { isRefreshing = false }
        repeat {
            refreshPending = false
            let scopes = settings?.searchScopes ?? SearchScopes.defaults
            let reusing = alternateNameCache
            let (found, cache) = await Task.detached(priority: .utility) {
                AppIndex.scan(scopes: scopes, cache: SpotlightNames.Cache(reusing: reusing))
            }.value
            alternateNameCache = cache
            guard found != discoveredEntries else { continue }
            discoveredEntries = found
            publishEntries()
        } while refreshPending
    }

    nonisolated private static func scan(
        scopes: [String], cache: SpotlightNames.Cache
    ) -> ([AppEntry], SpotlightNames.Cache) {
        var cache = cache
        var seenBundleIDs = Set<String>()
        var result: [AppEntry] = []
        for url in SearchScopes.appBundles(in: scopes) {
            let bundle = Bundle(url: url)
            let bundleID = bundle?.bundleIdentifier
            // Dedup by bundle id; the earliest scope wins.
            if let bundleID, !seenBundleIDs.insert(bundleID).inserted { continue }

            let name =
                (bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                ?? (bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String)
                ?? url.deletingPathExtension().lastPathComponent
            let executable = bundle?.object(forInfoDictionaryKey: "CFBundleExecutable") as? String
            result.append(
                AppEntry(
                    id: url.path, name: name, url: url, bundleID: bundleID,
                    kind: .application,
                    alternateNames: cache.alternateNames(for: url, displayName: name),
                    // A binary named after the app adds nothing the display name doesn't already cover.
                    executableName: executable.flatMap {
                        $0.caseInsensitiveCompare(name) == .orderedSame ? nil : $0
                    }))
        }
        // `publishEntries` appends snippets, custom commands and built-in commands after apps and Settings panes so the sectioned flat selection maps 1:1 onto rows.
        let apps = result.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        // Settings panes are `.appex` bundles, which carry no Spotlight alternate names.
        return (apps + SettingsPaneScanner.scan(), cache)
    }

    private func publishEntries() {
        // Each slice is already in its own display order — alphabetical, or pinned-first for quicklinks. The slice order is the launcher's section order (LauncherList mirrors it), so custom commands sit in their own section ahead of the built-ins.
        let updated =
            discoveredEntries + quicklinkEntries + snippetEntries + Self.systemActionEntries
            + windowCommandEntries + customCommandEntries + commandEntries
        guard updated != apps else { return }
        apps = updated
        matchCache = nil
    }

    /// Ranked matches. Empty query returns the full alphabetical list.
    func matches(_ query: String, limit: Int = 200) -> [AppEntry] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return apps }
        if let matchCache, matchCache.query == q,
            matchCache.rankingRevision == ranking.revision {
            return matchCache.result
        }
        let result = rank(q, limit: limit)
        matchCache = MatchCache(query: q, rankingRevision: ranking.revision, result: result)
        return result
    }

    private func rank(_ q: String, limit: Int) -> [AppEntry] {
        let learned = ranking.boosts(query: q)
        let scored = apps.compactMap { app -> (AppEntry, Int)? in
            // Base relevance comes from the entry's strongest matching field; the learned boost is added after and never knows which field that was.
            guard let score = SearchRelevance.score(query: q, fields: app.searchFields) else {
                return nil
            }
            return (app, score + (learned[app.preferenceKey] ?? 0))
        }
        return
            scored
            .sorted {
                $0.1 != $1.1
                    ? $0.1 > $1.1
                    : $0.0.name.localizedCaseInsensitiveCompare($1.0.name) == .orderedAscending
            }
            .prefix(limit)
            .map(\.0)
    }
}
