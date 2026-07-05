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
            return UserPreferences.nominalWindowHours(earliestBedtime: earliestBedtime, wakeTime: wakeTime, calendar: calendar)
        }

        return wake.timeIntervalSince(bed) / 3600.0
    }

    static func generateBedtimeRecommendation(
        wakeTime: Date,
        earliestBedtime: Date,
        sleepGoal: Double,
        sleepBank: SleepBank,
        referenceDate: Date = Date()
    ) -> BedtimeRecommendation {
        let calendar = Calendar.current
        let maxSleepHours = maxSleepHours(
            earliestBedtime: earliestBedtime,
            wakeTime: wakeTime,
            referenceDate: referenceDate,
            calendar: calendar
        )

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
        } else if sleepBank.isInDebt {
            let debtHours = sleepBank.debtHours
            reason = "You need \(String(format: "%.1f", totalSleepNeeded)) hours tonight to catch up on your \(String(format: "%.1f", debtHours))-hour sleep debt."
        } else if totalSleepNeeded < sleepGoal {
            totalSleepNeeded = sleepGoal
            reason = "You're ahead of the game! Aim for at least \(String(format: "%.1f", sleepGoal)) hours tonight."
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
