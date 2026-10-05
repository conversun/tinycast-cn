import AppKit
import Foundation
import Observation

extension ExtensionTests {
    @MainActor
    @Observable
    final class MenuEvents {
        var revision = 0
        var stops = 0
        var foregroundRenders = 0
    }

    @MainActor
    final class MenuStateWait {
        private let condition: () -> Bool
        private var continuation: CheckedContinuation<Bool, Never>?
        private var result: Bool?
        private var timeout: Task<Void, Never>?
        private var actions: [NSKeyValueObservation] = []

        init(_ condition: @escaping () -> Bool) {
            self.condition = condition
            track()
            if result == nil {
                timeout = Task { [weak self] in
                    do { try await Task.sleep(for: .seconds(5)) } catch { return }
                    self?.finish(false)
                }
            }
        }

        private func track() {
            guard result == nil else { return }
            let ready = withObservationTracking {
                condition()
            } onChange: { [weak self] in
                Task { @MainActor in self?.track() }
            }
            if ready { finish(true) }
        }

        private func finish(_ value: Bool) {
            guard result == nil else { return }
            result = value
            timeout?.cancel()
            timeout = nil
            continuation?.resume(returning: value)
            continuation = nil
            actions.removeAll()
        }

        func watchActions(in menu: NSMenu, events: MenuEvents) {
            for item in menu.items where item.action != nil {
                actions.append(item.observe(\.representedObject) { [weak events] _, _ in
                    Task { @MainActor in events?.revision += 1 }
                })
            }
        }

        func wait(_ label: String) async {
            let ready: Bool
            if let result {
                ready = result
            } else {
                ready = await withCheckedContinuation { continuation = $0 }
            }
            check(label, ready, "state subscription timed out")
        }
    }

    @MainActor
    static func runInstalledMenuBar(_ owner: InstalledExtension, command: ExtensionCommand) async {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "tinycast-live-menu-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = ExtensionStorage(directory: directory.appendingPathComponent("storage"))
        for (key, value) in environmentPreferences() {
            storage.setPreference(extension: owner.manifest.name, key: key, value: value)
        }
        var hosts: [StubHost] = []
        var boots = 0
        weak var lastRuntime: ExtensionRuntime?
        let metadata = ExtensionCommandMetadataStore(
            fileURL: directory.appendingPathComponent("commands.json"))
        let manager = ExtensionMenuBarManager(
            storage: storage, commandMetadata: metadata,
            supportDirectory: directory.appendingPathComponent("support"), showsStatusItems: false,
            makeExecution: { _, _, _ in
                boots += 1
                let host = StubHost()
                hosts.append(host)
                let runtime = ExtensionRuntime(hostAPI: host, runtimeURL: runtimeURL())
                lastRuntime = runtime
                return .init(runtime: runtime, stop: {})
            }, onError: { message, _, _ in check("installed menu command", false, message) })
        defer { manager.stop() }
        let reference = ExtensionCommandRef(extensionName: owner.manifest.name, commandName: command.name)
        print("▶ Native menu lifecycle: \(owner.title) — \(command.title)")
        manager.synchronize([owner])
        manager.run(owner, command: command)
        for _ in 0..<200 where manager.isRunning { await settle(50) }
        check("real command settles and unloads", !manager.isRunning && lastRuntime == nil)
        check(
            "real command saves a native item",
            metadata.metadata(extension: owner.manifest.name, command: command.name)
                .menuBarSnapshot?.hasMenu == true)
        let controller = manager.controller(for: reference, owner: owner)
        for cycle in 1...3 {
            controller.menuWillOpen(controller.menu)
            let cachedActions = controller.menu.items.filter { $0.action != nil }
            check(
                "cycle \(cycle) cached actions are bright before boot",
                !cachedActions.isEmpty
                    && cachedActions.allSatisfy { $0.isEnabled && $0.representedObject == nil })
            await settle(1500)
            let items = controller.menu.items
            check("cycle \(cycle) renders provider sections", items.contains { $0.isSectionHeader })
            check(
                "cycle \(cycle) renders Configure",
                items.contains { $0.title == "Configure…" && $0.isEnabled })
            print("  cycle \(cycle): \(items.count) native menu rows, \(boots) context boots")
            if let index = items.firstIndex(where: { $0.title == "Refresh" }) {
                controller.menuDidClose(controller.menu)
                controller.menu.performActionForItem(at: index)
                for _ in 0..<200 where manager.isRunning { await settle(50) }
                check("cycle \(cycle) refresh finishes and unloads", !manager.isRunning && lastRuntime == nil)
            } else {
                check("real command offers Refresh", false)
                controller.menuDidClose(controller.menu)
            }
        }
        controller.menuWillOpen(controller.menu)
        if let index = controller.menu.items.firstIndex(where: { $0.title == "Open Provider Usage" }) {
            controller.menuDidClose(controller.menu)
            controller.menu.performActionForItem(at: index)
            for _ in 0..<200 where manager.isRunning { await settle(50) }
            check(
                "real command queues an immediate launchCommand click",
                hosts.last?.calls.contains("system.launchCommand") == true
                    && !manager.isRunning && lastRuntime == nil)
        }
        print("\(passes) passed, \(failures) failed; \(boots) fresh contexts")
    }

