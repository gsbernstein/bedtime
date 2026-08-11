//
//  ViewModel.swift
//  Bedtime
//
//  Created by Greg on 10/17/25.
//

import Foundation
import HealthKit

class ViewModel {
    private struct SourceAppDestination {
        let name: String
        let url: URL
    }

    /// HealthKit identifies writers by bundle ID. Only add destinations that the
    /// source app publicly supports so the no-data state never offers a dead link.
    private static let sourceAppDestinations: [String: SourceAppDestination] = [
        "com.ouraring.oura": SourceAppDestination(
            name: "Oura",
            url: URL(string: "https://cloud.ouraring.com/app/v1/home")!
        )
    ]

    static func recentSourceAppLinks(
        sleepSessions: [Date: [SleepSession]],
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> [SleepSourceAppLink] {
        let cutoff = calendar.date(
            byAdding: .day,
            value: -Constants.recentSourceAppLookbackDays,
            to: referenceDate
        ) ?? referenceDate

        var linksByBundleID: [String: SleepSourceAppLink] = [:]
        let recentSessions = sleepSessions.values
            .flatMap { $0 }
            .filter { $0.endDate >= cutoff && $0.endDate <= referenceDate }
            .sorted { $0.endDate > $1.endDate }

        for session in recentSessions {
            let bundleID = session.source.source.bundleIdentifier.lowercased()
            guard
                linksByBundleID[bundleID] == nil,
                let app = sourceAppDestinations[bundleID]
            else {
                continue
            }

            linksByBundleID[bundleID] = SleepSourceAppLink(
                id: bundleID,
                name: app.name,
                destination: app.url,
                lastDataDate: session.endDate
            )
        }

        return linksByBundleID.values.sorted { $0.lastDataDate > $1.lastDataDate }
    }

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
        
        let recentNights: [NightSummary] = (0..<recentDays).reversed().map { offset in
            let referenceDay = calendar.date(byAdding: .day, value: -offset, to: endDate) ?? endDate
            let day = calendar.startOfDay(for: referenceDay)
            let sessions = sleepSessions[day] ?? []
            let total = sessions.map(\.durationInHours).reduce(0, +)
            return NightSummary(date: day, totalHours: total, hasData: !sessions.isEmpty)
        }
        
        return SleepBank(
            currentBalance: currentBalance,
            goalHours: goalHours,
            averageHours: averageHours,
            recentNights: recentNights
        )
    }
    
    static func generateBedtimeRecommendation(
        wakeTime: Date,
        earliestBedtime: Date,
        sleepGoal: Double,
        sleepBank: SleepBank,
        referenceDate: Date = Date(),
        durationStyle: DurationDisplayStyle = .hoursAndMinutes
    ) -> BedtimeRecommendation {
        let calendar = Calendar.current
        let maxSleepHours = SleepWindow.maxSleepHours(
            earliestBedtime: earliestBedtime,
            wakeTime: wakeTime,
            referenceDate: referenceDate,
            calendar: calendar
        )

        // Calculate how much sleep we need tonight
        // If we're in debt, we need extra sleep to catch up
        var totalSleepNeeded = sleepGoal - sleepBank.currentBalance
        
        // Generate reason
        let reason: String?
        if sleepBank.averageHours == nil {
            reason = "No data so far, just aim for your goal"
        } else if totalSleepNeeded > maxSleepHours {
            totalSleepNeeded = maxSleepHours
            reason = nil
        } else if sleepBank.isInDebt {
            let debtHours = sleepBank.debtHours
            let needed = TimeFormatter.formatHours(totalSleepNeeded, style: durationStyle)
            let debt = TimeFormatter.formatHours(debtHours, style: durationStyle)
            reason = "You need \(needed) tonight to catch up on your \(debt) sleep debt."
        } else {
            totalSleepNeeded = sleepGoal
            let goal = TimeFormatter.formatHours(
                sleepGoal,
                style: durationStyle,
                maxFractionDigits: 2
            )
            reason = "You're ahead of the game! Aim for at least \(goal) tonight."
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
