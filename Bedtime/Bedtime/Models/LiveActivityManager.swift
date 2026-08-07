import ActivityKit
import Combine
import Foundation

@MainActor
final class LiveActivityManager: ObservableObject {
    @Published private(set) var activeActivityID: String?
    @Published private(set) var isWorking = false
    @Published private(set) var lastErrorMessage: String?

    var isActivityActive: Bool {
        activeActivityID != nil
    }

    var areActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    init() {
        activeActivityID = Activity<BedtimeActivityAttributes>.activities.first?.id
    }

    func startOrUpdate(with recommendation: BedtimeRecommendation) async {
        guard areActivitiesEnabled else {
            lastErrorMessage = "Live Activities are disabled for Bedger in system settings."
            return
        }

        isWorking = true
        lastErrorMessage = nil
        defer { isWorking = false }

        let schedule = upcomingSchedule(for: recommendation)
        let state = BedtimeActivityAttributes.ContentState(
            activityStart: Date(),
            bedtime: schedule.bedtime,
            wakeTime: schedule.wakeTime,
            targetSleepHours: recommendation.targetSleepDuration
        )
        let content = ActivityContent(
            state: state,
            staleDate: schedule.wakeTime
        )

        if let activity = currentActivity {
            await activity.update(content)
            activeActivityID = activity.id
            return
        }

        do {
            let activity = try Activity.request(
                attributes: BedtimeActivityAttributes(title: "Tonight’s sleep plan"),
                content: content,
                pushType: nil
            )
            activeActivityID = activity.id
        } catch {
            lastErrorMessage = error.localizedDescription
        }
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
