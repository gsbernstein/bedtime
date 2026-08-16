import ActivityKit
import BackgroundTasks
import Combine
import Foundation

@MainActor
final class LiveActivityManager: ObservableObject {
    /// Shared so an app intent launched in the background drives the same
    /// activity the UI is showing.
    static let shared = LiveActivityManager()

    @Published private(set) var activeActivityID: String?
    @Published private(set) var isWorking = false
    @Published private(set) var lastErrorMessage: String?

    var isActivityActive: Bool {
        activeActivityID != nil
    }

    /// The widget extension deploys to iOS 18 because its countdown relies on
    /// `SystemFormatStyle`, so on older systems there is no activity to request.
    var isSupported: Bool {
        if #available(iOS 18, *) {
            return true
        }
        return false
    }

    var areActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    init() {
        activeActivityID = Activity<BedtimeActivityAttributes>.activities.first?.id
    }

    /// Registers the background refresh task handler. Apple requires this to
    /// happen synchronously before the app finishes launching, so call it from
    /// `BedtimeApp.init()` rather than anywhere the shared instance is used —
    /// registration doesn't depend on there being an activity yet.
    static func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Constants.wakeRefreshTaskIdentifier,
            using: nil
        ) { task in
            Task { @MainActor in
                await LiveActivityManager.shared.markAwakeIfNeeded()
                task.setTaskCompleted(success: true)
            }
        }
    }

    func newStartTime(bedtime: Date, now: Date) -> Date {
        // A fixed elapsed-time subtraction rather than calendar arithmetic: the
        // lead time should always be an actual 30 minutes, not a wall-clock gap
        // that a DST transition happening to land near bedtime could stretch or shrink.
        let defaultTime = bedtime.addingTimeInterval(-Constants.liveActivityLeadTime)
        return min(now, defaultTime)
    }

    func startOrUpdate(
        with recommendation: BedtimeRecommendation,
        durationStyle: DurationDisplayStyle,
        sourceAppLink: BedtimeSourceAppLink? = nil
    ) async {
        guard isSupported else {
            lastErrorMessage = "Live Activities need iOS 18 or later."
            return
        }

        guard areActivitiesEnabled else {
            lastErrorMessage = "Live Activities are disabled for Bedger in system settings."
            return
        }

        isWorking = true
        lastErrorMessage = nil
        defer { isWorking = false }

        let now = Date()
        let schedule = getTimes(for: recommendation, now: now)
        let isSleeping = now >= schedule.bedtime
        let startTime = Self.activity(withID: activeActivityID)?.content.state.activityStart ?? newStartTime(bedtime: schedule.bedtime, now: now)
        let state = BedtimeActivityAttributes.ContentState(
            activityStart: startTime,
            bedtime: schedule.bedtime,
            wakeTime: schedule.wakeTime,
            targetSleepHours: recommendation.targetSleepDuration,
            durationStyle: durationStyle,
            isSleeping: isSleeping,
            sourceAppLink: sourceAppLink
        )
        // Going stale at bedtime flips the card to the sleeping countdown while
        // the app is suspended. Starting mid-night, bedtime has already gone by,
        // so the state above carries the phase and this stays ahead of now.
        let content = ActivityContent(
            state: state,
            staleDate: isSleeping ? schedule.wakeTime : schedule.bedtime
        )

        if let activity = Self.activity(withID: activeActivityID) {
            // `.stale` still counts as on screen: the sleeping phase is
            // reached by deliberately letting the wind-down content go stale
            // at bedtime, so this is the common case for most of the night,
            // not an edge case.
            if activity.activityState == .active || activity.activityState == .stale {
                await activity.update(content)
                return
            }
            // Anything else is scheduled but not on screen yet. Clear it so this
            // request shows up now rather than silently editing tonight's plan.
            await activity.end(nil, dismissalPolicy: .immediate)
            activeActivityID = nil
        }

        do {
            let activity = try Activity.request(
                attributes: BedtimeActivityAttributes(),
                content: content,
                pushType: nil
            )
            activeActivityID = activity.id
            scheduleWakeRefreshTask(at: schedule.wakeTime)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    /// Flips the activity to its post-wake phase once `wakeTime` has passed,
    /// without recomputing the recommendation: this runs from a HealthKit
    /// background delivery callback or the wake-refresh background task,
    /// neither of which has cheap access to the full recommendation inputs
    /// (HealthKit averages, SwiftData preferences) — nor needs them, since
    /// every other field on the activity is left exactly as it was.
    func markAwakeIfNeeded(now: Date = Date()) async {
        guard
            let activity = Self.activity(withID: activeActivityID),
            activity.activityState == .active || activity.activityState == .stale
        else { return }

        let state = activity.content.state
        guard state.isSleeping, !state.isAwake, now >= state.wakeTime else { return }

        var updatedState = state
        updatedState.isAwake = true
        // Nothing left to wait for, so there's no future date to go stale at.
        await activity.update(ActivityContent(state: updatedState, staleDate: nil))
    }

    /// Best-effort backup for `markAwakeIfNeeded`, in case HealthKit doesn't
    /// deliver new sleep data by wake time (no watch/ring worn, slow sync,
    /// etc). Not time-precise — iOS decides when to actually run it.
    ///
    /// `BGProcessingTaskRequest` rather than `BGAppRefreshTaskRequest`: the
    /// latter needs the `fetch` UIBackgroundMode, but only `processing` is
    /// declared. The work itself is trivial, so the conditions that usually
    /// make processing tasks wait for a convenient moment are turned off.
    private func scheduleWakeRefreshTask(at wakeTime: Date) {
        let request = BGProcessingTaskRequest(identifier: Constants.wakeRefreshTaskIdentifier)
        request.earliestBeginDate = wakeTime
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        try? BGTaskScheduler.shared.submit(request)
    }

    /// Starts the activity once the wind-down window opens, refreshes it if the
    /// schedule moved, and clears out last night's once the wake time has passed.
    /// Safe to call on every foreground.
    func syncWithSchedule(
        recommendation: BedtimeRecommendation,
        durationStyle: DurationDisplayStyle,
        leadTime: TimeInterval = Constants.liveActivityLeadTime,
        now: Date = Date(),
        sourceAppLink: BedtimeSourceAppLink? = nil
    ) async {
        await endFinishedActivities(now: now)

        guard isSupported, areActivitiesEnabled else { return }

        let schedule = getTimes(for: recommendation, now: now)
        // Same reasoning as `newStartTime`: an actual elapsed-time lead, not a
        // wall-clock gap that could stretch or shrink across a DST transition.
        let windowOpens = schedule.bedtime.addingTimeInterval(-leadTime)

        // Once bedtime passes, the next match is tomorrow's, so this only opens
        // the window ahead of tonight's bedtime. An activity already running
        // carries the rest of the night on its own.
        guard now < windowOpens else {
            await startOrUpdate(with: recommendation, durationStyle: durationStyle, sourceAppLink: sourceAppLink)
            return
        }

        if #available(iOS 26, *) {
            await scheduleUpcomingNights(
                recommendation: recommendation,
                durationStyle: durationStyle,
                schedule: schedule,
                startingAt: windowOpens,
                sourceAppLink: sourceAppLink
            )
        }
    }

    /// Hands the starts over to the system so the wind-down card appears on its
    /// own, and pre-schedules the following nights too, since starting one from
    /// a background wake throws `ActivityAuthorizationError.visibility` — every
    /// other route needs either a push server or a user-triggered intent.
    ///
    /// The following nights just repeat tonight's bedtime/wake clock times:
    /// without another HealthKit-backed recalculation there's no better guess,
    /// but a stale countdown (flagged as such in the widget) beats no countdown
    /// at all until the person reopens the app. Only `.pending` activities are
    /// ever touched here — one already `.active` and on screen is left alone.
    @available(iOS 26, *)
    private func scheduleUpcomingNights(
        recommendation: BedtimeRecommendation,
        durationStyle: DurationDisplayStyle,
        schedule: (bedtime: Date, wakeTime: Date),
        startingAt start: Date,
        sourceAppLink: BedtimeSourceAppLink? = nil
    ) async {
        let calendar = Calendar.autoupdatingCurrent
        let activeCount = Activity<BedtimeActivityAttributes>.activities
            .filter { $0.activityState == .active }
            .count
        let nightCount = max(0, BedtimeActivityAttributes.maxConcurrentActivities - activeCount)
        guard nightCount > 0 else { return }

        let projectedNights: [(start: Date, bedtime: Date, wakeTime: Date)] = (0..<nightCount).compactMap { offset in
            guard
                let nightStart = calendar.date(byAdding: .day, value: offset, to: start),
                let nightBedtime = calendar.date(byAdding: .day, value: offset, to: schedule.bedtime),
                let nightWakeTime = calendar.date(byAdding: .day, value: offset, to: schedule.wakeTime)
            else { return nil }
            return (nightStart, nightBedtime, nightWakeTime)
        }

        // Already queued up with tonight's exact bedtimes, so leave it alone
        // rather than tearing down and rebuilding an unchanged queue.
        let pendingBedtimes = Set(
            Activity<BedtimeActivityAttributes>.activities
                .filter { $0.activityState == .pending }
                .map(\.content.state.bedtime)
        )
        let desiredBedtimes = Set(projectedNights.map(\.bedtime))
        guard pendingBedtimes != desiredBedtimes else { return }

        // Re-derived rather than reused from `pendingBedtimes` above: once an
        // `Activity` has been read from within this actor-isolated region, the
        // compiler can no longer prove it's safe to send into `await end(...)`
        // below. A fresh, standalone expression avoids that.
        for activity in Activity<BedtimeActivityAttributes>.activities where activity.activityState == .pending {
            await activity.end(nil, dismissalPolicy: .immediate)
        }

        for (index, night) in projectedNights.enumerated() {
            let state = BedtimeActivityAttributes.ContentState(
                activityStart: night.start,
                bedtime: night.bedtime,
                wakeTime: night.wakeTime,
                targetSleepHours: recommendation.targetSleepDuration,
                durationStyle: durationStyle,
                // Scheduled activities always begin ahead of bedtime.
                isSleeping: false,
                nightsSinceLastSync: index,
                sourceAppLink: sourceAppLink
            )

            do {
                let activity = try Activity.request(
                    attributes: BedtimeActivityAttributes(),
                    content: ActivityContent(state: state, staleDate: night.bedtime),
                    pushType: nil,
                    style: .standard,
                    alertConfiguration: AlertConfiguration(
                        title: "Time to wind down",
                        body: "Bedtime is coming up.",
                        sound: .default
                    ),
                    start: night.start
                )
                if index == 0 {
                    activeActivityID = activity.id
                    scheduleWakeRefreshTask(at: night.wakeTime)
                }
            } catch {
                if index == 0 {
                    lastErrorMessage = error.localizedDescription
                }
                // The remaining budget is likely exhausted too; stop rather
                // than fail through the rest of the queue one at a time.
                break
            }
        }
    }

    /// Starts tonight's activity from the last saved plan, for entry points that
    /// can't recompute a recommendation, such as a background app intent.
    func startFromSavedPlan(now: Date = Date()) async {
        guard let plan = BedtimePlanStore.current(now: now) else {
            lastErrorMessage = "Open Bedger once so it can work out tonight's bedtime."
            return
        }

        await startOrUpdate(
            with: BedtimeRecommendation(plan: plan),
            durationStyle: plan.durationStyle
        )
    }

    func end() async {
        isWorking = true
        lastErrorMessage = nil
        defer { isWorking = false }

        for activity in Activity<BedtimeActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        activeActivityID = nil
    }

    private func endFinishedActivities(now: Date) async {
        for activity in Activity<BedtimeActivityAttributes>.activities
        where activity.content.state.wakeTime <= now {
            await activity.end(nil, dismissalPolicy: .immediate)
            if activity.id == activeActivityID {
                activeActivityID = nil
            }
        }
    }

    /// Static so the returned activity stays out of the main-actor region and
    /// its async `update`/`end` calls can be sent under strict concurrency.
    private nonisolated static func activity(withID id: String?) -> Activity<BedtimeActivityAttributes>? {
        guard let id else { return nil }
        return Activity<BedtimeActivityAttributes>.activities.first {
            $0.id == id
        }
    }

    private func getTimes(
        for recommendation: BedtimeRecommendation,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> (bedtime: Date, wakeTime: Date) {
        let bedtimeComponents = calendar.dateComponents(
            [.hour, .minute],
            from: recommendation.recommendedBedtime
        )
        let wakeTimeComponents = calendar.dateComponents(
            [.hour, .minute],
            from: recommendation.wakeTime
        )

        func occurrence(
            of components: DateComponents,
            from date: Date,
            direction: Calendar.SearchDirection
        ) -> Date? {
            calendar.nextDate(
                after: date,
                matching: components,
                matchingPolicy: .nextTime,
                repeatedTimePolicy: .first,
                direction: direction
            )
        }

        // Once bedtime has passed, the night underway is the one to show. Always
        // reaching for the next bedtime would jump a whole day forward and take
        // the wake time with it.
        if
            let lastBedtime = occurrence(of: bedtimeComponents, from: now, direction: .backward),
            let wakeAfterLastBedtime = occurrence(of: wakeTimeComponents, from: lastBedtime, direction: .forward),
            now < wakeAfterLastBedtime
        {
            return (lastBedtime, wakeAfterLastBedtime)
        }

        let bedtime = occurrence(of: bedtimeComponents, from: now, direction: .forward)
            ?? recommendation.recommendedBedtime
        let wakeTime = occurrence(of: wakeTimeComponents, from: bedtime, direction: .forward)
            ?? recommendation.wakeTime

        return (bedtime, wakeTime)
    }
}
