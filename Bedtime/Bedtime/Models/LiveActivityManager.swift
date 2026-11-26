import ActivityKit
import BackgroundTasks
import Combine
import Foundation
import UIKit

enum LiveActivityStatus: Equatable {
    case unavailable
    case disabled
    case active(bedtime: Date, wakeTime: Date, isSleeping: Bool, isAwake: Bool)
    case scheduled(nextStart: Date, bedtime: Date, count: Int)
    case inactive
}

@MainActor
final class LiveActivityManager: ObservableObject {
    /// Shared so an app intent launched in the background drives the same
    /// activity the UI is showing.
    static let shared = LiveActivityManager()

    @Published private(set) var activeActivityID: String?
    @Published private(set) var status: LiveActivityStatus = .inactive
    @Published private(set) var isWorking = false
    @Published private(set) var lastErrorMessage: String?

    /// Serializes ActivityKit operations so overlapping calls from `.task`,
    /// `scenePhase`, and recommendation updates never race across `await`s
    /// and exceed the concurrent activity limit.
    private var inFlightOperation: Task<Void, Never>?

    var isActivityActive: Bool {
        if case .active = status {
            return true
        }
        return false
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
        refreshStatus()
    }

    /// Registers the background refresh task handler. Apple requires this to
    /// happen synchronously before the app finishes launching, so call it from
    /// `BedtimeApp.init()` rather than anywhere the shared instance is used —
    /// registration doesn't depend on there being an activity yet. `nonisolated`
    /// since `App.init()` isn't MainActor-isolated; the launch handler still
    /// hops to the main actor itself before touching `.shared`.
    nonisolated static func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Constants.wakeRefreshTaskIdentifier,
            using: nil
        ) { task in
            // BGTask isn't Sendable, but the system allows calling
            // setTaskCompleted from any context — matches the HealthKit
            // observer's completionHandler workaround.
            nonisolated(unsafe) let task = task
            Task { @MainActor in
                await LiveActivityManager.shared.markAwakeIfNeeded()
                task.setTaskCompleted(success: true)
            }
        }
    }

    func refreshStatus(now: Date = Date()) {
        guard isSupported else {
            activeActivityID = nil
            status = .unavailable
            return
        }

        guard areActivitiesEnabled else {
            activeActivityID = Self.currentlyVisibleActivity()?.id
            status = .disabled
            return
        }

        if let visible = Self.currentlyVisibleActivity() {
            let state = visible.content.state
            activeActivityID = visible.id
            status = .active(
                bedtime: state.bedtime,
                wakeTime: state.wakeTime,
                isSleeping: state.isSleeping || now >= state.bedtime,
                isAwake: state.isAwake
            )
            return
        }

        activeActivityID = nil

        if #available(iOS 26, *) {
            let pending = Activity<BedtimeActivityAttributes>.activities
                .filter { $0.activityState == .pending }
                .sorted { $0.content.state.activityStart < $1.content.state.activityStart }
            if let next = pending.first {
                status = .scheduled(
                    nextStart: next.content.state.activityStart,
                    bedtime: next.content.state.bedtime,
                    count: pending.count
                )
                return
            }
        }

        status = .inactive
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
        sourceAppLink: BedtimeSourceAppLink? = nil,
        allowBackgroundRequest: Bool = false
    ) async {
        await runSerialized {
            await self.startOrUpdateImpl(
                with: recommendation,
                durationStyle: durationStyle,
                sourceAppLink: sourceAppLink,
                allowBackgroundRequest: allowBackgroundRequest
            )
        }
    }

    /// Flips the activity to its post-wake phase once `wakeTime` has passed,
    /// without recomputing the recommendation: this runs from a HealthKit
    /// background delivery callback or the wake-refresh background task,
    /// neither of which has cheap access to the full recommendation inputs
    /// (HealthKit averages, SwiftData preferences) — nor needs them, since
    /// every other field on the activity is left exactly as it was.
    func markAwakeIfNeeded(now: Date = Date()) async {
        await runSerialized {
            await self.markAwakeIfNeededImpl(now: now)
        }
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
        await runSerialized {
            await self.syncWithScheduleImpl(
                recommendation: recommendation,
                durationStyle: durationStyle,
                leadTime: leadTime,
                now: now,
                sourceAppLink: sourceAppLink
            )
        }
    }

    /// Starts tonight's activity from the last saved plan, for entry points that
    /// can't recompute a recommendation, such as a background `LiveActivityIntent`.
    func startFromSavedPlan(now: Date = Date()) async {
        await runSerialized {
            guard let plan = BedtimePlanStore.current(now: now) else {
                self.lastErrorMessage = "Open Bedger once so it can work out tonight's bedtime."
                return
            }

            await self.startOrUpdateImpl(
                with: BedtimeRecommendation(plan: plan),
                durationStyle: plan.durationStyle,
                allowBackgroundRequest: true
            )
        }
    }

    func end() async {
        await runSerialized {
            self.isWorking = true
            self.lastErrorMessage = nil
            defer { self.isWorking = false }

            for activity in Activity<BedtimeActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Constants.wakeRefreshTaskIdentifier)
            self.refreshStatus()
        }
    }

    func cancelScheduled() async {
        await runSerialized {
            self.isWorking = true
            self.lastErrorMessage = nil
            defer { self.isWorking = false }

            if #available(iOS 26, *) {
                for activity in Activity<BedtimeActivityAttributes>.activities where activity.activityState == .pending {
                    await activity.end(nil, dismissalPolicy: .immediate)
                }
            }
            if Self.currentlyVisibleActivity() == nil {
                BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Constants.wakeRefreshTaskIdentifier)
            }
            self.refreshStatus()
        }
    }

    // MARK: - Serialized Implementations

    private func runSerialized(_ operation: @escaping @MainActor () async -> Void) async {
        let previous = inFlightOperation
        let task = Task { @MainActor in
            await previous?.value
            await operation()
        }
        inFlightOperation = task
        await task.value
        if inFlightOperation == task {
            inFlightOperation = nil
        }
    }

    private func startOrUpdateImpl(
        with recommendation: BedtimeRecommendation,
        durationStyle: DurationDisplayStyle,
        sourceAppLink: BedtimeSourceAppLink? = nil,
        allowBackgroundRequest: Bool
    ) async {
        guard isSupported else {
            lastErrorMessage = "Live Activities need iOS 18 or later."
            refreshStatus()
            return
        }

        guard areActivitiesEnabled else {
            lastErrorMessage = "Live Activities are disabled for Bedger in system settings."
            refreshStatus()
            return
        }

        isWorking = true
        lastErrorMessage = nil
        defer {
            isWorking = false
            refreshStatus()
        }

        let now = Date()
        let schedule = getTimes(for: recommendation, now: now)
        let isSleeping = now >= schedule.bedtime
        let startTime = Self.currentlyVisibleActivity()?.content.state.activityStart
            ?? newStartTime(bedtime: schedule.bedtime, now: now)
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

        if let primary = Self.currentlyVisibleActivity() {
            let primaryID = primary.id
            // `.stale` still counts as on screen: the sleeping phase is
            // reached by deliberately letting the wind-down content go stale
            // at bedtime, so this is the common case for most of the night.
            await primary.update(content)
            for activity in Activity<BedtimeActivityAttributes>.activities
            where activity.id != primaryID && (activity.activityState == .active || activity.activityState == .stale) {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            scheduleWakeRefreshTask(at: schedule.wakeTime)
            return
        }

        // Calling `Activity.request` from a non-intent background wakeup throws
        // `ActivityAuthorizationError.visibility`. Skip silently instead of
        // tearing down any queued `.pending` activities or flashing an error.
        guard allowBackgroundRequest || UIApplication.shared.applicationState == .active else {
            return
        }

        // Nothing to update in place, so this is about to request a new
        // activity. Clear every `.pending` one first so they don't consume the
        // 5-concurrent-activity budget (`targetMaximumExceeded`).
        if #available(iOS 26, *) {
            for activity in Activity<BedtimeActivityAttributes>.activities where activity.activityState == .pending {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }

        do {
            _ = try Activity.request(
                attributes: BedtimeActivityAttributes(),
                content: content,
                pushType: nil
            )
            scheduleWakeRefreshTask(at: schedule.wakeTime)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func markAwakeIfNeededImpl(now: Date) async {
        defer { refreshStatus(now: now) }
        guard let activity = Self.currentlyVisibleActivity() else { return }

        let state = activity.content.state
        // Wind-down → sleeping happens via `staleDate` without flipping
        // `state.isSleeping`, so check `wakeTime` and `!isAwake` directly.
        guard !state.isAwake, now >= state.wakeTime else { return }

        var updatedState = BedtimeActivityAttributes.ContentState(
            activityStart: state.activityStart,
            bedtime: state.bedtime,
            wakeTime: state.wakeTime,
            targetSleepHours: state.targetSleepHours,
            durationStyle: state.durationStyle,
            isSleeping: true,
            nightsSinceLastSync: state.nightsSinceLastSync,
            sourceAppLink: state.sourceAppLink,
            isAwake: true
        )
        updatedState.isAwake = true
        // Nothing left to wait for, so there's no future date to go stale at.
        await activity.update(ActivityContent(state: updatedState, staleDate: nil))
    }

    private func syncWithScheduleImpl(
        recommendation: BedtimeRecommendation,
        durationStyle: DurationDisplayStyle,
        leadTime: TimeInterval,
        now: Date,
        sourceAppLink: BedtimeSourceAppLink?
    ) async {
        defer { refreshStatus(now: now) }
        await endFinishedActivitiesImpl(now: now)

        guard isSupported, areActivitiesEnabled else { return }

        let schedule = getTimes(for: recommendation, now: now)
        // Same reasoning as `newStartTime`: an actual elapsed-time lead, not a
        // wall-clock gap that could stretch or shrink across a DST transition.
        let windowOpens = schedule.bedtime.addingTimeInterval(-leadTime)

        // Once bedtime's wind-down window opens, start or update tonight's
        // activity directly.
        guard now < windowOpens else {
            await startOrUpdateImpl(
                with: recommendation,
                durationStyle: durationStyle,
                sourceAppLink: sourceAppLink,
                allowBackgroundRequest: false
            )
            return
        }

        // If an activity is already visible on screen before `windowOpens`
        // (e.g. user tapped Start Now), refresh its content.
        if Self.currentlyVisibleActivity() != nil {
            await startOrUpdateImpl(
                with: recommendation,
                durationStyle: durationStyle,
                sourceAppLink: sourceAppLink,
                allowBackgroundRequest: false
            )
        }

        if #available(iOS 26, *) {
            await scheduleUpcomingNightsImpl(
                recommendation: recommendation,
                durationStyle: durationStyle,
                schedule: schedule,
                startingAt: windowOpens,
                sourceAppLink: sourceAppLink
            )
        }
    }

    /// Hands future starts over to the system so the wind-down card appears on
    /// its own, since starting one from a background wake throws
    /// `ActivityAuthorizationError.visibility`.
    @available(iOS 26, *)
    private func scheduleUpcomingNightsImpl(
        recommendation: BedtimeRecommendation,
        durationStyle: DurationDisplayStyle,
        schedule: (bedtime: Date, wakeTime: Date),
        startingAt start: Date,
        sourceAppLink: BedtimeSourceAppLink?
    ) async {
        guard UIApplication.shared.applicationState == .active else { return }

        let calendar = Calendar.autoupdatingCurrent
        // Both `.active` and `.stale` activities count against the system's
        // concurrent activity budget.
        let liveActivities = Activity<BedtimeActivityAttributes>.activities
            .filter { $0.activityState == .active || $0.activityState == .stale }
        let nightCount = max(0, BedtimeActivityAttributes.maxConcurrentActivities - liveActivities.count)
        guard nightCount > 0 else { return }

        // If tonight's bedtime is already covered by a visible activity (e.g.
        // started early via Start Now), start the scheduled queue tomorrow.
        let startOffset = liveActivities.contains { $0.content.state.bedtime == schedule.bedtime } ? 1 : 0
        let projectedNights: [(offset: Int, start: Date, bedtime: Date, wakeTime: Date)] = (startOffset..<(startOffset + nightCount)).compactMap { offset in
            guard
                let nightStart = calendar.date(byAdding: .day, value: offset, to: start),
                let nightBedtime = calendar.date(byAdding: .day, value: offset, to: schedule.bedtime),
                let nightWakeTime = calendar.date(byAdding: .day, value: offset, to: schedule.wakeTime)
            else { return nil }
            return (offset, nightStart, nightBedtime, nightWakeTime)
        }

        // Check exact count + state so duplicate `.pending` activities or
        // display-setting changes trigger a clean rebuild.
        let pendingActivities = Activity<BedtimeActivityAttributes>.activities
            .filter { $0.activityState == .pending }
        let pendingMatches = pendingActivities.count == projectedNights.count
            && Set(pendingActivities.map(\.content.state.bedtime)) == Set(projectedNights.map(\.bedtime))
            && pendingActivities.allSatisfy {
                $0.content.state.durationStyle == durationStyle
                    && $0.content.state.targetSleepHours == recommendation.targetSleepDuration
                    && $0.content.state.sourceAppLink == sourceAppLink
            }
        guard !pendingMatches else { return }

        isWorking = true
        lastErrorMessage = nil
        defer { isWorking = false }

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
                nightsSinceLastSync: night.offset,
                sourceAppLink: sourceAppLink
            )

            do {
                _ = try Activity.request(
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

    private func endFinishedActivitiesImpl(now: Date) async {
        for activity in Activity<BedtimeActivityAttributes>.activities
        where activity.content.state.wakeTime <= now {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    /// Best-effort backup for `markAwakeIfNeeded`, in case HealthKit doesn't
    /// deliver new sleep data by wake time (no watch/ring worn, slow sync,
    /// etc). Not time-precise — iOS decides when to actually run it.
    private func scheduleWakeRefreshTask(at wakeTime: Date) {
        let request = BGProcessingTaskRequest(identifier: Constants.wakeRefreshTaskIdentifier)
        request.earliestBeginDate = wakeTime
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        try? BGTaskScheduler.shared.submit(request)
    }

    /// Static so the returned activity stays out of the main-actor region and
    /// its async `update`/`end` calls can be sent under strict concurrency.
    private nonisolated static func currentlyVisibleActivity() -> Activity<BedtimeActivityAttributes>? {
        Activity<BedtimeActivityAttributes>.activities.first {
            $0.activityState == .active || $0.activityState == .stale
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
