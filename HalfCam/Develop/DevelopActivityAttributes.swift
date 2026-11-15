import ActivityKit
import Foundation

struct DevelopActivityItem: Codable, Hashable {
    var filmName: String
    var startedAt: Date
    var readyAt: Date

    var isReady: Bool { readyAt <= Date() }
}

struct DevelopActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var items: [DevelopActivityItem]
        // Optional so activities created before language support still decode.
        var languageCode: String? = nil

        var count: Int { items.count }
        var soonestLive: DevelopActivityItem? {
            items.first { $0.readyAt > Date() }
        }
        var allReady: Bool {
            !items.isEmpty && items.allSatisfy { $0.readyAt <= Date() }
        }
    }
}
