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

    /// Real hours available on the current night — DST-aware, for the main-screen
    /// recommendation where "how much can I actually get tonight" is what matters.
    var effectiveMaxSleepHours: Double {
        Self.maxSleepHours(earliestBedtime: earliestReasonableBedtime, wakeTime: wakeTime)
    }

    /// Nominal wall-clock length of the sleep window (a stable 10h for a 9pm–7am
    /// schedule, ignoring DST). For settings/schedule display, where a value that
    /// wobbles ±1h twice a year would just be confusing.
    var nominalMaxSleepHours: Double {
        Self.nominalWindowHours(earliestBedtime: earliestReasonableBedtime, wakeTime: wakeTime)
    }

    /// Real hours between the earliest reasonable bedtime and wake time for the
    /// night ending at the next wake from `referenceDate`. Anchoring on the wake
    /// (forward from now) then searching backward for the bedtime keeps the
    /// window correct even when the app is opened mid-sleep, and lets `Calendar`
    /// absorb the ±1h of a DST transition instead of assuming a 24h day.
    static func maxSleepHours(
        earliestBedtime: Date,
        wakeTime: Date,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> Double {
        let wakeComponents = calendar.dateComponents([.hour, .minute], from: wakeTime)
        let bedComponents = calendar.dateComponents([.hour, .minute], from: earliestBedtime)

        guard
            let wake = calendar.nextDate(
                after: referenceDate,
                matching: wakeComponents,
                matchingPolicy: .strict
            ),
            let bed = calendar.nextDate(
                after: wake,
                matching: bedComponents,
                matchingPolicy: .strict,
                direction: .backward
            )
        else {
            // Fall back to a nominal wall-clock window if a match can't be found.
            return nominalWindowHours(earliestBedtime: earliestBedtime, wakeTime: wakeTime, calendar: calendar)
        }

        return wake.timeIntervalSince(bed) / 3600.0
    }

    static func nominalWindowHours(
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
