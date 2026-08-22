import AppKit

extension NSAppearance {
    /// `bestMatch` rather than a name comparison, so the vibrant and accessibility variants resolve too.
    var isDark: Bool { bestMatch(from: [.aqua, .darkAqua]) == .darkAqua }
}

extension NSColor {
    /// Built in sRGB, the space SwiftUI's `Color.white`/`.black` literals resolve in, so a token's
    /// dark branch is the same pixel as the `Color.white.opacity(_:)` it replaced.
    static func srgbInk(_ white: CGFloat, alpha: Double) -> NSColor {
        NSColor(srgbRed: white, green: white, blue: white, alpha: alpha)
    }
}
