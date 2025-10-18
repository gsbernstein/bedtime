//
//  ViewModel.swift
//  Bedtime
//
//  Created by Greg on 10/17/25.
//

import Foundation

class ViewModel {
    static func calculateSleepBank(
        sleepSessions: [Date: [SleepSession]],
        goalHours: Double,
        recentDays: Int
    ) -> SleepBank {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -recentDays, to: endDate) ?? endDate
        
        // Filter sessions from the last N days
        let recentSessions = sleepSessions.filter { day, _ in
            day >= startDate && day <= endDate
        }
        
        let daysWithData = recentSessions.count
        
        // Calculate total sleep hours in the period
        let totalSleepHours = recentSessions.values.flatMap { $0 }.map { $0.durationInHours }.reduce(0, +)
        
        // Calculate expected sleep hours (goal * number of days)
        let expectedSleepHours = goalHours * Double(daysWithData)
        
        // Calculate current balance (actual - expected)
        let currentBalance = totalSleepHours - expectedSleepHours
        
        let averageHours = daysWithData > 0 ? totalSleepHours / Double(daysWithData) : nil
        
        return SleepBank(
            currentBalance: currentBalance,
            goalHours: goalHours,
            averageHours: averageHours
        )
    }
    
    static func generateBedtimeRecommendation(
        wakeTime: Date,
        sleepGoal: Double,
        sleepBank: SleepBank,
        maxSleepHours: Double,
        minSleepHours: Double
    ) -> BedtimeRecommendation {
        let calendar = Calendar.current
        
        // Calculate how much sleep we need tonight
        // If we're in debt, we need extra sleep to catch up
        var totalSleepNeeded = sleepGoal - sleepBank.currentBalance
        
        // Generate reason
        let reason: String
        if sleepBank.averageHours == nil {
            reason = "No data so far, just aim for your goal"
        } else if totalSleepNeeded > maxSleepHours {
            totalSleepNeeded = maxSleepHours
            reason = "You can't catch up in one night, so just get as much as possible."
        } else if totalSleepNeeded < minSleepHours {
            totalSleepNeeded = minSleepHours
            reason = "You're way ahead!"
        } else if sleepBank.isInDebt {
            let debtHours = sleepBank.debtHours
            reason = "You need \(String(format: "%.1f", totalSleepNeeded)) hours tonight to catch up on your \(String(format: "%.1f", debtHours))-hour sleep debt."
        } else {
            reason = "You're ahead of the game! Aim for at least \(String(format: "%.1f", sleepGoal)) hours tonight."
        }
        
        // Calculate recommended bedtime
        let recommendedBedtime = calendar.date(byAdding: .minute, value: -Int(totalSleepNeeded * 60), to: wakeTime) ?? wakeTime.addingTimeInterval(-totalSleepNeeded * 60 * 60)
        
        return BedtimeRecommendation(
            recommendedBedtime: recommendedBedtime,
            wakeTime: wakeTime,
            targetSleepDuration: totalSleepNeeded,
            reason: reason
        )
    }
}
