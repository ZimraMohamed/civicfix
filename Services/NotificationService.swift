import UIKit
import UserNotifications
import OSLog


@MainActor @Observable
final class NotificationRouter {
    static let shared = NotificationRouter()

    enum Destination: Equatable { case home, adminReports }

    var destination: Destination?

   
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


@MainActor
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()
    private let log = Logger(subsystem: "com.lozaa.CivicFix", category: "notifications")

   
    func configure() {
        UNUserNotificationCenter.current().delegate = self
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func isAllowed(_ status: UNAuthorizationStatus) -> Bool {
        status == .authorized || status == .provisional || status == .ephemeral
    }

    
    @discardableResult
    func requestPermission() async -> Bool {
        configure()
        let center = UNUserNotificationCenter.current()
        if await authorizationStatus() == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
        }
        return Self.isAllowed(await authorizationStatus())
    }

    
    @discardableResult
    func post(title: String, body: String, type: String, reportID: String, key: String) async -> Bool {
        configure()

        
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

  

  
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        []
    }

    
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        let type = response.notification.request.content.userInfo["type"] as? String
        await MainActor.run { NotificationRouter.shared.handle(type: type) }
    }
}
