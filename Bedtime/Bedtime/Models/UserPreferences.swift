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
    var earliestReasonableBedtime: Date

    init(
        sleepGoalHours: Double = 8.0,
        wakeTime: Date = Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? Date(),
        sleepBankDays: Int = 7,
        earliestReasonableBedtime: Date = Calendar.current.date(from: DateComponents(hour: 21, minute: 0)) ?? Date()
    ) {
        self.sleepGoalHours = sleepGoalHours
        self.wakeTime = wakeTime
        self.sleepBankDays = sleepBankDays
        self.lastUpdated = Date()
        self.earliestReasonableBedtime = earliestReasonableBedtime
    }

    /// Longest sleep window allowed before hitting the earliest reasonable bedtime.
    var effectiveMaxSleepHours: Double {
        Self.maxSleepHours(earliestBedtime: earliestReasonableBedtime, wakeTime: wakeTime)
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

    private static func minutesSinceMidnight(_ date: Date, calendar: Calendar) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
}
