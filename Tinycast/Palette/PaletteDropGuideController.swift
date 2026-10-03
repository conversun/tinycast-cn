import AppKit
import SwiftUI

/// Driven by the window controller: only a live drag has a home placement to point at.
@MainActor
final class PaletteDropGuideController {
    private var panel: NSPanel?
    private var host: NSHostingView<PaletteDropGuideView>?
    private var screenFrame: CGRect = .zero
    private var home: CGPoint = .zero
    private var dragged: CGPoint = .zero
    private var width: CGFloat = 0
    private var verticalFlash = false
    private var horizontalFlash = false
    private var flashTask: Task<Void, Never>?
    private var hideTask: Task<Void, Never>?

    enum Axis { case vertical, horizontal, both }

    /// Reveal the guides, with `home` the default placement's top-left in screen coordinates.
    func show(home: CGPoint, width: CGFloat, screenFrame: CGRect, dragged: CGPoint) {
        self.home = home
        self.width = width
        self.screenFrame = screenFrame
        self.dragged = dragged
        hideTask?.cancel()
        hideTask = nil
        let panel = ensurePanel()
        panel.setFrame(screenFrame, display: false)
        render()
        if !panel.isVisible {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Theme.Duration.dropGuide
            panel.animator().alphaValue = 1
        }
    }

    /// Re-point mid-drag. `windowDidMove` fires continuously, so an unchanged move costs nothing.
    func move(home: CGPoint, screenFrame: CGRect, dragged: CGPoint) {
        guard self.home != home || self.screenFrame != screenFrame || self.dragged != dragged else {
            return
        }
        let crossedScreens = self.screenFrame != screenFrame
        self.home = home
        self.screenFrame = screenFrame
        self.dragged = dragged
        if crossedScreens { panel?.setFrame(screenFrame, display: false) }
        render()
    }

    func flash(_ axis: Axis) {
        flashTask?.cancel()
        verticalFlash = axis != .horizontal
        horizontalFlash = axis != .vertical
        render()
        flashTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Theme.Duration.dropGuide * 2))
            guard !Task.isCancelled, let self else { return }
            verticalFlash = false
            horizontalFlash = false
            render()
            flashTask = nil
        }
    }

    func hide() {
        flashTask?.cancel()
        flashTask = nil
        verticalFlash = false
        horizontalFlash = false
        guard let panel, panel.isVisible else { return }
        hideTask?.cancel()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Theme.Duration.dropGuide
            panel.animator().alphaValue = 0
        }
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Theme.Duration.dropGuide))
            guard !Task.isCancelled, let self else { return }
            panel.orderOut(nil)
            hideTask = nil
        }
    }

    // MARK: - Private

    private func ensurePanel() -> NSPanel {
        if let panel { return panel }
        let host = NSHostingView(rootView: guides)
        // The controller owns the frame; without this the hosting view would size the window.
        host.sizingOptions = []
        let panel = PaletteDropGuidePanel()
        panel.contentView = host
        self.host = host
        self.panel = panel
        return panel
    }

    private func render() {
        host?.rootView = guides
    }

    /// AppKit's y grows up from the screen's origin, SwiftUI's grows down from the window's top.
    private var guides: PaletteDropGuideView {
        PaletteDropGuideView(
            topLeft: CGPoint(x: home.x - screenFrame.minX, y: screenFrame.maxY - home.y),
            width: width, horizontalDistance: abs(dragged.x - home.x),
            verticalDistance: abs(dragged.y - home.y),
            verticalFlash: verticalFlash, horizontalFlash: horizontalFlash)
    }
}

/// Borderless, click-through, never key: the guides are a readout, not a surface.
private final class PaletteDropGuidePanel: NSPanel {
    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .paletteDropGuide
        ignoresMouseEvents = true
        hidesOnDeactivate = false
        animationBehavior = .none
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
