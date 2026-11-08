import ActivityKit
import Foundation

enum DevelopLive {
    static func sync(rolls: [Roll]) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let now = Date()
        let items = rolls
            .filter { $0.state == .waiting && !$0.isTutorial }
            .compactMap { roll -> DevelopActivityItem? in
                guard let ready = roll.developReadyAt else { return nil }
                let wait = AppConst.waitDuration(capacity: roll.capacity, seed: roll.rollSeed, tutorial: false)
                let started = ready.addingTimeInterval(-wait)
                return DevelopActivityItem(
                    filmName: FilmCatalog.recipe(id: roll.filmId).name,
                    startedAt: min(started, ready.addingTimeInterval(-60)),
                    readyAt: ready
                )
            }
            .sorted { $0.readyAt < $1.readyAt }

        let activities = Activity<DevelopActivityAttributes>.activities
        guard !items.isEmpty else {
            for activity in activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            return
        }

        let state = DevelopActivityAttributes.ContentState(items: items)
        let stale = state.soonestLive?.readyAt ?? now
        let content = ActivityContent(state: state, staleDate: stale)

        if let activity = activities.first {
            await activity.update(content)
            for extra in activities.dropFirst() {
                await extra.end(nil, dismissalPolicy: .immediate)
            }
            if state.allReady {
                await activity.end(content, dismissalPolicy: .after(now.addingTimeInterval(15 * 60)))
            }
            return
        }

        guard let activity = try? Activity.request(
            attributes: DevelopActivityAttributes(),
            content: content,
            pushType: nil
        ) else { return }
        if state.allReady {
            await activity.end(content, dismissalPolicy: .after(now.addingTimeInterval(15 * 60)))
        }
    }
}
