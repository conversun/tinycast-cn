import Foundation

/// The live level behind the slider and bar, published so a repeat refreshes in place.
@Observable
final class VolumeState {
    var level: Double
    var muted: Bool

    init(level: Double, muted: Bool = false) {
        self.level = level
        self.muted = muted
    }
}
