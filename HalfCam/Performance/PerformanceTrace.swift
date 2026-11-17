import OSLog

/// Instruments → Points of Interest. Names only; no photo data, file paths or IDs.
enum PerformanceTrace {
    private static let poster = OSSignposter(
        subsystem: "com.xuyue.HalfCam",
        category: "Performance"
    )

    static func begin(_ name: StaticString) -> OSSignpostIntervalState {
        poster.beginInterval(name, id: poster.makeSignpostID())
    }

    static func end(_ name: StaticString, _ state: OSSignpostIntervalState) {
        poster.endInterval(name, state)
    }

    static func measure<Value>(_ name: StaticString, _ work: () throws -> Value) rethrows -> Value {
        let state = begin(name)
        defer { end(name, state) }
        return try work()
    }
}
