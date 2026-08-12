import CoreGraphics

/// Whether the selected row still needs moving, and to which edge. Pure: the row's frame and the
/// band both arrive measured, in the scroll view's own space where the band is `0…height` — the
/// region between the palette's floating bars, with the strip behind them already excluded.
enum SelectionReveal {
    enum Edge {
        case top
        case bottom
    }

    /// Rounding alone must not provoke a scroll, so a row flush with an edge counts as inside.
    private static let tolerance: CGFloat = 0.5

    /// The edge to align the row to, or nil once it sits inside the band and nothing need move.
    static func edge(rowTop: CGFloat, rowBottom: CGFloat, band: CGFloat) -> Edge? {
        // A row taller than the band can only ever show its start, so its top is as good as inside.
        if rowBottom - rowTop >= band {
            return rowTop < -tolerance || rowTop > tolerance ? .top : nil
        }
        if rowTop < -tolerance { return .top }
        if rowBottom > band + tolerance { return .bottom }
        return nil
    }
}
