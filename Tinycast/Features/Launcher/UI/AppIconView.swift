import SwiftUI

/// Row icon decoding off the main thread; warm icons seed synchronously, so no flash.
struct AppIconView: View {
    let app: AppEntry
    @State private var image: NSImage?

    init(app: AppEntry) {
        self.app = app
        _image = State(
            initialValue: app.isSymbolIcon
                ? IconCache.cachedSymbol(named: app.symbolIconName)
                : IconCache.cached(forFile: app.url.path))
    }

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable()
            } else {
                RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            }
        }
        .task(id: app.id) {
            guard image == nil else { return }
            image =
                app.isSymbolIcon
                ? await IconCache.loadSymbolAsync(named: app.symbolIconName)
                : await IconCache.loadAsync(forFile: app.url.path)
        }
    }
}
