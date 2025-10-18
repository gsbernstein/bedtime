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
        
        return SleepBank(
            currentBalance: currentBalance,
            goalHours: goalHours,
            averageHours: totalSleepHours / Double(daysWithData)
        )
    }
    
    static func generateBedtimeRecommendation(
        wakeTime: Date,
        sleepGoal: Double,
        sleepBank: SleepBank
    ) -> BedtimeRecommendation {
        let calendar = Calendar.current
        
        // Calculate how much sleep we need tonight
        // If we're in debt, we need extra sleep to catch up
        let extraSleepNeeded = max(0, -sleepBank.currentBalance)
        let totalSleepNeeded = sleepGoal + extraSleepNeeded
        
        // Calculate recommended bedtime
        let recommendedBedtime = calendar.date(byAdding: .minute, value: -Int(totalSleepNeeded * 60), to: wakeTime) ?? wakeTime.addingTimeInterval(-totalSleepNeeded * 60 * 60)
        
        // Generate reason
        let reason: String
        if sleepBank.isInDebt {
            let debtHours = sleepBank.debtHours
            reason = "You need \(String(format: "%.1f", totalSleepNeeded)) hours tonight to catch up on your \(String(format: "%.1f", debtHours))-hour sleep debt."
        } else {
            reason = "You're on track! Aim for \(String(format: "%.1f", sleepGoal)) hours tonight."
        }
        
        return BedtimeRecommendation(
            recommendedBedtime: recommendedBedtime,
            wakeTime: wakeTime,
            targetSleepDuration: totalSleepNeeded,
            reason: reason
        )
    }
}
