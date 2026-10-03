import Foundation

/// Window management's shortcuts and lists in settings.json, each shortcut kept with its record.
@MainActor
struct WindowManagementSettingsFile {
    let sizes: CustomWindowSizeStore
    let layouts: WindowLayoutStore
    let rooms: RoomStore
    let hotKeys: HotKeyManager

    /// Built per read, because the keyboard layout and the Hyper chord both change at run time.
    private var spelling: HotKeySpelling {
        HotKeySpelling(
            characters: ASCIIKeyboardLayout.baseCharacters(for: 0..<128),
            hyperModifiers: KeyShortcut.displayedHyperChord().map(KeyShortcut.carbonModifiers(from:)))
    }

    func commandShortcutsBinding(for key: SettingsFileKey) -> SettingsFileBinding {
        SettingsFileBinding(
            key,
            read: {
                let spelling = self.spelling
                var texts: [WindowCommand.ID: String] = [:]
                for id in WindowCommand.ID.allCases {
                    texts[id] = hotKeys.binding(for: .windowCommand(id: id)).map(spelling.text(for:))
                }
                return WindowManagementFileFormat.json(commandShortcuts: texts)
            },
            write: { json in
                guard let decoded = WindowManagementFileFormat.commandShortcuts(from: json) else {
                    return [.invalidValue(key)]
                }
                let wanted = WindowCommand.ID.allCases.map { id in
                    Wanted(
                        action: .windowCommand(id: id), text: decoded.shortcuts[id],
                        label: "“\(id.rawValue)”")
                }
                return decoded.problems.map { .invalidEntry(key, $0) } + apply(wanted, key: key)
            })
    }

    func customSizesBinding(for key: SettingsFileKey) -> SettingsFileBinding {
        SettingsFileBinding(
            key,
            read: {
                let spelling = self.spelling
                return .array(
                    sizes.sizes.map { size in
                        WindowManagementFileFormat.json(
                            size, shortcut: shortcut(for: .customWindowSize(id: size.id), spelling))
                    })
            },
            write: { json in
                guard let decoded = WindowManagementFileFormat.customSizes(from: json) else {
                    return [.invalidValue(key)]
                }
                let kept = sizes.replace(with: decoded.records)
                let rule = "a name is empty or used twice"
                return report(decoded, kept: kept, kind: "custom size", rule: rule, key: key)
                    + applyShortcuts(
                        decoded.shortcuts, records: sizes.sizes.map { ($0.id, $0.name) },
                        bound: hotKeys.boundCustomWindowSizeIDs, kind: "custom size",
                        action: HotKeyAction.customWindowSize, key: key)
            })
    }

    func layoutsBinding(for key: SettingsFileKey) -> SettingsFileBinding {
        SettingsFileBinding(
            key,
            read: {
                let spelling = self.spelling
                return .array(
                    layouts.layouts.map { layout in
                        WindowManagementFileFormat.json(
                            layout, shortcut: shortcut(for: .windowLayout(id: layout.id), spelling))
                    })
            },
            write: { json in
                guard let decoded = WindowManagementFileFormat.layouts(from: json) else {
                    return [.invalidValue(key)]
                }
                let kept = layouts.replace(with: decoded.records)
                let rule = "a name is empty or used twice, or it has no apps"
                return report(decoded, kept: kept, kind: "layout", rule: rule, key: key)
                    + applyShortcuts(
                        decoded.shortcuts, records: layouts.layouts.map { ($0.id, $0.name) },
                        bound: hotKeys.boundWindowLayoutIDs, kind: "layout",
                        action: HotKeyAction.windowLayout, key: key)
            })
    }