    @MainActor
    static func menuBarRenderingChecks() async {
        let controller = ExtensionMenuBarController(
            entryID: "tinycast-fixture-rendering", assetsPath: "/tmp", isVisible: false)
        defer { controller.remove() }
        controller.menuWillOpen(controller.menu)
        check("opening callback does not change menu structure", controller.menu.items.isEmpty)
        controller.menuDidClose(controller.menu)
        controller.menuNeedsUpdate(controller.menu)
        let placeholder = controller.menu.items.first
        check(
            "cold menu has content before opening",
            placeholder?.title == "Loading…"
                && placeholder?.isEnabled == false && !controller.isOpen)
        controller.menuNeedsUpdate(controller.menu)
        check(
            "repeated native preparation keeps one placeholder",
            controller.menu.items.count == 1
                && controller.menu.items.first === placeholder)
        let row = RenderNode(
            id: 2, type: "MenuBarExtra.Item",
            props: [
                "title": .string("Weekly · 17%"), "subtitle": .string("resets in 5d"),
                "icon": .string("star-16"), "onAction": .handler("refresh"),
                "shortcut": .object([
                    "macOS": .object([
                        "key": .string("pageDown"),
                        "modifiers": .array([.string("cmd")])
                    ])
                ])
            ])
        let root = RenderNode(id: 1, type: "MenuBarExtra", children: [row])
        controller.showMenu(root, session: "one")
        await settle(200)
        let item = controller.menu.items.first
        controller.menuNeedsUpdate(controller.menu)
        check("native preparation preserves cached content", controller.menu.items.first === item)
        check(
            "menu is prepared while closed",
            item?.title == "Weekly · 17% resets in 5d" && item?.image?.size.width == 14,
            "title=\(item?.title ?? "nil") image=\(String(describing: item?.image?.size))")
        check("menu contains only extension rows", controller.menu.items.count == 1)
        check(
            "macOS named shortcut maps to native key",
            item?.keyEquivalent == "\u{f72d}"
                && item?.keyEquivalentModifierMask == .command)
        check(
            "closed menu has inline secondary text",
            item?.attributedTitle?.string == "Weekly · 17% resets in 5d"
                && item?.subtitle == nil)
        controller.clearMenu()
        check(
            "unloading preserves action appearance without callbacks",
            item?.representedObject == nil && item?.isEnabled == true)
        controller.menuWillOpen(controller.menu)
        check("opening keeps prepared rows", controller.menu.items.first === item)
        let loading = RenderNode(id: 3, type: "MenuBarExtra", props: ["isLoading": .bool(true)], children: [])
        controller.showMenu(loading, session: "two")
        check(
            "loading keeps settled actions bright",
            controller.menu.items.first === item && item?.isEnabled == true)
        controller.showMenu(root, session: "two")
        check(
            "fresh session rebinds existing rows",
            controller.menu.items.first === item
                && item?.representedObject != nil && item?.isEnabled == true)
        let image = item?.image
        var changes = 0
        let observation = NotificationCenter.default.addObserver(
            forName: NSMenu.didChangeItemNotification,
            object: controller.menu, queue: nil
        ) { _ in
            MainActor.assumeIsolated { changes += 1 }
        }
        for _ in 0..<20 { controller.showMenu(root, session: "two") }
        NotificationCenter.default.removeObserver(observation)
        check(
            "repeated renders preserve rows and icons",
            controller.menu.items.first === item && item?.image === image)
        check(
            "identical renders cause no native layout updates", changes == 0, "\(changes) menu notifications")
        let props = row.props.merging(["subtitle": .string("resets in 4d")]) { _, value in value }
        let updated = RenderNode(id: 2, type: row.type, props: props)
        controller.showMenu(RenderNode(id: 1, type: root.type, children: [updated]), session: "two")
        check(
            "text changes update in place",
            controller.menu.items.first === item
                && item?.attributedTitle?.string == "Weekly · 17% resets in 4d")
        controller.menuDidClose(controller.menu)
        controller.clearMenu()
    }

