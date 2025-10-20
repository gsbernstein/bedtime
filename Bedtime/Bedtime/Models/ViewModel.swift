//
//  ViewModel.swift
//  Bedtime
//
//  Created by Greg on 10/17/25.
//

import Foundation

class ViewModel {
    static func calculateSleepBank(
        daySleepData: [Date: DaySleepData],
        goalHours: Double,
        recentDays: Int
    ) -> SleepBank {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -recentDays, to: endDate) ?? endDate
        
        // Filter days from the last N days
        let recentDays = daySleepData.filter { day, _ in
            day >= startDate && day <= endDate
        }
        
        let daysWithData = recentDays.count
        
        // Calculate total night sleep hours in the period (exclude naps)
        let totalSleepHours = recentDays.values.map { $0.totalNightSleepHours }.reduce(0, +)
        
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
        minSleepHours: Double,
        timeInBedBuffer: Double
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
        
        // Calculate recommended bedtime (when to fall asleep)
        let recommendedBedtime = calendar.date(byAdding: .minute, value: -Int(totalSleepNeeded * 60), to: wakeTime) ?? wakeTime.addingTimeInterval(-totalSleepNeeded * 60 * 60)
        
        // Calculate when to go to bed (subtract buffer)
        let goToBedTime = calendar.date(byAdding: .minute, value: -Int((totalSleepNeeded + timeInBedBuffer) * 60), to: wakeTime) ?? wakeTime.addingTimeInterval(-(totalSleepNeeded + timeInBedBuffer) * 60 * 60)
        
        return BedtimeRecommendation(
            recommendedBedtime: recommendedBedtime,
            goToBedTime: goToBedTime,
            wakeTime: wakeTime,
            targetSleepDuration: totalSleepNeeded,
            timeInBedBuffer: timeInBedBuffer,
            reason: reason
        )
    }
}
