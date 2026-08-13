import AppKit

@main
@MainActor
struct PaletteInputTests {
    static func main() {
        placeholderHidesWhileInputMethodTextIsMarked()
        print("Palette input tests passed.")
    }

    static func placeholderHidesWhileInputMethodTextIsMarked() {
        let state = PaletteState()
        var reportedStates: [Bool] = []
        state.onSearchMarkedTextChanged = { reportedStates.append($0) }
        check("an empty field shows its placeholder", state.showsSearchPlaceholder)

        let editor = NSTextView()
        editor.setMarkedText(
            NSAttributedString(string: "nihao"),
            selectedRange: NSRange(location: 5, length: 0),
            replacementRange: NSRange(location: NSNotFound, length: 0))
        state.setSearchHasMarkedText(PalettePanel.searchHasMarkedText(in: editor))

        check(
            "marked input method text hides the placeholder before the query commits",
            !state.showsSearchPlaceholder)
        check("marked text notifies only its visual listener", reportedStates == [true])

        editor.unmarkText()
        state.setSearchHasMarkedText(PalettePanel.searchHasMarkedText(in: editor))
        check("cancelling marked text restores the placeholder", state.showsSearchPlaceholder)
        check("cancelling marked text notifies its visual listener", reportedStates == [true, false])

        state.query = "你"
        check("committed text keeps the placeholder hidden", !state.showsSearchPlaceholder)

        state.setSearchHasMarkedText(true)
        state.prepare(mode: .launcher)
        check("preparing a new palette session clears marked text", state.showsSearchPlaceholder)
    }

    static func check(_ label: String, _ condition: @autoclosure () -> Bool) {
        guard condition() else {
            fputs("FAIL: \(label)\n", stderr)
            exit(1)
        }
    }
}
