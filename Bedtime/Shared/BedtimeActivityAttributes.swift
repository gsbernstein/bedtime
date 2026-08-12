import ActivityKit
import Foundation

// ActivityKit hands this type to the widget extension across isolation
// boundaries, so it must stay off the target's default MainActor isolation.
nonisolated struct BedtimeActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// When the activity was started, used as the origin of the wind-down progress bar.
        let activityStart: Date
        let bedtime: Date
        let wakeTime: Date
        let targetSleepHours: Double
        let durationStyle: DurationDisplayStyle
        /// Set when the activity begins after bedtime has already passed. Before
        /// bedtime the card relies on `staleDate` to make the same switch on its
        /// own, which `staleDate` can only do for a date still ahead of it.
        let isSleeping: Bool
    }

    let title: String
}
