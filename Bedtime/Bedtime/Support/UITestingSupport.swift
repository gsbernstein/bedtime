#if DEBUG
import Foundation
import HealthKit

enum UITestingSupport {
    static var isActive: Bool {
        ProcessInfo.processInfo.arguments.contains("-ui_testing")
    }

    static func mockSleepSessions() -> [Date: [SleepSession]] {
        let source = HKSourceRevision(source: HKSource.default(), version: nil)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        func session(
            dayOffset: Int,
            startHour: Int,
            startMinute: Int,
            endHour: Int,
            endMinute: Int
        ) -> SleepSession {
            let base = calendar.date(byAdding: .day, value: dayOffset, to: today) ?? today
            let start = calendar.date(
                bySettingHour: startHour,
                minute: startMinute,
                second: 0,
                of: base
            ) ?? base
            let endDayOffset = endHour < startHour ? 1 : 0
            let endBase = calendar.date(byAdding: .day, value: endDayOffset, to: base) ?? base
            let end = calendar.date(
                bySettingHour: endHour,
                minute: endMinute,
                second: 0,
                of: endBase
            ) ?? endBase

            return SleepSession(
                startDate: start,
                endDate: end,
                sleepType: .asleepCore,
                source: source
            )
        }

        let lastNight = session(dayOffset: -1, startHour: 23, startMinute: 15, endHour: 7, endMinute: 5)
        let twoNightsAgo = session(dayOffset: -2, startHour: 22, startMinute: 45, endHour: 6, endMinute: 30)
        let threeNightsAgo = session(dayOffset: -3, startHour: 23, startMinute: 30, endHour: 7, endMinute: 45)

        return [
            lastNight.dateForGrouping: [lastNight],
            twoNightsAgo.dateForGrouping: [twoNightsAgo],
            threeNightsAgo.dateForGrouping: [threeNightsAgo],
        ]
    }
}
#endif
