import AppKit

@MainActor
public final class MenuBarController {
    public static let shared = MenuBarController()

    private var statusItem: NSStatusItem?

    public init() {}

    public func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem?.button else { return }

        // Sleek Swish "S" aperture symbol
        if let image = NSImage(systemSymbolName: "s.circle.fill", accessibilityDescription: "Swish") ?? NSImage(systemSymbolName: "circle.circle", accessibilityDescription: "Swish") {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
            button.image = image.withSymbolConfiguration(config)
        } else {
            button.title = "✦"
        }
        button.toolTip = "Swish: Hold ⌘ while dragging files to convert"

        rebuildMenu()
    }

    public func rebuildMenu() {
        let menu = NSMenu()

        // Header
        let headerItem = NSMenuItem(title: "Swish", action: nil, keyEquivalent: "")
        headerItem.attributedTitle = NSAttributedString(
            string: "Swish Converter",
            attributes: [
                .font: NSFont.systemFont(ofSize: 13, weight: .bold),
                .foregroundColor: NSColor.labelColor
            ]
        )
        menu.addItem(headerItem)

        // Status
        let statusItem = NSMenuItem(title: "● Status: Active & Monitoring", action: nil, keyEquivalent: "")
        statusItem.attributedTitle = NSAttributedString(
            string: "● Status: Active",
            attributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .medium),
                .foregroundColor: NSColor.systemGreen
            ]
        )
        menu.addItem(statusItem)

        // Instructions
        let hintItem = NSMenuItem(title: "Drag files in Finder + Hold ⌘", action: nil, keyEquivalent: "")
        hintItem.isEnabled = false
        menu.addItem(hintItem)

        menu.addItem(NSMenuItem.separator())

        // Test Wheel Trigger
        let testItem = NSMenuItem(title: "Preview Format Wheel at Cursor", action: #selector(testWheelAction), keyEquivalent: "t")
        testItem.target = self
        menu.addItem(testItem)

        // Accessibility Check
        let isTrusted = AXIsProcessTrusted()
        let axItem = NSMenuItem(
            title: isTrusted ? "Accessibility: Granted ✓" : "Accessibility: Not Granted ⚠️",
            action: #selector(openAccessibilitySettings),
            keyEquivalent: ""
        )
        axItem.target = self
        menu.addItem(axItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit Swish", action: #selector(quitAction), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        self.statusItem?.menu = menu
    }

    @objc private func testWheelAction() {
        let mouseLoc = NSEvent.mouseLocation
        let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        let files = (try? FileManager.default.contentsOfDirectory(at: desktopURL, includingPropertiesForKeys: nil)) ?? []
        let testFile = files.first(where: { ["png", "jpg", "pdf", "mov", "mp3"].contains($0.pathExtension.lowercased()) }) ?? desktopURL

        DropPanelController.shared.show(at: mouseLoc, fileURLs: [testFile])

        // Auto dismiss after 4 seconds if just previewing
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            if DropPanelController.shared.isVisible && !DropPanelController.shared.state.isConverting {
                DropPanelController.shared.hide()
            }
        }
    }

    @objc private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    @objc private func quitAction() {
        NSApplication.shared.terminate(nil)
    }
}