    func roomsBinding(for key: SettingsFileKey) -> SettingsFileBinding {
        SettingsFileBinding(
            key,
            read: {
                let spelling = self.spelling
                return .array(
                    rooms.rooms.map { room in
                        WindowManagementFileFormat.json(
                            room, shortcut: shortcut(for: .windowRoom(id: room.id), spelling))
                    })
            },
            write: { json in
                guard let decoded = WindowManagementFileFormat.rooms(from: json) else {
                    return [.invalidValue(key)]
                }
                let learned = Dictionary(
                    rooms.rooms.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
                let kept = rooms.replace(
                    with: decoded.records.map { room in learned[room.id].map(room.keepingRuntime) ?? room })
                let rule = "a name is empty or used twice, or it has no windows"
                return report(decoded, kept: kept, kind: "room", rule: rule, key: key)
                    + applyShortcuts(
                        decoded.shortcuts, records: rooms.rooms.map { ($0.id, $0.name) },
                        bound: hotKeys.boundWindowRoomIDs, kind: "room",
                        action: HotKeyAction.windowRoom, key: key)
            })
    }

    // MARK: - Shortcuts

    private struct Wanted {
        let action: HotKeyAction
        let text: String?
        let label: String
    }

    private struct Change {
        let action: HotKeyAction
        let binding: HotKeyBinding
        let previous: HotKeyBinding?
        let label: String
        let text: String
    }

    private func shortcut(for action: HotKeyAction, _ spelling: HotKeySpelling) -> String? {
        hotKeys.binding(for: action).map(spelling.text(for:))
    }

    private func report<Record>(
        _ decoded: WindowManagementFileFormat.Decoded<Record>, kept: Int, kind: String,
        rule: String, key: SettingsFileKey
    ) -> [SettingsFileIssue] {
        var issues = decoded.problems.map { SettingsFileIssue.invalidEntry(key, $0) }
        let skipped = decoded.records.count - kept
        if skipped > 0 {
            let noun = skipped == 1 ? "1 \(kind) was" : "\(skipped) \(kind)s were"
            issues.append(.invalidEntry(key, "\(noun) skipped: \(rule)"))
        }
        return issues
    }

    /// A record the file dropped takes its shortcut with it; the rest follow their record.
    private func applyShortcuts(
        _ shortcuts: [UUID: String], records: [(id: UUID, name: String)], bound: [UUID],
        kind: String, action: (UUID) -> HotKeyAction, key: SettingsFileKey
    ) -> [SettingsFileIssue] {
        let live = Set(records.map(\.id))
        for id in bound where !live.contains(id) {
            hotKeys.setBinding(nil, for: action(id))
        }
        let wanted = records.map { record in
            Wanted(action: action(record.id), text: shortcuts[record.id], label: "\(kind) “\(record.name)”")
        }
        return apply(wanted, key: key)
    }

    /// Clears every changed binding first, so two shortcuts the file swaps never block each other.
    private func apply(_ wanted: [Wanted], key: SettingsFileKey) -> [SettingsFileIssue] {
        let spelling = self.spelling
        var issues: [SettingsFileIssue] = []
        var changes: [Change] = []
        for item in wanted {
            let current = hotKeys.binding(for: item.action)
            guard let text = item.text else {
                if current != nil { hotKeys.setBinding(nil, for: item.action) }
                continue
            }
            guard let binding = spelling.binding(from: text) else {
                issues.append(
                    .invalidEntry(key, "\(item.label): “\(text)” isn't a shortcut Tinycast can bind"))
                continue
            }
            guard binding != current else { continue }
            if current != nil { hotKeys.setBinding(nil, for: item.action) }
            changes.append(
                Change(
                    action: item.action, binding: binding, previous: current, label: item.label,
                    text: text))
        }
        for change in changes {
            guard let owner = hotKeys.conflictOwner(of: change.binding, excluding: change.action) else {
                hotKeys.setBinding(change.binding, for: change.action)
                continue
            }
            issues.append(.invalidEntry(key, "\(change.label): “\(change.text)” already runs \(owner)"))
            // The old binding returns when it is still free, so a clash never costs a working one.
            if let previous = change.previous,
                hotKeys.conflictOwner(of: previous, excluding: change.action) == nil
            {
                hotKeys.setBinding(previous, for: change.action)
            }
        }
        return issues
    }
}
