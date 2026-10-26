import Foundation

extension LocalizedStringResource {
    /// `String(localized:)` on a resource can bypass the bundle's table cache and reparse every call.
    func resolved() -> String {
        let value = Bundle.main.localizedString(forKey: key, value: nil, table: table)
        let needsArguments = value.contains("%")
        let needsDefault = value == key && defaultValue != String.LocalizationValue(key)
        return needsArguments || needsDefault ? String(localized: self) : value
    }
}
