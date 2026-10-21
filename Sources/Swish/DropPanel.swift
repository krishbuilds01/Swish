import AppKit
import SwiftUI

public final class WheelDropView: NSView {
    public let state: WheelState
    private var hostingView: NSHostingView<LiquidGlassWheelView>!

    // Radial Petal Wheel Geometry
    private let innerRadius: CGFloat = 56
    private let outerRadius: CGFloat = 165

    public init(state: WheelState, frame: NSRect) {
        self.state = state
        super.init(frame: frame)

        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.clear.cgColor

        let rootView = LiquidGlassWheelView(state: state)
        self.hostingView = NSHostingView(rootView: rootView)
        self.hostingView.frame = self.bounds
        self.hostingView.autoresizingMask = [.width, .height]
        self.addSubview(hostingView)

        // Register for file drags
        self.registerForDraggedTypes([.fileURL, .URL])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - NSDraggingDestination

    public override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        updateFilesFromPasteboard(sender.draggingPasteboard)
        return updateHoverState(at: sender.draggingLocation)
    }

    public override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        return updateHoverState(at: sender.draggingLocation)
    }

    public override func draggingExited(_ sender: (any NSDraggingInfo)?) {
        DispatchQueue.main.async { [weak self] in
            self?.state.hoveredIndex = nil
        }
    }

    public override func prepareForDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        if state.isUnsupportedFile { return false }
        return state.hoveredIndex != nil
    }

    public override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        if state.isUnsupportedFile { return false }
        guard let format = state.selectedFormat else {
            return false
        }

        // Get dropped files
        var filesToConvert = state.fileURLs
        if let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !urls.isEmpty {
            filesToConvert = urls
        }

        guard !filesToConvert.isEmpty else {
            return false
        }

        print("[Swish] Drop received on petal: \(format.displayName). Files: \(filesToConvert.map { $0.lastPathComponent })")

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.state.activeConvertingFormat = format
            withAnimation(.spring(response: 0.30, dampingFraction: 0.74)) {
                self.state.phase = .converting
            }

            Task {
                do {
                    let results = try await ConversionEngine.shared.convert(files: filesToConvert, to: format)
                    await MainActor.run {
                        // Green ripple shockwave expansion
                        self.state.rippleScale = 0.40
                        self.state.rippleOpacity = 0.95
                        self.state.secondRippleScale = 0.25
                        self.state.secondRippleOpacity = 0.75

                        withAnimation(.easeOut(duration: 0.65)) {
                            self.state.phase = .success
                            self.state.rippleScale = 1.35
                            self.state.rippleOpacity = 0.0
                            self.state.secondRippleScale = 1.15
                            self.state.secondRippleOpacity = 0.0
                        }

                        // Success tactile haptic!
                        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)

                        if results.count == 1 && filesToConvert.count > 1 {
                            NotificationHelper.shared.notifyBatchSuccess(filesCount: filesToConvert.count, destination: results[0], format: format)
                        } else {
                            for (idx, original) in filesToConvert.enumerated() {
                                if idx < results.count {
                                    NotificationHelper.shared.notifySuccess(original: original, converted: results[idx], format: format)
                                }
                            }
                        }
                    }

                    // 0.90s delay to enjoy the green tick animation
                    try await Task.sleep(nanoseconds: 900_000_000)
                    await MainActor.run {
                        DropPanelController.shared.hide()
                    }
                } catch {
                    await MainActor.run {
                        self.state.phase = .idle
                        if let first = filesToConvert.first {
                            NotificationHelper.shared.notifyError(file: first, error: error)
                        }
                        DropPanelController.shared.hide()
                    }
                }
            }
        }

        return true
    }

    // MARK: - Internal Coordinate Calculation

    private func updateFilesFromPasteboard(_ pb: NSPasteboard) {
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !urls.isEmpty {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if self.state.fileURLs != urls {
                    self.state.fileURLs = urls
                    let formats = ConversionEngine.shared.compatibleFormats(for: urls[0])
                    if formats.isEmpty {
                        self.state.isUnsupportedFile = true
                        self.state.unsupportedMessage = "File not supported for conversion"
                        self.state.availableFormats = []
                    } else {
                        self.state.isUnsupportedFile = false
                        self.state.availableFormats = formats
                    }
                }
            }
        }
    }

    private func updateHoverState(at loc: NSPoint) -> NSDragOperation {
        if state.isUnsupportedFile {
            DispatchQueue.main.async { [weak self] in
                self?.state.hoveredIndex = nil
            }
            return []
        }

        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        let dx = loc.x - center.x
        let dy = loc.y - center.y
        let distance = hypot(dx, dy)

        // In AppKit, y is up (+y is 12 o'clock).
        // atan2(dx, dy) measures clockwise angle from 12 o'clock!
        var clockAngle = Double(atan2(dx, dy))
        if clockAngle < 0 {
            clockAngle += 2.0 * .pi
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.state.cursorDistance = distance
            self.state.cursorAngle = clockAngle

            let formatsCount = self.state.availableFormats.count
            guard formatsCount > 0 else {
                self.state.hoveredIndex = nil
                return
            }

            // Check if cursor is within the radial petal band
            if distance >= self.innerRadius && distance <= (self.outerRadius + 35) {
                let sliceAngle = (2.0 * .pi) / Double(formatsCount)
                let index = Int((clockAngle + sliceAngle / 2.0) / sliceAngle) % formatsCount

                if self.state.hoveredIndex != index {
                    // Tactile haptic tick on petal snap
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                    self.state.hoveredIndex = index
                }
            } else {
                // In center pill or outside outer edge
                self.state.hoveredIndex = nil
            }
        }

        return distance >= innerRadius ? .copy : []
    }
}