    @MainActor
    static func menuBarPendingActionChecks() {
        let controller = ExtensionMenuBarController(
            entryID: "tinycast-fixture-pending-action", assetsPath: "/tmp",
            isVisible: false)
        defer { controller.remove() }
        var dispatched: [String] = []
        var opens = 0
        var unavailable = 0
        controller.onAction = { dispatched.append("\($0):\($1):\($2)") }
        controller.onOpen = { opens += 1 }
        controller.onActionUnavailable = { unavailable += 1 }
        func root(_ id: Int, title: String = "Run", duplicate: Bool = false) -> RenderNode {
            let rows = (0..<(duplicate ? 2 : 1)).map { index in
                RenderNode(
                    id: id + index, type: "MenuBarExtra.Item",
                    props: [
                        "title": .string(title), "onAction": .handler("handler-\(id + index)")
                    ])
            }
            return RenderNode(
                id: id + 2, type: "MenuBarExtra",
                children: [
                    RenderNode(
                        id: id + 3, type: "MenuBarExtra.Section", props: ["title": .string("Section")],
                        children: [
                            RenderNode(
                                id: id + 4, type: "MenuBarExtra.Submenu", props: ["title": .string("Nested")],
                                children: rows)
                        ])
                ])
        }
        func click() {
            let submenu = controller.menu.items.first { $0.submenu != nil }?.submenu
            check("cached submenu has a usable action", submenu?.items.first?.isEnabled == true)
            submenu?.performActionForItem(at: 0)
        }
        controller.showMenu(root(10), session: "old")
        controller.clearMenu()
        click()
        check(
            "cached clicks request a runtime without using stale handlers", dispatched.isEmpty && opens == 1)
        controller.showMenu(
            RenderNode(id: 1, type: "MenuBarExtra", props: ["isLoading": .bool(true)]), session: "new")
        check("cached click survives loading renders", dispatched.isEmpty)
        controller.showMenu(root(100), session: "new")
        check(
            "pending click binds to the fresh handler despite new node IDs",
            dispatched == ["new:handler-100:left-click"])
        controller.showMenu(root(100), session: "new")
        check("pending click dispatches only once", dispatched.count == 1)

        controller.clearMenu()
        click()
        controller.showMenu(root(100, title: "Different"), session: "changed")
        check("a reused node ID cannot redirect a cached click", dispatched.count == 1 && unavailable == 1)
        controller.showMenu(root(200), session: "before-duplicates")
        controller.clearMenu()
        click()
        controller.showMenu(root(300, duplicate: true), session: "duplicates")
        check("ambiguous fresh actions are rejected", dispatched.count == 1 && unavailable == 2)
        controller.clearMenu()
        let before = opens
        click()
        check("ambiguous cached actions are rejected before queuing", opens == before && unavailable == 3)

        controller.showMenu(root(400), session: "before-error")
        controller.clearMenu()
        click()
        controller.showError("Fixture failure")
        controller.showMenu(root(500), session: "after-error")
        check("failed refreshes discard pending clicks", dispatched.count == 1)
        controller.clearMenu()
        click()
        controller.clearMenu()
        controller.showMenu(root(600), session: "after-cancel")
        check("shutdown discards pending clicks", dispatched.count == 1)

        func section(_ name: String) -> RenderNode {
            RenderNode(
                id: 1, type: "MenuBarExtra",
                children: [
                    RenderNode(
                        id: 2, type: "MenuBarExtra.Section", props: ["title": .string(name)],
                        children: [
                            RenderNode(id: 3, type: "MenuBarExtra.Separator"),
                            RenderNode(
                                id: 4, type: "MenuBarExtra.Item",
                                props: [
                                    "title": .string("Open"), "onAction": .handler(name)
                                ])
                        ])
                ])
        }
        controller.showMenu(section("Account A"), session: "account-a")
        controller.clearMenu()
        controller.menu.performActionForItem(at: 2)
        controller.showMenu(section("Account B"), session: "account-b")
        check(
            "separators cannot hide a changed section from queued clicks",
            dispatched.count == 1 && unavailable == 4)

        func alternate(_ primary: String) -> RenderNode {
            RenderNode(
                id: 1, type: "MenuBarExtra",
                children: [
                    RenderNode(
                        id: 2, type: "MenuBarExtra.Item",
                        props: [
                            "title": .string(primary), "onAction": .handler(primary),
                            "alternate": .node(
                                RenderNode(
                                    id: 3, type: "MenuBarExtra.Item",
                                    props: [
                                        "title": .string("Reveal in Finder"),
                                        "onAction": .handler("reveal-" + primary)
                                    ]))
                        ])
                ])
        }
        controller.showMenu(alternate("Open File A"), session: "file-a")
        controller.clearMenu()
        controller.menu.performActionForItem(at: 1)
        controller.showMenu(alternate("Open File B"), session: "file-b")
        check(
            "alternate clicks retain their primary item's identity", dispatched.count == 1 && unavailable == 5
        )
    }

