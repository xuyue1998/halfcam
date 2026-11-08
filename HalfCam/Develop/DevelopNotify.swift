import Foundation
import UserNotifications

enum DevelopNotify {
    static func schedule(rollId: UUID, filmName: String, at date: Date) {
        let center = UNUserNotificationCenter.current()
        let title = L("胶卷好了")
        let body = L("你的 \(filmName) 好了")
        center.requestAuthorization(options: [.alert, .sound, .badge]) { ok, _ in
            guard ok else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            content.userInfo = ["rollId": rollId.uuidString]
            let delay = max(1, date.timeIntervalSinceNow)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
            let request = UNNotificationRequest(
                identifier: "develop.\(rollId.uuidString)",
                content: content,
                trigger: trigger
            )
            center.removePendingNotificationRequests(withIdentifiers: [request.identifier])
            center.add(request)
        }
    }

    static func cancel(rollId: UUID) {
        let id = "develop.\(rollId.uuidString)"
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])
        center.removeDeliveredNotifications(withIdentifiers: [id])
    }
}

func waitClock(_ remaining: TimeInterval) -> String {
    let total = max(0, Int(ceil(remaining)))
    return String(format: "%02d:%02d", total / 60, total % 60)
}
