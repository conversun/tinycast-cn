import SwiftUI

/// The file, by whichever surface suits it. Shared by the preview pane and the ⌘Y overlay.
struct FileSearchSurface: View {
    let url: URL
    var autoplays = false

    var body: some View {
        if FileSearchMediaPlayer.plays(url) {
            FileSearchMediaPlayer(url: url, autoplays: autoplays)
        } else {
            QuickLookSurface(url: url)
        }
    }
}
