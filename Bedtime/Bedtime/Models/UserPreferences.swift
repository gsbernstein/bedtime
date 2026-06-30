//
//  UserPreferences.swift
//  Bedtime
//
//  Created by Greg on 10/4/25.
//

import Foundation
import SwiftData

@Model
final class UserPreferences {
    var sleepGoalHours: Double
    var wakeTime: Date
    var sleepBankDays: Int
    var lastUpdated: Date
    /// Legacy limit kept for SwiftData schema compatibility and migration.
    var maxSleepHoursPerNight: Double
    /// Preferred bedtime floor; migrated from `maxSleepHoursPerNight` when nil.
    var earliestReasonableBedtime: Date?
    var minSleepHoursPerNight: Double

    init(
        sleepGoalHours: Double = 8.0,
        wakeTime: Date = Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? Date(),
        sleepBankDays: Int = 7,
        maxSleepHoursPerNight: Double = 10,
        earliestReasonableBedtime: Date? = nil,
        minSleepHoursPerNight: Double = 5
    ) {
        self.sleepGoalHours = sleepGoalHours
        self.wakeTime = wakeTime
        self.sleepBankDays = sleepBankDays
        self.lastUpdated = Date()
        self.maxSleepHoursPerNight = maxSleepHoursPerNight
        self.minSleepHoursPerNight = minSleepHoursPerNight
        self.earliestReasonableBedtime = earliestReasonableBedtime
            ?? Self.earliestBedtime(maxSleepHours: maxSleepHoursPerNight, wakeTime: wakeTime)
    }

    /// Earliest bedtime used by settings and recommendations.
    var resolvedEarliestBedtime: Date {
        earliestReasonableBedtime
            ?? Self.earliestBedtime(maxSleepHours: maxSleepHoursPerNight, wakeTime: wakeTime)
    }

    /// Longest sleep window allowed before hitting the earliest reasonable bedtime.
    var effectiveMaxSleepHours: Double {
        Self.maxSleepHours(earliestBedtime: resolvedEarliestBedtime, wakeTime: wakeTime)
    }

    /// One-time migration for stores that predate `earliestReasonableBedtime`.
    func migrateBedtimeLimitIfNeeded() {
        guard earliestReasonableBedtime == nil else { return }
        earliestReasonableBedtime = Self.earliestBedtime(
            maxSleepHours: maxSleepHoursPerNight,
            wakeTime: wakeTime
        )
    }

    static func maxSleepHours(
        earliestBedtime: Date,
        wakeTime: Date,
        calendar: Calendar = .current
    ) -> Double {
        let wakeMinutes = minutesSinceMidnight(wakeTime, calendar: calendar)
        let earliestMinutes = minutesSinceMidnight(earliestBedtime, calendar: calendar)

        let sleepMinutes: Int
        if earliestMinutes > wakeMinutes {
            sleepMinutes = (24 * 60 - earliestMinutes) + wakeMinutes
        } else {
            sleepMinutes = wakeMinutes - earliestMinutes
        }

        return Double(sleepMinutes) / 60.0
    }

    static func earliestBedtime(
        maxSleepHours: Double,
        wakeTime: Date,
        calendar: Calendar = .current
    ) -> Date {
        let wakeMinutes = minutesSinceMidnight(wakeTime, calendar: calendar)
        let sleepMinutes = Int((maxSleepHours * 60).rounded())
        var earliestMinutes = wakeMinutes - sleepMinutes
        if earliestMinutes < 0 {
            earliestMinutes += 24 * 60
        }

        return calendar.date(
            from: DateComponents(
                hour: earliestMinutes / 60,
                minute: earliestMinutes % 60
            )
        ) ?? wakeTime
    }

    private static func minutesSinceMidnight(_ date: Date, calendar: Calendar) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
}
