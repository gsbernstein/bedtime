//
//  SleepData.swift
//  Bedtime
//
//  Created by Greg on 10/4/25.
//

import Foundation
import HealthKit

let asleepTypes: Set<HKCategoryValueSleepAnalysis> = [.asleepUnspecified, .asleepCore, .asleepDeep, .asleepREM]

struct SleepSession {
    let startDate: Date
    let endDate: Date
    let duration: TimeInterval
    let sleepType: HKCategoryValueSleepAnalysis
    
    init(startDate: Date, endDate: Date, sleepType: HKCategoryValueSleepAnalysis) {
        self.startDate = startDate
        self.endDate = endDate
        self.duration = endDate.timeIntervalSince(startDate)
        self.sleepType = sleepType
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

extension SleepSession {
    init?(sample: HKCategorySample) {
        guard let sleepType = HKCategoryValueSleepAnalysis(rawValue: sample.value) else { return nil }
        guard asleepTypes.contains(sleepType) else { return nil }
        self.init(startDate: sample.startDate,
            endDate: sample.endDate,
            sleepType: sleepType)
    }
}

extension HKCategoryValueSleepAnalysis {
    
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
    
    var color: String {
        switch self {
        case .asleepDeep:        return "blue"
        case .asleepREM:         return "purple"
        case .asleepCore:        return "indigo"
        case .awake:             return "orange"
        case .inBed:             return "gray"
        case .asleepUnspecified: return "secondary"
        @unknown default:        return "secondary"
        }
    }
}

struct SleepBank {
    let currentBalance: Double // in hours
    let goalHours: Double
    
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
