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
    /// When true, durations use decimal hours ("5.1h"); otherwise "5h 6m".
    var useDecimalDurations: Bool = false
    /// Stored as a raw string so an unrecognized value (e.g. from a future app version)
    /// falls back to `.cozy` instead of failing to load.
    private var themeRawValue: String = AppTheme.cozy.rawValue
    /// When true, the sleep balance waterfall chart is hidden from the Sleep Balance card.
    var hideSleepBankChart: Bool = false

    var durationDisplayStyle: DurationDisplayStyle {
        useDecimalDurations ? .decimal : .hoursAndMinutes
    }

    var theme: AppTheme {
        get { AppTheme(rawValue: themeRawValue) ?? .cozy }
        set { themeRawValue = newValue.rawValue }
    }

    init(
        sleepGoalHours: Double = 8.0,
        wakeTime: Date = Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? Date(),
        sleepBankDays: Int = 7,
        earliestReasonableBedtime: Date = Calendar.current.date(from: DateComponents(hour: 21, minute: 0)) ?? Date(),
        useDecimalDurations: Bool = false,
        theme: AppTheme = .cozy,
        hideSleepBankChart: Bool = false
    ) {
        self.sleepGoalHours = sleepGoalHours
        self.wakeTime = wakeTime
        self.sleepBankDays = sleepBankDays
        self.lastUpdated = Date()
        self.earliestReasonableBedtime = earliestReasonableBedtime
        self.useDecimalDurations = useDecimalDurations
        self.themeRawValue = theme.rawValue
        self.hideSleepBankChart = hideSleepBankChart
    }

    /// Convenience accessor for the nominal sleep-window length from this
    /// schedule's stored times. Now-aware/DST math lives in `SleepWindow`.
    var nominalMaxSleepHours: Double {
        SleepWindow.nominalWindowHours(earliestBedtime: earliestReasonableBedtime, wakeTime: wakeTime)
    }
}
