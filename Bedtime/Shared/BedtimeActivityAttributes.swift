import ActivityKit
import Foundation

// ActivityKit hands this type to the widget extension across isolation
// boundaries, so it must stay off the target's default MainActor isolation.
nonisolated struct BedtimeActivityAttributes: ActivityAttributes {
    /// The system caps an app at this many concurrent Live Activities, counting
    /// both active and merely `.pending` (scheduled but not yet started) ones.
    /// Shared with the widget extension so its staleness messaging can key off
    /// the same ceiling `LiveActivityManager` schedules against.
    static let maxConcurrentActivities = 5

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
        /// How many nights ahead of the last HealthKit-backed recalculation this
        /// one is. 0 is tonight's real recommendation; a locally pre-scheduled
        /// queue (see `LiveActivityManager`) just repeats those same clock times
        /// for the following nights, so a higher count means a longer stretch
        /// without a fresh recommendation, and the card nudges more insistently
        /// to reopen the app.
        var nightsSinceLastSync: Int = 0
    }
}
