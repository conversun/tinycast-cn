import AppKit
@preconcurrency import ApplicationServices

@MainActor
enum DictationInsertionContext {
    static func read(in target: InjectionTarget?) -> DictationTextFormatter.Context? {
        if let editor = target?.ownEditor {
            return context(editor.string, range: editor.selectedRange())
        }
        guard let app = target?.externalApp else { return nil }
        guard let element = AccessibilityText.focusedElement(in: app) else { return nil }
        var value: CFTypeRef?
        var selected: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value) == .success,
            let text = value as? String,
            AXUIElementCopyAttributeValue(
                element, kAXSelectedTextRangeAttribute as CFString, &selected) == .success,
            let selected, CFGetTypeID(selected) == AXValueGetTypeID()
        else { return nil }
        var range = CFRange()
        guard AXValueGetValue(unsafeDowncast(selected, to: AXValue.self), .cfRange, &range)
        else { return nil }
        return context(text, range: NSRange(location: range.location, length: range.length))
    }

    private static func context(_ text: String, range: NSRange) -> DictationTextFormatter.Context? {
        guard let selected = Range(range, in: text) else { return nil }
        return .init(
            before: text[..<selected.lowerBound],
            after: text[selected.upperBound...])
    }
}