    @MainActor
    static func menuBarImageChecks() async {
        var pending: [CheckedContinuation<NSImage?, Never>] = []
        let controller = ExtensionMenuBarController(
            entryID: "tinycast-fixture-slow-image", assetsPath: "/tmp",
            isVisible: false,
            loadImage: { _, _, _ in
                await withCheckedContinuation { pending.append($0) }
            })
        defer { controller.remove() }
        func root(_ icon: String) -> RenderNode {
            RenderNode(
                id: 1, type: "MenuBarExtra",
                children: [
                    RenderNode(
                        id: 2, type: "MenuBarExtra.Submenu", props: ["title": .string("Actions")],
                        children: [
                            RenderNode(
                                id: 3, type: "MenuBarExtra.Item",
                                props: [
                                    "title": .string("Run"), "icon": .string(icon),
                                    "onAction": .handler("run")
                                ])
                        ])
                ])
        }
        controller.showMenu(root("slow"), session: "one")
        let item = controller.menu.items.first?.submenu?.items.first
        let placeholder = item?.image
        check(
            "slow icons do not block text or actions",
            item?.title == "Run" && item?.isEnabled == true
                && item?.representedObject != nil && placeholder?.size.width == 14)
        await settle(20)
        controller.showMenu(root("new"), session: "one")
        let oldImage = NSImage(size: NSSize(width: 14, height: 14))
        pending.removeFirst().resume(returning: oldImage)
        await settle(20)
        check(
            "obsolete icon replies cannot replace current artwork",
            item?.image === placeholder && pending.count == 1)
        controller.clearMenu()
        check(
            "unloading preserves submenu action appearance",
            item?.isEnabled == true && item?.representedObject == nil)
        let newImage = NSImage(size: NSSize(width: 14, height: 14))
        pending.removeFirst().resume(returning: newImage)
        await settle(20)
        check(
            "late images update rows without restoring expired callbacks",
            item?.image === newImage
                && item?.isEnabled == true && item?.representedObject == nil)

        var attempts: [CGFloat: Int] = [:]
        let retry = ExtensionMenuBarController(
            entryID: "tinycast-fixture-retry-image", assetsPath: "/tmp",
            isVisible: false,
            loadImage: { _, _, size in
                attempts[size, default: 0] += 1
                return attempts[size] == 1 ? nil : NSImage(size: NSSize(width: size, height: size))
            })
        defer { retry.remove() }
        let snapshot = ExtensionMenuBarSnapshot(
            node: RenderNode(
                id: 0, type: "MenuBarExtra",
                props: [
                    "icon": .string("retry"), "title": .string("Usage")
                ], children: root("retry").children))
        retry.update(snapshot)
        retry.showMenu(root("retry"), session: "one")
        await settle(20)
        for _ in 0..<20 {
            retry.update(snapshot)
            retry.showMenu(root("retry"), session: "one")
        }
        await settle(20)
        check("failed icons are attempted once per session", attempts[14] == 1 && attempts[18] == 1)
        retry.clearMenu()
        retry.showMenu(root("retry"), session: "two")
        await settle(20)
        check("next session retries unchanged menu and status icons", attempts[14] == 2 && attempts[18] == 2)
        retry.clearMenu()
        retry.showMenu(root("retry"), session: "three")
        await settle(20)
        check("successful icons remain cached across sessions", attempts[14] == 2 && attempts[18] == 2)
        retry.showMenu(root("other"), session: "three")
        await settle(20)
        retry.showMenu(root("retry"), session: "three")
        let returningPlaceholder = retry.menu.items.first?.submenu?.items.first?.image
        await settle(20)
        check(
            "returning to an evicted icon reloads it in the same session",
            attempts[14] == 4
                && retry.menu.items.first?.submenu?.items.first?.image !== returningPlaceholder)
    }

    @MainActor
    final class DelayedMenuHost: ExtensionHostAPI {
        var pending: [CheckedContinuation<String, Never>] = []
        var huds: [String] = []

        func perform(api: String, method: String, arguments: [RenderValue]) async throws -> String {
            if api == "clipboard" { return await withCheckedContinuation { pending.append($0) } }
            if api == "feedback", method == "showHUD" { huds.append(arguments.first?.stringValue ?? "") }
            return ""
        }

        func sessionEnded() {}
    }

