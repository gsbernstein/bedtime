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
    
    init(
        sleepGoalHours: Double = 8.0,
        wakeTime: Date = Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? Date(),
        sleepBankDays: Int = 7
    ) {
        self.sleepGoalHours = sleepGoalHours
        self.wakeTime = wakeTime
        self.sleepBankDays = sleepBankDays
        self.lastUpdated = Date()
    }
    
    // Helper to get wake time as a formatted string
    var wakeTimeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: wakeTime)
    }
    
    // Helper to get sleep goal as a formatted string
    var sleepGoalString: String {
        return String(format: "%.1f hours", sleepGoalHours)
    }
}
