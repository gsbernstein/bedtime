import ActivityKit
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

    func newStartTime(bedtime: Date, now: Date) -> Date {
        // A fixed elapsed-time subtraction rather than calendar arithmetic: the
        // lead time should always be an actual 30 minutes, not a wall-clock gap
        // that a DST transition happening to land near bedtime could stretch or shrink.
        let defaultTime = bedtime.addingTimeInterval(-Constants.liveActivityLeadTime)
        return min(now, defaultTime)
    }

    func startOrUpdate(
        with recommendation: BedtimeRecommendation,
        durationStyle: DurationDisplayStyle
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
            isSleeping: isSleeping
        )
        // Going stale at bedtime flips the card to the sleeping countdown while
        // the app is suspended. Starting mid-night, bedtime has already gone by,
        // so the state above carries the phase and this stays ahead of now.
        let content = ActivityContent(
            state: state,
            staleDate: isSleeping ? schedule.wakeTime : schedule.bedtime
        )

        if let activity = Self.activity(withID: activeActivityID) {
            if activity.activityState == .active {
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
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    /// Starts the activity once the wind-down window opens, refreshes it if the
    /// schedule moved, and clears out last night's once the wake time has passed.
    /// Safe to call on every foreground.
    func syncWithSchedule(
        recommendation: BedtimeRecommendation,
        durationStyle: DurationDisplayStyle,
        leadTime: TimeInterval = Constants.liveActivityLeadTime,
        now: Date = Date()
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
            await startOrUpdate(with: recommendation, durationStyle: durationStyle)
            return
        }

        if #available(iOS 26, *) {
            await scheduleUpcomingNights(
                recommendation: recommendation,
                durationStyle: durationStyle,
                schedule: schedule,
                startingAt: windowOpens
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
        startingAt start: Date
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

        let pending = Activity<BedtimeActivityAttributes>.activities.filter { $0.activityState == .pending }
        // Already queued up with tonight's exact bedtimes, so leave it alone
        // rather than tearing down and rebuilding an unchanged queue.
        let pendingBedtimes = Set(pending.map(\.content.state.bedtime))
        let desiredBedtimes = Set(projectedNights.map(\.bedtime))
        guard pendingBedtimes != desiredBedtimes else { return }

        for activity in pending {
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
                nightsSinceLastSync: index
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
