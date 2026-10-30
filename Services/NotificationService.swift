import UIKit
import UserNotifications
import OSLog

/// Where a tapped notification should take the user. `MainTabView` consumes it.
@MainActor @Observable
final class NotificationRouter {
    static let shared = NotificationRouter()

    enum Destination: Equatable { case home, adminReports }

    var destination: Destination?

    /// A banner drawn by the app itself at the top of the screen (see MainTabView).
    struct Banner: Identifiable, Equatable {
        let id = UUID()
        let title: String
        let body: String
        let type: String
    }
    var banner: Banner?

    func show(title: String, body: String, type: String) {
        banner = Banner(title: title, body: body, type: type)
    }

    func handle(type: String?) {
        switch type {
        case "new_report": destination = .adminReports
        case "status_changed": destination = .home
        default: break
        }
    }
}

/// Local notifications only: no APNs, no server, no Firebase Messaging.
/// `ReportWatcher` decides *when* to notify; this type decides *how*.
@MainActor
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()
    private let log = Logger(subsystem: "com.lozaa.CivicFix", category: "notifications")

    /// Call once at launch so banners and taps work even on a cold start.
    func configure() {
        UNUserNotificationCenter.current().delegate = self
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func isAllowed(_ status: UNAuthorizationStatus) -> Bool {
        status == .authorized || status == .provisional || status == .ephemeral
    }

    /// Shows the system prompt the first time; afterwards just reports the current state.
    @discardableResult
    func requestPermission() async -> Bool {
        configure()
        let center = UNUserNotificationCenter.current()
        if await authorizationStatus() == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
        }
        return Self.isAllowed(await authorizationStatus())
    }

    /// Delivers a notification immediately. Returns false if the user hasn't allowed notifications.
    @discardableResult
    func post(title: String, body: String, type: String, reportID: String, key: String) async -> Bool {
        configure()

        // While the app is open we draw our own banner, so you always see something.
        if UIApplication.shared.applicationState == .active {
            NotificationRouter.shared.show(title: title, body: body, type: type)
        }

        let status = await authorizationStatus()
        guard Self.isAllowed(status) else {
            log.error("Not posting “\(title)”: notification permission is \(status.rawValue) (2 = denied)")
            return false
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["type": type, "reportId": reportID]

        // Same identifier = same notification, so a repeat replaces instead of stacking.
        let request = UNNotificationRequest(identifier: "\(type)-\(reportID)-\(key)",
                                            content: content, trigger: nil)
        do {
            try await UNUserNotificationCenter.current().add(request)
            log.info("Posted notification: \(title)")
            return true
        } catch {
            log.error("Posting failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Show the banner even while the app is open.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        []   // the app shows its own banner while it is open
    }

    /// The user tapped a notification.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        let type = response.notification.request.content.userInfo["type"] as? String
        await MainActor.run { NotificationRouter.shared.handle(type: type) }
    }
}
