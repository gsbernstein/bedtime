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
    var wakeTime: DateComponents
    var sleepBankDays: Int
    var lastUpdated: Date
    var maxSleepHoursPerNight: Double
    var minSleepHoursPerNight: Double
    
    internal init(
        sleepGoalHours: Double = 8,
        wakeTime: DateComponents = DateComponents(hour: 7),
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
