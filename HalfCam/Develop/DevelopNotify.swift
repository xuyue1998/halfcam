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

    @MainActor
    static func relocalizePending(rolls: () -> [Roll]) async {
        let center = UNUserNotificationCenter.current()
        let requests = await center.pendingNotificationRequests()
        for request in requests {
            guard let roll = rolls().first(where: {
                $0.state == .waiting && "develop.\($0.id.uuidString)" == request.identifier
            }),
                  let readyAt = roll.developReadyAt,
                  readyAt > Date(),
                  let content = request.content.mutableCopy() as? UNMutableNotificationContent else { continue }
            let filmName = FilmCatalog.recipe(id: roll.filmId).name
            content.title = L("胶卷好了")
            content.body = L("你的 \(filmName) 好了")
            // Replace only an existing pending request, without asking for permission
            // again or resetting its full original waiting interval.
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: max(1, readyAt.timeIntervalSinceNow),
                repeats: false
            )
            try? await center.add(UNNotificationRequest(
                identifier: request.identifier,
                content: content,
                trigger: trigger
            ))
        }
    }
}

func waitClock(_ remaining: TimeInterval) -> String {
    let total = max(0, Int(ceil(remaining)))
    return String(format: "%02d:%02d", total / 60, total % 60)
}
