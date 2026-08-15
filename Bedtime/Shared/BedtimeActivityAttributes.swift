import ActivityKit
import Foundation

/// A deep link to the third-party app that actually wrote recent sleep data to
/// HealthKit (e.g. Oura), so the card can point there directly once the person
/// wakes up instead of a bare "open Bedger" that doesn't have the data either.
struct BedtimeSourceAppLink: Codable, Hashable {
    let name: String
    let url: URL
}

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
        /// The most recent app HealthKit sleep data came from, if that app
        /// offers its own deep link. Set once, before bedtime, from whatever
        /// wrote the last several nights of data, since the source rarely
        /// changes night to night.
        var sourceAppLink: BedtimeSourceAppLink? = nil
        /// Flipped by `LiveActivityManager.markAwakeIfNeeded()`, which the app
        /// calls whenever it gets a chance to run after `wakeTime` — from
        /// HealthKit background delivery when new sleep data lands, or a
        /// scheduled background refresh task as a backup. `staleDate` only
        /// gets one automatic local transition (already spent on wind-down →
        /// sleeping), so reaching this phase needs the app to actually run and
        /// push a fresh update rather than a second local staleness flip.
        var isAwake: Bool = false
    }
}
