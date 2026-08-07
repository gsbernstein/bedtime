import ActivityKit
import Foundation

// ActivityKit hands this type to the widget extension across isolation
// boundaries, so it must stay off the target's default MainActor isolation.
nonisolated struct BedtimeActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let activityStart: Date
        let bedtime: Date
        let wakeTime: Date
        let targetSleepHours: Double
    }

    let title: String
}
