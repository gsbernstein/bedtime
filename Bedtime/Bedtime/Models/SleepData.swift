//
//  SleepData.swift
//  Bedtime
//
//  Created by Greg on 10/4/25.
//

import Foundation
import HealthKit
import SwiftUI

struct SleepSession {
    let startDate: Date
    let endDate: Date
    let duration: TimeInterval
    let sleepType: HKCategoryValueSleepAnalysis
    let source: HKSourceRevision
    
    init(startDate: Date, endDate: Date, sleepType: HKCategoryValueSleepAnalysis, source: HKSourceRevision) {
        self.startDate = startDate
        self.endDate = endDate
        self.duration = endDate.timeIntervalSince(startDate)
        self.sleepType = sleepType
        self.source = source
    }
    
    var durationInHours: Double {
        return duration / 3600.0
    }
    
    var dateForGrouping: Date {
        let midpoint = startDate.addingTimeInterval(duration / 2)
        let shiftedMidpoint = midpoint.addingTimeInterval(TimeInterval(6 * 60 * 60))
        return Calendar.current.startOfDay(for: shiftedMidpoint)
    }
}

struct SleepSourceAppLink: Identifiable {
    let id: String
    let name: String
    let destination: URL
    let lastDataDate: Date
}

extension SleepSession {
    init?(sample: HKCategorySample) {
        guard let sleepType = HKCategoryValueSleepAnalysis(rawValue: sample.value) else { return nil }
        guard HKCategoryValueSleepAnalysis.allAsleepValues.contains(sleepType) else { return nil }
        self.init(startDate: sample.startDate,
                  endDate: sample.endDate,
                  sleepType: sleepType,
                  source: sample.sourceRevision)
    }
}

extension HKCategoryValueSleepAnalysis {
    
    static let allAsleepValues: [HKCategoryValueSleepAnalysis] = [
        .asleepUnspecified,
        .asleepCore,
        .asleepDeep,
        .asleepREM,
    ]
    
    var displayName: String {
        switch self {
        case .asleepUnspecified: return "Asleep"
        case .asleepCore:        return "Core"
        case .asleepDeep:        return "Deep"
        case .asleepREM:         return "REM"
        case .awake:             return "Awake"
        case .inBed:             return "In Bed"
        @unknown default:        return "Unknown"
        }
    }
    
    var icon: String {
        switch self {
        case .asleepDeep:        return "moon.zzz.fill"
        case .asleepREM:         return "brain.head.profile"
        case .asleepCore:        return "moon.fill"
        case .awake:             return "eye.fill"
        case .inBed:             return "bed.double.fill"
        case .asleepUnspecified: return "moon.stars.fill"
        @unknown default:        return "questionmark.circle.fill"
        }
    }
    
    func color(for theme: AppTheme) -> Color {
        switch self {
        case .asleepDeep:        return AppColors.sleepDeep(theme)
        case .asleepREM:         return AppColors.sleepREM(theme)
        case .asleepCore:        return AppColors.sleepCore(theme)
        case .awake:             return AppColors.sleepAwake(theme)
        case .inBed:             return AppColors.sleepInBed(theme)
        case .asleepUnspecified: return Color.secondary
        @unknown default:        return Color.secondary
        }
    }
}

struct NightSummary: Identifiable, Equatable {
    let date: Date
    let totalHours: Double?

    var id: Date { date }
    var hasData: Bool { totalHours != nil }
}

struct BalanceDayImpact: Identifiable {
    let date: Date
    let priorBalance: Double
    let impact: Double
    
    var id: Date { date }
    var newBalance: Double { priorBalance + impact }
    var isGain: Bool { impact > 0 }
}

struct SleepBank: Equatable {
    let currentBalance: Double // in hours
    let goalHours: Double
    let averageHours: Double?
    let recentNights: [NightSummary]
    
    var isInDebt: Bool {
        return currentBalance < 0
    }
    
    func statusColor(for theme: AppTheme) -> Color {
        guard averageHours != nil else { return .secondary }
        return Constants.sleepGoalColor(difference: currentBalance, graceColor: .primary, theme: theme)
    }

    var debtHours: Double {
        return max(0, -currentBalance)
    }
    
    var creditHours: Double {
        return max(0, currentBalance)
    }
    
    /// Describes what the balance figures cover: the lookback window they were measured
    /// over, or a nudge to start tracking when the window holds no nights to measure.
    func statusDescription(days: Int) -> String {
        guard averageHours != nil else {
            return "Track some sleep in Apple Health to get insights."
        }
        return "Across the last \(days) days"
    }
    
    var balanceImpacts: [BalanceDayImpact] {
        var runningBalance = 0.0
        return recentNights.compactMap { night in
            guard let totalHours = night.totalHours else { return nil }
            let priorBalance = runningBalance
            let impact = totalHours - goalHours
            runningBalance += impact
            return BalanceDayImpact(date: night.date, priorBalance: priorBalance, impact: impact)
        }
    }
    
}

struct BedtimeRecommendation {
    let recommendedBedtime: Date
    let wakeTime: Date
    let targetSleepDuration: Double // in hours
    let reason: String?
}
