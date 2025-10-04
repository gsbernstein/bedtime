//
//  SleepData.swift
//  Bedtime
//
//  Created by Greg on 10/4/25.
//

import Foundation
import HealthKit

struct SleepSession {
    let startDate: Date
    let endDate: Date
    let duration: TimeInterval
    
    init(startDate: Date, endDate: Date) {
        self.startDate = startDate
        self.endDate = endDate
        self.duration = endDate.timeIntervalSince(startDate)
    }
    
    var durationInHours: Double {
        return duration / 3600.0
    }
}

struct SleepBank {
    let currentBalance: Double // in hours
    let goalHours: Double
    let recentSessions: [SleepSession]
    
    var isInDebt: Bool {
        return currentBalance < 0
    }
    
    var debtHours: Double {
        return max(0, -currentBalance)
    }
    
    var creditHours: Double {
        return max(0, currentBalance)
    }
    
    var statusDescription: String {
        if isInDebt {
            return "You're \(String(format: "%.1f", debtHours)) hours behind your sleep goal"
        } else {
            return "You're \(String(format: "%.1f", creditHours)) hours ahead of your sleep goal"
        }
    }
}

struct BedtimeRecommendation {
    let recommendedBedtime: Date
    let wakeTime: Date
    let targetSleepDuration: Double // in hours
    let reason: String
}
