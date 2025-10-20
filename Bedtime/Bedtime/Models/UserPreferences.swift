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
    var wakeHour: Int
    var wakeMinute: Int
    var sleepBankDays: Int
    var lastUpdated: Date
    var maxSleepHoursPerNight: Double
    var minSleepHoursPerNight: Double
    
    init(
        sleepGoalHours: Double = 8.0,
        wakeHour: Int = 7,
        wakeMinute: Int = 0,
        sleepBankDays: Int = 7,
        maxSleepHoursPerNight: Double = 12,
        minSleepHoursPerNight: Double = 5
    ) {
        self.sleepGoalHours = sleepGoalHours
        self.wakeHour = wakeHour
        self.wakeMinute = wakeMinute
        self.sleepBankDays = sleepBankDays
        self.lastUpdated = Date()
        self.maxSleepHoursPerNight = maxSleepHoursPerNight
        self.minSleepHoursPerNight = minSleepHoursPerNight
    }
    
    var wakeTime: Date {
        get {
            let calendar = Calendar.current
            let today = Date()
            return calendar.date(bySettingHour: wakeHour, minute: wakeMinute, second: 0, of: today) ?? today
        }
        set {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.hour, .minute], from: newValue)
            self.wakeHour = components.hour ?? 7
            self.wakeMinute = components.minute ?? 0
        }
    }
}
