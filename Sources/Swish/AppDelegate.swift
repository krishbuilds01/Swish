import AppKit

public final class AppDelegate: NSObject, NSApplicationDelegate {
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Runs silently in the background: no dock icon, no main window
        NSApplication.shared.setActivationPolicy(.accessory)

        // Set Swish logo as the official application icon
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns") ?? Bundle.main.url(forResource: "Swish", withExtension: "png"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApplication.shared.applicationIconImage = icon
        } else if let icon = NSImage(contentsOfFile: "/Users/krishnapandey/Drag/Swish.png") {
            NSApplication.shared.applicationIconImage = icon
        }

        // Request notification authorization
        NotificationHelper.shared.requestAuthorization()

        // Setup menu bar status item
        MenuBarController.shared.setup()

        // Start global drag and keyboard monitoring
        DragMonitor.shared.start()

        print("[Swish] Started successfully. Background service active.")
    }

    public func applicationWillTerminate(_ notification: Notification) {
        DragMonitor.shared.stop()
    }
}
