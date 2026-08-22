import AppKit
import Foundation
import SwiftUI

@main
@MainActor
struct NotesEditorTests {
    private static var failures = 0

    static func main() async {
        _ = NSApplication.shared
        testLiteralEditingAndNativeCommands()
        testUndoIsolation()
        testCharacterCountReports()
        print(failures == 0 ? "Notes editor tests passed" : "\(failures) tests failed")
        exit(failures == 0 ? 0 : 1)
    }

    private static func testLiteralEditingAndNativeCommands() {
        let source = "# Heading\n\nThis is **bold** and [linked](https://example.com)."
        let input = NoteEditorInput(
            id: NoteID(rawValue: "Literal.md"),
            source: source,
            epoch: 1)
        var changes: [String] = []
        let editor = makeEditor(input: input, onSourceChange: { changes.append($0) })
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }

        check("the editor displays literal Markdown source", editor.textView.string == source)
        check("the plain editor enables native Find", editor.textView.usesFindPanel)

        let boldRange = (editor.textView.string as NSString).range(of: "**bold**")
        editor.textView.setSelectedRange(boldRange)
        copySelection(of: editor.textView, to: pasteboard)
        check(
            "native Copy preserves literal Markdown",
            pasteboard.string(forType: .string) == "**bold**")

        cutSelection(of: editor.textView, to: pasteboard)
        check("native Cut publishes one literal source update", changes.count == 1)
        check("native Cut removes the selected source", !editor.textView.string.contains("**bold**"))
        editor.coordinator.editorUndoManager.undo()
        check("native Undo restores the literal source", editor.textView.string == source)
        editor.coordinator.editorUndoManager.redo()
        check("native Redo restores the cut", editor.textView.string == changes.last)

        let end = (editor.textView.string as NSString).length
        editor.textView.setSelectedRange(NSRange(location: end, length: 0))
        paste(" [literal](url)", into: editor.textView, from: pasteboard)
        check("native Paste inserts exact source", editor.textView.string.hasSuffix(" [literal](url)"))

        let unicode = " 🧑🏽‍💻e\u{301}"
        editor.textView.insertText(unicode, replacementRange: editor.textView.selectedRange())
        check("emoji and combining marks remain exact", editor.textView.string.hasSuffix(unicode))

