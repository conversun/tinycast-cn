import Foundation

/// The grid the volume commands move on, and how a level reads. Pure and Foundation-only so
/// `Tools/volume-test.swift` compiles it standalone; CoreAudio lives in `SystemActionRunner`.
enum VolumeLevel {
    /// 20 steps of 5%, which keeps every level round and puts the 0/25/50/75/100 presets on the grid.
    static let steps = 20
    static let step = 1 / Double(steps)

    static func clamped(_ level: Double) -> Double {
        min(max(level, 0), 1)
    }

    /// Moves to the next grid line rather than past it: from an off-grid 37%, up lands on 40% and
    /// down on 35%. A level already on the grid moves a full step.
    static func stepped(_ level: Double, up: Bool) -> Double {
        let exact = clamped(level) * Double(steps)
        // The nudge absorbs binary error: 0.4 * 20 is 8.000000000000002, which would round up to 9 and leave a downward step standing still.
        let line =
            up ? (exact + tolerance).rounded(.down) + 1 : (exact - tolerance).rounded(.up) - 1
        return clamped(line / Double(steps))
    }

    static func percentage(_ level: Double) -> String {
        "\(Int((clamped(level) * 100).rounded()))%"
    }

    /// Shared by the HUD and the slider so one level never draws two different icons. Stops at two waves.
    static func symbol(level: Double, muted: Bool = false) -> String {
        let level = clamped(level)
        if muted || level == 0 { return "speaker.slash.fill" }
        return level < 0.5 ? "speaker.wave.1.fill" : "speaker.wave.2.fill"
    }

    private static let tolerance = 1e-6
}
