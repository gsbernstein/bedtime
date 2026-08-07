import ActivityKit
import Foundation

struct BedtimeActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let bedtime: Date
        let wakeTime: Date
        let targetSleepHours: Double
    }

    let title: String
}
