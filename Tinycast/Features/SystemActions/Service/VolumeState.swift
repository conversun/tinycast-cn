import Foundation

/// The live level behind the slider and the HUD's bar. Published so a repeated command refreshes a
/// HUD already on screen instead of rebuilding it; the arithmetic lives in `VolumeLevel`.
@Observable
final class VolumeState {
    var level: Double
    var muted: Bool

    init(level: Double, muted: Bool = false) {
        self.level = level
        self.muted = muted
    }
}
