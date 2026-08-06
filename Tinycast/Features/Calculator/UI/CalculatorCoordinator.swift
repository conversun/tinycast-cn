import AppKit

/// Owns copying a calculation out: the inline card records history, a history row never re-records.
@MainActor
final class CalculatorCoordinator {
    private let calcHistory: CalculatorHistoryStore
    private let paletteCoordinator: PaletteCoordinator

    init(calcHistory: CalculatorHistoryStore, paletteCoordinator: PaletteCoordinator) {
        self.calcHistory = calcHistory
        self.paletteCoordinator = paletteCoordinator
    }

    /// Enter on the inline calculator card: copy the answer, remember the calculation, dismiss.
    func copyCalculatorResult(_ result: CalcResult) {
        guard case .value(let display, let copyText) = result.payload else { return }
        calcHistory.record(expression: result.expression, result: display)
        paletteCoordinator.hidePalette(restoreFocus: false)
        Paster.copyPlainText(copyText)
    }

    /// Enter on a Calculator History row: re-copy the stored answer (no re-record).
    func copyHistoryEntry(_ entry: CalcHistoryEntry) {
        paletteCoordinator.hidePalette(restoreFocus: false)
        Paster.copyPlainText(entry.result.replacingOccurrences(of: ",", with: ""))
    }

    func copyHistoryExpression(_ entry: CalcHistoryEntry) {
        paletteCoordinator.hidePalette(restoreFocus: false)
        Paster.copyPlainText(entry.expression)
    }
}
