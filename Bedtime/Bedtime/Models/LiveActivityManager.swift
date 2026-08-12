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

        let schedule = upcomingSchedule(for: recommendation)
        let state = BedtimeActivityAttributes.ContentState(
            // Updating an existing activity keeps its original start so the
            // wind-down bar doesn't jump back to empty.
            activityStart: currentActivity?.content.state.activityStart ?? Date(),
            bedtime: schedule.bedtime,
            wakeTime: schedule.wakeTime,
            targetSleepHours: recommendation.targetSleepDuration,
            durationStyle: durationStyle
        )
        // Going stale at bedtime is what flips the card from the wind-down
        // countdown to the sleeping one while the app is suspended.
        let content = ActivityContent(
            state: state,
            staleDate: schedule.bedtime
        )

        if let activity = currentActivity {
            await activity.update(content)
            activeActivityID = activity.id
            return
        }

        do {
            let activity = try Activity.request(
                attributes: BedtimeActivityAttributes(title: "Bedger"),
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

        let schedule = upcomingSchedule(for: recommendation, now: now)
        // Once bedtime passes, the next match is tomorrow's, so this only opens
        // the window ahead of tonight's bedtime. An activity already running
        // carries the rest of the night on its own.
        guard now >= schedule.bedtime.addingTimeInterval(-leadTime) else { return }

        await startOrUpdate(with: recommendation, durationStyle: durationStyle)
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

    private var currentActivity: Activity<BedtimeActivityAttributes>? {
        guard let activeActivityID else { return nil }
        return Activity<BedtimeActivityAttributes>.activities.first {
            $0.id == activeActivityID
        }
    }

    private func upcomingSchedule(
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

        let bedtime = calendar.nextDate(
            after: now,
            matching: bedtimeComponents,
            matchingPolicy: .nextTime,
            repeatedTimePolicy: .first,
            direction: .forward
        ) ?? recommendation.recommendedBedtime
        let wakeTime = calendar.nextDate(
            after: bedtime,
            matching: wakeTimeComponents,
            matchingPolicy: .nextTime,
            repeatedTimePolicy: .first,
            direction: .forward
        ) ?? recommendation.wakeTime

        return (bedtime, wakeTime)
    }
}
