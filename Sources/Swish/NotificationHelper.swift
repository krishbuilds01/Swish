import Foundation
import UserNotifications
import AppKit

public struct NotificationHelper: Sendable {
    public static let shared = NotificationHelper()

    private var isNotificationCenterAvailable: Bool {
        return Bundle.main.bundleIdentifier != nil
    }

    public init() {
        if isNotificationCenterAvailable {
            requestAuthorization()
        }
    }

    public func requestAuthorization() {
        guard isNotificationCenterAvailable else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("[Swish] Notification auth error: \(error.localizedDescription)")
            }
        }
    }

    public func notifyBatchSuccess(filesCount: Int, destination: URL, format: FormatOption) {
        NSSound(named: "Glass")?.play()

        guard isNotificationCenterAvailable else { return }

        let content = UNMutableNotificationContent()
        content.title = "Swish: \(format.displayName) Complete"
        content.subtitle = "\(filesCount) items archived → \(destination.lastPathComponent)"
        content.body = "Saved in \(destination.deletingLastPathComponent().lastPathComponent)"
        content.sound = UNNotificationSound.default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[Swish] Failed to deliver batch notification: \(error)")
            }
        }
    }

    public func notifySuccess(original: URL, converted: URL, format: FormatOption) {
        // System feedback sound always plays safely
        NSSound(named: "Glass")?.play()

        guard isNotificationCenterAvailable else { return }

        let content = UNMutableNotificationContent()
        content.title = "Swish: Conversion Complete"
        content.subtitle = "\(original.lastPathComponent) → \(converted.lastPathComponent)"
        content.body = "Saved beside original in \(converted.deletingLastPathComponent().lastPathComponent)"
        content.sound = UNNotificationSound.default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[Swish] Failed to deliver notification: \(error)")
            }
        }
    }

    public func notifyError(file: URL, error: Error) {
        NSSound.beep()

        guard isNotificationCenterAvailable else { return }

        let content = UNMutableNotificationContent()
        content.title = "Swish: Conversion Failed"
        content.subtitle = file.lastPathComponent
        content.body = error.localizedDescription
        content.sound = UNNotificationSound.defaultCritical

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { _ in }
    }
}