// MARK: - Transparent Floating NSPanel

public final class LiquidGlassPanel: NSPanel {
    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.level = .floating
        self.ignoresMouseEvents = false
        self.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle, .fullScreenAuxiliary]
        self.isMovableByWindowBackground = false
    }

    public override var canBecomeKey: Bool {
        return false // Do NOT steal key focus from Finder's drag loop!
    }

    public override var canBecomeMain: Bool {
        return false
    }
}

// MARK: - Drop Panel Controller

@MainActor
public final class DropPanelController {
    public static let shared = DropPanelController()

    public let state = WheelState()
    private var panel: LiquidGlassPanel?
    private var dropView: WheelDropView?
    private let panelSize: CGFloat = 440

    public init() {
        setupPanel()
    }

    private func setupPanel() {
        let rect = NSRect(x: 200, y: 200, width: panelSize, height: panelSize)
        let panel = LiquidGlassPanel(contentRect: rect)
        let view = WheelDropView(state: state, frame: NSRect(x: 0, y: 0, width: panelSize, height: panelSize))
        panel.contentView = view

        self.panel = panel
        self.dropView = view
    }

    public func show(at screenLocation: NSPoint, fileURLs: [URL]) {
        guard let panel = panel else { return }

        state.reset()
        state.fileURLs = fileURLs
        if let first = fileURLs.first {
            let formats = ConversionEngine.shared.compatibleFormats(for: first)
            if formats.isEmpty {
                state.isUnsupportedFile = true
                state.unsupportedMessage = "File not supported for conversion"
                state.availableFormats = []
            } else {
                state.isUnsupportedFile = false
                state.availableFormats = formats
            }
        } else {
            state.isUnsupportedFile = true
            state.unsupportedMessage = "File not supported for conversion"
            state.availableFormats = []
        }

        // Center on cursor with screen boundary clamping
        let screens = NSScreen.screens
        let targetScreen = screens.first(where: { NSPointInRect(screenLocation, $0.frame) }) ?? NSScreen.main ?? screens.first

        var x = screenLocation.x - panelSize / 2.0
        var y = screenLocation.y - panelSize / 2.0

        if let screen = targetScreen {
            let vis = screen.visibleFrame
            x = max(vis.minX + 10, min(x, vis.maxX - panelSize - 10))
            y = max(vis.minY + 10, min(y, vis.maxY - panelSize - 10))
        }

        let origin = NSPoint(x: x, y: y)
        panel.setFrameOrigin(origin)
        state.isPresented = true
        panel.orderFrontRegardless()
        print("[Swish] Presentation at origin: \(origin). Supported: \(!state.isUnsupportedFile). Formats: \(state.availableFormats.count)")
    }

    public func hide() {
        guard let panel = panel, panel.isVisible else { return }
        state.isPresented = false
        // Allow fade out animation to finish before ordering out
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { [weak self] in
            guard let self = self else { return }
            if !self.state.isPresented {
                self.panel?.orderOut(nil)
                self.state.reset()
            }
        }
    }

    public var isVisible: Bool {
        return panel?.isVisible ?? false
    }
}
