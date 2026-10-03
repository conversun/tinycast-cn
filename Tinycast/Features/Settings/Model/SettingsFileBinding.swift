import Foundation

/// One settings.json key, bound to wherever the app keeps its value.
@MainActor
struct SettingsFileBinding {
    let key: SettingsFileKey
    let read: () -> SettingsFileJSON
    /// Returns what it could not use and leaves that part alone, so a typo never costs a setting.
    let write: (SettingsFileJSON) -> [SettingsFileIssue]

    init(
        _ key: SettingsFileKey, read: @escaping () -> SettingsFileJSON,
        write: @escaping (SettingsFileJSON) -> [SettingsFileIssue]
    ) {
        self.key = key
        self.read = read
        self.write = write
    }

    /// `accept` narrows or normalizes a value the type alone allows, returning nil to reject it.
    init<Root: AnyObject, Value: SettingsFileValue>(
        _ key: SettingsFileKey, _ root: Root, _ path: ReferenceWritableKeyPath<Root, Value>,
        accept: @escaping (Value) -> Value? = { $0 }
    ) {
        self.init(
            key,
            read: { root[keyPath: path].settingsJSON },
            write: { json in
                guard let value = Value(settingsJSON: json).flatMap(accept) else {
                    return [.invalidValue(key)]
                }
                // Assigning an equal value would still notify every observer of the property.
                if root[keyPath: path] != value { root[keyPath: path] = value }
                return []
            })
    }
}