    @MainActor
    static func lateMenuResponseChecks() async {
        let host = DelayedMenuHost()
        let runtime = ExtensionRuntime(hostAPI: host, runtimeURL: runtimeURL())
        defer {
            runtime.shutdown()
            for reply in host.pending { reply.resume(returning: "") }
        }
        let code = #"""
            const { Clipboard, showHUD } = require("@raycast/api");
            module.exports.default = async () => { await showHUD(await Clipboard.readText()); };
            """#
        let file = URL(fileURLWithPath: "/tmp/late-response.js")
        for session in ["old", "new"] {
            try? await runtime.boot(
                config: .current(supportDirectory: FileManager.default.temporaryDirectory))
            await runtime.start(
                session: session, code: code, file: file, mode: .noView, context: launchContext(mode: .noView)
            )
            await settle(100)
            if session == "old" { runtime.shutdown() }
        }
        guard host.pending.count == 2 else { check("both host requests wait", false); return }
        host.pending.removeFirst().resume(returning: #""old""#)
        await settle(100)
        check("late response cannot settle a fresh context", host.huds.isEmpty)
        host.pending.removeFirst().resume(returning: #""new""#)
        await settle(100)
        check("fresh context receives only its own response", host.huds == ["new"])
    }

    @MainActor
    final class MenuHost: ExtensionHostAPI {
        let name: String
        let storage: ExtensionStorage
        var didCancel = false
        var isInteractive = false
        let events: MenuEvents
        var pendingActions: [String: CheckedContinuation<String, Never>] = [:]
        var holdsReady = false
        var pendingReady: CheckedContinuation<String, Never>?
        var hasFetch = false
        var pendingFetch: CheckedContinuation<String, Error>?

        init(name: String, storage: ExtensionStorage, events: MenuEvents) {
            self.name = name
            self.storage = storage
            self.events = events
        }

        func perform(api: String, method: String, arguments: [RenderValue]) async throws -> String {
            if api == "feedback", method == "confirmAlert" { return isInteractive ? "true" : "false" }
            if api == "storage", method == "set", let key = arguments.first?.stringValue,
                let value = arguments.dropFirst().first.flatMap(
                    ExtensionStorage.StoredValue.init(renderValue:))
            {
                storage.setLocalStorage(extension: name, key: key, value: value)
                events.revision += 1
            }
            if api == "storage", method == "get",
                let key = arguments.first?.stringValue, key.hasPrefix("action-")
            {
                return await withCheckedContinuation {
                    pendingActions[key] = $0
                    events.revision += 1
                }
            }
            if api == "storage", method == "get",
                arguments.first?.stringValue == "ready", holdsReady
            {
                return await withCheckedContinuation {
                    pendingReady = $0
                    events.revision += 1
                }
            }
            if api == "fetch" {
                return try await withTaskCancellationHandler {
                    try await withCheckedThrowingContinuation {
                        pendingFetch = $0
                        hasFetch = true
                        events.revision += 1
                    }
                } onCancel: {
                    Task { @MainActor in
                        self.didCancel = true
                        self.pendingFetch?.resume(throwing: CancellationError())
                        self.pendingFetch = nil
                        self.events.revision += 1
                    }
                }
            }
            return ""
        }

        func sessionEnded() {
            for action in pendingActions.values { action.resume(returning: "") }
            pendingActions.removeAll()
            pendingReady?.resume(returning: "")
            pendingReady = nil
            events.revision += 1
        }

        func completeAction(_ number: Int) {
            pendingActions.removeValue(forKey: "action-\(number)")?.resume(returning: "")
        }
    }

    @MainActor
    static func menuBarHostChecks() async {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)
        await menuBarRenderingChecks()
        menuBarPendingActionChecks()
        await menuBarImageChecks()
        await lateMenuResponseChecks()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "tinycast-menu-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = ExtensionStorage(directory: directory.appendingPathComponent("storage"))
        let source = #"""
            const React = require("react");
            const { MenuBarExtra, LocalStorage, environment, confirmAlert } = require("@raycast/api");
            module.exports.default = function(props) {
              const [loading, setLoading] = React.useState(true);
              const [title, setTitle] = React.useState(environment.launchType);
              const actions = React.useRef(0);
              React.useEffect(() => {
                if (props.launchContext?.origin) LocalStorage.setItem("launch",
                  environment.launchType + ":" + props.arguments.value + ":" + props.launchContext.origin);
              }, []);
              React.useEffect(() => {
                LocalStorage.getItem("ready").then(() => setLoading(false));
              }, []);
              return React.createElement(MenuBarExtra, { title, isLoading: loading, icon: "star-16" },
                React.createElement(MenuBarExtra.Section, { title: "Usage" },
                  React.createElement(MenuBarExtra.Item, { title: "Information", subtitle: "Details", tooltip: "Tip" }),
                  React.createElement(MenuBarExtra.Item, { title: "Refresh", shortcut: { key: "r", modifiers: ["cmd"] },
                    alternate: React.createElement(MenuBarExtra.Item, { title: "Alternate", onAction() {} }),
                    onAction: async event => {
                      const action = ++actions.current;
                      await LocalStorage.getItem("action-" + action);
                      await LocalStorage.setItem("clicked", event.type);
                      await LocalStorage.setItem("completed", action);
                      setTitle("Updated");
                    } }),
                  React.createElement(MenuBarExtra.Submenu, { title: "Empty" }),
                  React.createElement(MenuBarExtra.Item, { title: "Confirm", onAction: async () => {
                    await LocalStorage.setItem("confirmed", await confirmAlert({ title: "Continue?" }));
                  } }),
                  React.createElement(MenuBarExtra.Submenu, { title: "Nested" },
                    React.createElement(MenuBarExtra.Item, { title: "Child", onAction() {} }))));
            };
            """#
        func owner(_ name: String, code: String, mode: String = "menu-bar") -> InstalledExtension {
            let path = directory.appendingPathComponent(name)
            try? FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
            try? code.write(to: path.appendingPathComponent("bar.js"), atomically: true, encoding: .utf8)
            let manifest = ExtensionManifest(json: [
                "name": name,
                "commands": [
                    [
                        "name": "bar", "title": "Bar", "mode": mode, "interval": "10m",
                        "disabledByDefault": true
                    ]
                ]
            ])!
            return InstalledExtension(manifest: manifest, directory: path)
        }
        let first = owner("first", code: source)
        let second = owner("second", code: source)
        let empty = owner("empty", code: "module.exports.default = () => null;")
        let hanging = owner(
            "hanging",
            code: #"""
                const React = require("react");
                const { MenuBarExtra } = require("@raycast/api");
                module.exports.default = () => {
                  React.useEffect(() => { fetch("https://fixture.invalid"); }, []);
                  return React.createElement(MenuBarExtra, { title: "Loading", isLoading: true });
                };
                """#)
        let job = owner(
            "job",
            code: #"""
                const { LocalStorage, environment } = require("@raycast/api");
                module.exports.default = async props => {
                  await LocalStorage.setItem("context", environment.launchType + ":" + props.launchContext.origin);
                };
                """#, mode: "no-view")
        let installed = [first, second, empty, hanging, job]
        let firstRef = ExtensionCommandRef(extensionName: "first", commandName: "bar")
        var boots: [(String, ExtensionLaunchType)] = []
        var failures: [String] = []
        var hosts: [MenuHost] = []
        let events = MenuEvents()
        var holdsReady = false
        weak var lastRuntime: ExtensionRuntime?
        let metadataFile = directory.appendingPathComponent("commands.json")
        let metadata = ExtensionCommandMetadataStore(fileURL: metadataFile)
        let manager = ExtensionMenuBarManager(
            storage: storage, commandMetadata: metadata,
            supportDirectory: directory.appendingPathComponent("support"), executionTimeout: .seconds(1),
            showsStatusItems: false,
            makeExecution: { owner, _, type in
                boots.append((owner.manifest.name, type))
                let host = MenuHost(name: owner.manifest.name, storage: storage, events: events)
                host.holdsReady = holdsReady
                host.isInteractive = type == .userInitiated
                hosts.append(host)
                let runtime = ExtensionRuntime(hostAPI: host, runtimeURL: runtimeURL())
                lastRuntime = runtime
                return .init(
                    runtime: runtime, stop: { events.stops += 1 },
                    enableInteraction: { host.isInteractive = true })
            }, onError: { message, _, _ in failures.append(message) })
        defer { manager.stop() }
        manager.synchronize(installed)
        func snapshot(_ reference: ExtensionCommandRef) -> ExtensionMenuBarSnapshot? {
            metadata.metadata(extension: reference.extensionName, command: reference.commandName)
                .menuBarSnapshot
        }
        func idle(after count: Int) -> MenuStateWait {
            MenuStateWait { events.stops >= count && !manager.isRunning }
        }
        func ready(_ controller: ExtensionMenuBarController, _ reference: ExtensionCommandRef) -> MenuStateWait {
            let wait = MenuStateWait {
                _ = events.revision
                _ = metadata.metadata(extension: reference.extensionName, command: reference.commandName)
                return controller.menu.items.contains { $0.representedObject != nil }
            }
            wait.watchActions(in: controller.menu, events: events)
            return wait
        }
        func actionStarted(_ number: Int) -> MenuStateWait {
            MenuStateWait {
                _ = events.revision
                return hosts.last?.pendingActions["action-\(number)"] != nil
            }
        }
        func unloaded(_ wait: MenuStateWait) async {
            await wait.wait("menu session reaches idle")
            await lastRuntime?.drainHostCalls()
        }
        /// Backdating the last run is what the scheduler reads as due, the way a restart would.
        func makeOverdue(_ reference: ExtensionCommandRef) {
            metadata.recordMenuBarRun(
                extension: reference.extensionName, command: reference.commandName, now: .distantPast)
        }
        check("install does not run a menu command", boots.isEmpty && metadata.menuBarCommands().isEmpty)
        let initialIdle = idle(after: boots.count + 1)
        manager.run(first, command: first.manifest.commands[0])
        await unloaded(initialIdle)
        check("settled menu keeps only a snapshot", !manager.isRunning && lastRuntime == nil)
        check("manual launch snapshots title", snapshot(firstRef)?.title == "userInitiated")
        check(
            "manifest interval schedules next refresh",
            metadata.metadata(extension: "first", command: "bar").lastRun != nil)

        let controller = manager.controller(for: firstRef, owner: first)
        let openingReady = ready(controller, firstRef)
        controller.menuWillOpen(controller.menu)
        await openingReady.wait("opening binds fresh menu actions")
        check("opening a menu reloads its runtime", boots.count == 2 && manager.isRunning)
        let items = controller.menu.items
        check("native section header", items.first?.isSectionHeader == true && items.first?.title == "Usage")
        check(
            "informational row is disabled",
            items.first { $0.title == "Information Details" }?.isEnabled == false)
        check(
            "inline subtitle and tooltip",
            items.first { $0.title == "Information Details" }?.attributedTitle?.string
                == "Information Details" && items.first { $0.title == "Information Details" }?.subtitle == nil
                && items.first { $0.title == "Information Details" }?.toolTip == "Tip")
        check("empty submenu is disabled", items.first { $0.title == "Empty" }?.isEnabled == false)
        check(
            "nested menu retains children",
            items.first { $0.title == "Nested" }?.submenu?.items.first?.title == "Child")
        let alternate = items.first { $0.title == "Alternate" }
        check(
            "alternate inherits shortcut and adds option",
            alternate?.isAlternate == true
                && alternate?.keyEquivalent == "r"
                && alternate?.keyEquivalentModifierMask == [.command, .option])
        try? await Task.sleep(for: .milliseconds(1100))
        check("an open settled menu outlives background timeout", manager.isRunning)
        if let index = controller.menu.items.firstIndex(where: { $0.title == "Refresh" }) {
            let started = actionStarted(1)
            let actionIdle = idle(after: boots.count)
            controller.menuDidClose(controller.menu)
            controller.menu.performActionForItem(at: index)
            await started.wait("first async menu action enters host gate")
            check("closing menu does not cancel an async action", manager.isRunning)
            hosts.last?.completeAction(1)
            await unloaded(actionIdle)
            check(
                "action writes into its own extension",
                storage.localStorageValue(extension: "first", key: "clicked")
                    == .string("left-click")
                    && storage.localStorageValue(extension: "second", key: "clicked") == nil)
            check(
                "action snapshot updates before unloading",
                snapshot(firstRef)?.title == "Updated"
                    && !manager.isRunning && lastRuntime == nil)
        } else {
            check("refresh action exists", false)
        }

        let reopenReady = ready(controller, firstRef)
        controller.menuWillOpen(controller.menu)
        await reopenReady.wait("reopening binds fresh menu actions")
        let beforeReopen = boots.count
        storage.setLocalStorage(extension: "first", key: "completed", value: .number(0))
        if let index = controller.menu.items.firstIndex(where: { $0.title == "Refresh" }) {
            let firstStarted = actionStarted(1)
            controller.menuDidClose(controller.menu)
            controller.menu.performActionForItem(at: index)
            await firstStarted.wait("reopened action enters first gate")
            controller.menuWillOpen(controller.menu)
            check("reopening preserves an unfinished action's runtime", boots.count == beforeReopen)
            let secondStarted = actionStarted(2)
            controller.menu.performActionForItem(at: index)
            await secondStarted.wait("overlapping action enters second gate")
            controller.menuDidClose(controller.menu)
        } else {
            check("refresh exists after reopening", false)
        }
        let secondRef = ExtensionCommandRef(extensionName: "second", commandName: "bar")
        metadata.setMenuBarEnabled(true, extension: "second", command: "bar")
        let secondController = manager.controller(for: secondRef, owner: second)
        let secondReady = ready(secondController, secondRef)
        let firstHost = hosts.last
        secondController.menuWillOpen(secondController.menu)
        check(
            "another menu waits for every overlapping action",
            boots.count == beforeReopen && manager.isRunning)
        let firstCompleted = MenuStateWait {
            _ = events.revision
            return storage.localStorageValue(extension: "first", key: "completed") == .number(1)
        }
        firstHost?.completeAction(1)
        await firstCompleted.wait("first overlapping action completes")
        check(
            "queued menu still waits for the second action",
            boots.count == beforeReopen && manager.isRunning)
        firstHost?.completeAction(2)
        await secondReady.wait("queued second menu binds after both actions")
        check(
            "both actions finish before the queued menu opens",
            boots.last?.0 == "second"
                && storage.localStorageValue(extension: "first", key: "completed") == .number(2))
        let secondIdle = idle(after: boots.count)
        secondController.menuDidClose(secondController.menu)
        await unloaded(secondIdle)
        check("reopened action sessions unload after closing", !manager.isRunning && lastRuntime == nil)

        let payloadReady = ready(controller, firstRef)
        controller.menuWillOpen(controller.menu)
        await payloadReady.wait("payload test opens first menu")
        let payloadIdle = idle(after: boots.count + 1)
        manager.run(
            second, command: second.manifest.commands[0], arguments: ["value": "kept"],
            type: .background, context: ["origin": .string("payload")])
        makeOverdue(secondRef)
        manager.synchronize(installed)
        controller.menuDidClose(controller.menu)
        await unloaded(payloadIdle)
        check(
            "scheduled refresh preserves an explicit background launch's payload",
            storage.localStorageValue(extension: "second", key: "launch")
                == .string("background:kept:payload")
                && !manager.isRunning)

        let promotedReady = ready(controller, firstRef)
        manager.run(first, command: first.manifest.commands[0], type: .background)
        let backgroundBoots = boots.count
        check("background hosts begin without interactive prompts", hosts.last?.isInteractive == false)
        controller.menuWillOpen(controller.menu)
        await promotedReady.wait("promoted background menu binds actions")
        check(
            "opening promotes the existing background host",
            boots.count == backgroundBoots
                && hosts.last?.isInteractive == true)
        if let index = controller.menu.items.firstIndex(where: { $0.title == "Confirm" }) {
            let confirmIdle = idle(after: boots.count)
            controller.menuDidClose(controller.menu)
            controller.menu.performActionForItem(at: index)
            await unloaded(confirmIdle)
            check(
                "actions can confirm after opening a background refresh",
                storage.localStorageValue(extension: "first", key: "confirmed") == .bool(true)
                    && !manager.isRunning)
        } else {
            check("confirmation action exists", false)
        }

        storage.setLocalStorage(extension: "first", key: "confirmed", value: .bool(false))
        let beforeEarlyClick = boots.count
        let earlyIdle = idle(after: beforeEarlyClick + 1)
        controller.menuWillOpen(controller.menu)
        if let index = controller.menu.items.firstIndex(where: { $0.title == "Confirm" }) {
            let item = controller.menu.items[index]
            check(
                "opening a cached menu keeps actions bright before boot",
                item.isEnabled && item.representedObject == nil)
            controller.menuDidClose(controller.menu)
            controller.menu.performActionForItem(at: index)
            await unloaded(earlyIdle)
            check(
                "clicking immediately after opening runs the fresh action and unloads",
                storage.localStorageValue(extension: "first", key: "confirmed") == .bool(true)
                    && boots.count == beforeEarlyClick + 1 && !manager.isRunning && lastRuntime == nil)
        } else {
            check("early confirmation action exists", false)
        }

        let overdueIdle = idle(after: boots.count + 1)
        makeOverdue(firstRef)
        manager.synchronize(installed)
        await unloaded(overdueIdle)
        check("overdue refresh runs with background launch type", boots.last?.1 == .background)
        check("background refresh unloads", !manager.isRunning && lastRuntime == nil)
        metadata.flush()
        let restored = ExtensionCommandMetadataStore(fileURL: metadataFile)
        check(
            "button snapshot survives restart",
            restored.metadata(extension: "first", command: "bar")
                == metadata.metadata(extension: "first", command: "bar"))
        let bootCount = boots.count
        manager.stop()
        manager.synchronize(installed)
        check("restoring a saved item executes no JavaScript", boots.count == bootCount)

        let queueIdle = idle(after: boots.count + 2)
        manager.run(first, command: first.manifest.commands[0])
        manager.run(second, command: second.manifest.commands[0])
        await unloaded(queueIdle)
        check(
            "queued refreshes finish serially",
            boots.suffix(2).map(\.0) == ["first", "second"] && !manager.isRunning)
        let emptyIdle = idle(after: boots.count + 1)
        manager.run(empty, command: empty.manifest.commands[0])
        await unloaded(emptyIdle)
        check(
            "null removes item without forgetting activation",
            metadata.metadata(extension: "empty", command: "bar").menuBarEnabled
                && metadata.metadata(extension: "empty", command: "bar").menuBarSnapshot == nil
                && !manager.isRunning)
        let (foreground, _, recorder) = makeRuntime()
        defer { foreground.shutdown() }
        recorder.onRender = { events.foregroundRenders += 1 }
        try? await foreground.boot(config: .current(supportDirectory: directory))
        let foregroundStarted = MenuStateWait { events.foregroundRenders > 0 }
        await foreground.start(
            session: "foreground",
            code: #"""
                const React = require("react");
                const { Detail } = require("@raycast/api");
                module.exports.default = () => {
                  const [count, setCount] = React.useState(0);
                  React.useEffect(() => { setInterval(() => setCount(value => value + 1), 40); }, []);
                  return React.createElement(Detail, { markdown: String(count) });
                };
                """#, file: directory.appendingPathComponent("foreground.js"), mode: .view,
            context: launchContext())
        await foregroundStarted.wait("foreground starts rendering")
        let foregroundRenders = recorder.trees.count
        let jobIdle = idle(after: boots.count + 1)
        manager.run(
            job, command: job.manifest.commands[0], type: .background, context: ["origin": .string("menu")])
        await unloaded(jobIdle)
        check(
            "background no-view receives scoped context",
            storage.localStorageValue(extension: "job", key: "context")
                == .string("background:menu") && !manager.isRunning && lastRuntime == nil)
        check(
            "no-view launch creates no menu snapshot",
            !metadata.metadata(extension: "job", command: "bar").menuBarEnabled)
        let concurrentStart = recorder.trees.count
        let concurrentRenders = MenuStateWait { events.foregroundRenders > concurrentStart + 3 }
        let foregroundIdle = idle(after: boots.count + 1)
        let backgroundReadyGate = MenuStateWait {
            _ = events.revision
            return hosts.last?.pendingReady != nil
        }
        holdsReady = true
        manager.run(first, command: first.manifest.commands[0], type: .background)
        holdsReady = false
        await backgroundReadyGate.wait("background command waits at readiness gate")
        await concurrentRenders.wait("foreground advances across background executions")
        check("foreground renders while background remains active", manager.isRunning)
        hosts.last?.pendingReady?.resume(returning: "")
        hosts.last?.pendingReady = nil
        await unloaded(foregroundIdle)
        check(
            "foreground keeps rendering during background commands",
            recorder.trees.count > foregroundRenders + 3
                && recorder.failures.isEmpty && !manager.isRunning)
        foreground.shutdown()

        let hangingIdle = idle(after: boots.count + 1)
        let fetchStarted = MenuStateWait {
            _ = events.revision
            return hosts.last?.name == "hanging" && hosts.last?.hasFetch == true
        }
        manager.run(hanging, command: hanging.manifest.commands[0])
        await fetchStarted.wait("hanging command starts its host request")
        let fetchCancelled = MenuStateWait {
            _ = events.revision
            return hosts.last?.didCancel == true
        }
        manager.disable("extension:hanging/bar")
        await fetchCancelled.wait("disable cancels the pending host request")
        await unloaded(hangingIdle)
        await lastRuntime?.drainHostCalls()
        check("disable cancels host requests", hosts.last?.didCancel == true && lastRuntime == nil)
        check(
            "disable removes snapshot and schedule",
            !metadata.metadata(extension: "hanging", command: "bar").menuBarEnabled)
        let timeoutIdle = idle(after: boots.count + 1)
        manager.run(hanging, command: hanging.manifest.commands[0])
        await unloaded(timeoutIdle)
        check(
            "loading timeout releases runtime",
            !manager.isRunning && lastRuntime == nil
                && failures.last?.contains("timed out") == true)
        manager.synchronize([])
        check(
            "uninstall prunes every menu and schedule",
            metadata.menuBarCommands().isEmpty && !manager.isRunning)
    }
}