        let markedLocation = (editor.textView.string as NSString).length
        editor.textView.setSelectedRange(NSRange(location: markedLocation, length: 0))
        editor.textView.setMarkedText(
            "語",
            selectedRange: NSRange(location: 1, length: 0),
            replacementRange: NSRange(location: NSNotFound, length: 0))
        editor.textView.unmarkText()
        check("marked text commits through native AppKit editing", editor.textView.string.hasSuffix("語"))
        check("every published value equals the displayed source", changes.last == editor.textView.string)
    }

    private static func testUndoIsolation() {
        let first = NoteEditorInput(
            id: NoteID(rawValue: "First.md"),
            source: "First",
            epoch: 1)
        var changes: [String] = []
        let editor = makeEditor(input: first, onSourceChange: { changes.append($0) })
        editor.textView.setSelectedRange(NSRange(location: 5, length: 0))
        editor.textView.insertText(" edit", replacementRange: editor.textView.selectedRange())
        check("native editing registers Undo", editor.coordinator.editorUndoManager.canUndo)

        let second = NoteEditorInput(
            id: NoteID(rawValue: "Second.md"),
            source: "Second",
            epoch: 2)
        editor.coordinator.parent = view(for: second, onSourceChange: { changes.append($0) })
        editor.coordinator.update(second)
        check("switching notes installs the replacement source", editor.textView.string == "Second")
        check("switching notes clears stale Undo", !editor.coordinator.editorUndoManager.canUndo)
        editor.coordinator.editorUndoManager.undo()
        check("Undo after a switch leaves the new note intact", editor.textView.string == "Second")

        editor.textView.setSelectedRange(NSRange(location: 6, length: 0))
        editor.textView.insertText(" draft", replacementRange: editor.textView.selectedRange())
        let external = NoteEditorInput(id: second.id, source: "External", epoch: 3)
        editor.coordinator.parent = view(for: external, onSourceChange: { changes.append($0) })
        editor.coordinator.update(external)
        check("a clean external reload replaces the displayed source", editor.textView.string == "External")
        check("a clean external reload clears stale Undo", !editor.coordinator.editorUndoManager.canUndo)
    }

    private static func testCharacterCountReports() {
        let first = NoteEditorInput(id: NoteID(rawValue: "First.md"), source: "First", epoch: 1)
        var reports: [(NoteEditorInput, Int)] = []
        let editor = makeEditor(input: first, onCountChange: { reports.append(($0, $1)) })
        check("installing a note reports its length", reports.last?.1 == 5)

        editor.textView.selectAll(nil)
        editor.textView.insertText("Twelve chars", replacementRange: editor.textView.selectedRange())
        check("typing reports the new length", reports.last?.1 == 12)

        editor.textView.selectAll(nil)
        editor.textView.insertText("🇬🇧", replacementRange: editor.textView.selectedRange())
        check(
            "the count is the text storage's own UTF-16 length",
            reports.last?.1 == editor.textView.textStorage?.length)

        let second = NoteEditorInput(id: NoteID(rawValue: "Second.md"), source: "Second", epoch: 2)
        editor.coordinator.parent = view(for: second, onCountChange: { reports.append(($0, $1)) })
        editor.coordinator.update(second)
        check(
            "a stale count cannot be attributed to the replacement note",
            reports.last?.0.id == second.id && reports.last?.1 == 6)
    }

    /// The primitives `copy:`/`cut:`/`paste:` delegate to; the actions clobber the real clipboard.
    private static func copySelection(of textView: NSTextView, to pasteboard: NSPasteboard) {
        let types = textView.writablePasteboardTypes
        pasteboard.declareTypes(types, owner: nil)
        _ = textView.writeSelection(to: pasteboard, types: types)
    }

    private static func cutSelection(of textView: NSTextView, to pasteboard: NSPasteboard) {
        copySelection(of: textView, to: pasteboard)
        textView.delete(nil)
    }

    private static func paste(
        _ text: String, into textView: NSTextView, from pasteboard: NSPasteboard
    ) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        _ = textView.readSelection(from: pasteboard)
    }

    private static func makeEditor(
        input: NoteEditorInput,
        onSourceChange: @escaping (String) -> Void = { _ in },
        onCountChange: @escaping (NoteEditorInput, Int) -> Void = { _, _ in }
    ) -> (coordinator: NoteEditorView.Coordinator, textView: NoteTextView, window: NSWindow) {
        let view = view(
            for: input,
            onSourceChange: onSourceChange,
            onCountChange: onCountChange)
        let coordinator = NoteEditorView.Coordinator(parent: view)
        let textView = NoteTextView(usingTextLayoutManager: true)
        NoteEditorView.configure(textView)
        textView.delegate = coordinator
        textView.editorUndoManager = coordinator.editorUndoManager
        textView.setFrameSize(NSSize(width: 320, height: 1))
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 320, height: 180))
        scrollView.documentView = textView
        let window = NSWindow(
            contentRect: scrollView.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false)
        window.contentView = scrollView
        coordinator.textView = textView
        coordinator.install(input, resetUndo: false)
        window.makeFirstResponder(textView)
        return (coordinator, textView, window)
    }

    private static func view(
        for input: NoteEditorInput,
        onSourceChange: @escaping (String) -> Void = { _ in },
        onCountChange: @escaping (NoteEditorInput, Int) -> Void = { _, _ in }
    ) -> NoteEditorView {
        NoteEditorView(
            input: input,
            onSourceChange: onSourceChange,
            onCharacterCountChange: onCountChange,
            onReady: { _ in })
    }

    private static func check(_ message: String, _ condition: @autoclosure () -> Bool) {
        guard condition() else {
            failures += 1
            print("FAIL: \(message)")
            return
        }
    }
}
