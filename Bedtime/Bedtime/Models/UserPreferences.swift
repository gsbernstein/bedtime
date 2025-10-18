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
    var maxSleepHoursPerNight: Double
    var minSleepHoursPerNight: Double
    
    init(
        sleepGoalHours: Double = 8.0,
        wakeTime: Date = Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? Date(),
        sleepBankDays: Int = 7,
        maxSleepHoursPerNight: Double = 12,
        minSleepHoursPerNight: Double = 5
    ) {
        self.sleepGoalHours = sleepGoalHours
        self.wakeTime = wakeTime
        self.sleepBankDays = sleepBankDays
        self.lastUpdated = Date()
        self.maxSleepHoursPerNight = maxSleepHoursPerNight
        self.minSleepHoursPerNight = minSleepHoursPerNight
    }
}
