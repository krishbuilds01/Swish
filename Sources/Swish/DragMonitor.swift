import AppKit
import ApplicationServices
import Foundation

@MainActor
public final class DragMonitor {
    public static let shared = DragMonitor()

    private var eventTap: CFMachPort?
    private var globalMouseMonitor: Any?
    private var isDraggingActive: Bool = false
    private var wheelAnchorPoint: NSPoint? = nil

    public init() {}

    public func start() {
        setupGlobalNSEventMonitor()
        setupCGEventTap()
        print("[Swish] DragMonitor running. Listening for Command (⌘) + Drag...")
    }

    public func stop() {
        if let monitor = globalMouseMonitor {
            NSEvent.removeMonitor(monitor)
            globalMouseMonitor = nil
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            eventTap = nil
        }
    }

    // MARK: - NSEvent Monitor

    private func setupGlobalNSEventMonitor() {
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDragged, .leftMouseDown, .leftMouseUp, .flagsChanged]
        ) { event in
            DispatchQueue.main.async {
                DragMonitor.shared.handleNSEvent(event)
            }
        }
    }

    public func handleNSEvent(_ event: NSEvent) {
        let isCmd = event.modifierFlags.contains(.command)
        let mouseLoc = NSEvent.mouseLocation

        switch event.type {
        case .leftMouseDown:
            isDraggingActive = true
            wheelAnchorPoint = nil

        case .leftMouseDragged:
            isDraggingActive = true
            if isCmd {
                triggerWheelIfNeeded(at: mouseLoc)
            } else {
                dismissWheelIfActive()
            }

        case .flagsChanged:
            let leftButtonDown = NSEvent.pressedMouseButtons & 1 != 0
            if isCmd && leftButtonDown {
                triggerWheelIfNeeded(at: mouseLoc)
            } else if !isCmd {
                dismissWheelIfActive()
            }

        case .leftMouseUp:
            isDraggingActive = false
            wheelAnchorPoint = nil
            // If panel is visible, allow performDragOperation to process before hiding
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                if !DropPanelController.shared.state.isConverting {
                    DropPanelController.shared.hide()
                }
            }

        default:
            break
        }
    }

    // MARK: - CGEventTap for low-latency hardware level monitoring

    private func setupCGEventTap() {
        let mask = (1 << CGEventType.leftMouseDragged.rawValue) |
                   (1 << CGEventType.leftMouseDown.rawValue) |
                   (1 << CGEventType.leftMouseUp.rawValue) |
                   (1 << CGEventType.flagsChanged.rawValue)

        let tapCallback: CGEventTapCallBack = { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
            let isCmd = event.flags.contains(.maskCommand)
            let loc = event.location

            if type == .flagsChanged || type == .leftMouseDragged || type == .leftMouseUp {
                DispatchQueue.main.async {
                    DragMonitor.shared.handleCGEvent(type: type, isCmd: isCmd, loc: loc)
                }
            }
            return Unmanaged.passRetained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: tapCallback,
            userInfo: nil
        ) else {
            print("[LiquidDrop] CGEventTap could not be initialized (Accessibility permission might be required)")
            return
        }

        self.eventTap = tap
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    public func handleCGEvent(type: CGEventType, isCmd: Bool, loc: CGPoint) {
        guard let screen = NSScreen.main else { return }
        let appKitLoc = NSPoint(x: loc.x, y: screen.frame.height - loc.y)

        switch type {
        case .leftMouseDragged:
            if isCmd {
                triggerWheelIfNeeded(at: appKitLoc)
            } else {
                dismissWheelIfActive()
            }
        case .flagsChanged:
            let leftButtonDown = NSEvent.pressedMouseButtons & 1 != 0
            if isCmd && leftButtonDown {
                triggerWheelIfNeeded(at: appKitLoc)
            } else if !isCmd {
                dismissWheelIfActive()
            }
        case .leftMouseUp:
            wheelAnchorPoint = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                if !DropPanelController.shared.state.isConverting {
                    DropPanelController.shared.hide()
                }
            }
        default:
            break
        }
    }

    // MARK: - Trigger / Dismiss Logic

    private func triggerWheelIfNeeded(at mouseLoc: NSPoint) {
        // If already visible and converting, don't interfere
        if DropPanelController.shared.state.isConverting { return }

        // If wheel is already presented, keep it anchored! (Do not move it with cursor)
        if DropPanelController.shared.isVisible { return }

        // Check active drag pasteboard for files
        let dragPB = NSPasteboard(name: .drag)
        var fileURLs: [URL] = []
        if let urls = dragPB.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !urls.isEmpty {
            fileURLs = urls
        }

        print("[Swish] Wheel triggered at \(mouseLoc). Found \(fileURLs.count) drag files.")
        wheelAnchorPoint = mouseLoc
        DropPanelController.shared.show(at: mouseLoc, fileURLs: fileURLs)
    }

    private func dismissWheelIfActive() {
        if DropPanelController.shared.isVisible && !DropPanelController.shared.state.isConverting {
            print("[Swish] Wheel dismissed.")
            DropPanelController.shared.hide()
            wheelAnchorPoint = nil
        }
    }
}
