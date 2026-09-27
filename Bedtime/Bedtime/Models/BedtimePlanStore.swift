//
//  BedtimePlanStore.swift
//  Bedtime
//

import Foundation

/// A snapshot of the most recent recommendation.
///
/// Computing a recommendation needs HealthKit and the SwiftData preferences, which
/// is more than a background launch should take on. Saving the answer lets an
/// automation start tonight's Live Activity from whatever the app last worked out.
struct BedtimePlan: Codable {
    let recommendedBedtime: Date
    let wakeTime: Date
    let targetSleepHours: Double
    let durationStyle: DurationDisplayStyle
    let savedAt: Date
}

enum BedtimePlanStore {
    /// Plans older than this are treated as missing; the schedule they were built
    /// from has probably moved on.
    static let maximumAge: TimeInterval = .days(7)

    private static let key = "tonightsBedtimePlan"

    static func save(
        _ recommendation: BedtimeRecommendation,
        durationStyle: DurationDisplayStyle,
        now: Date = Date()
    ) {
        let plan = BedtimePlan(
            recommendedBedtime: recommendation.recommendedBedtime,
            wakeTime: recommendation.wakeTime,
            targetSleepHours: recommendation.targetSleepDuration,
            durationStyle: durationStyle,
            savedAt: now
        )
        guard let data = try? JSONEncoder().encode(plan) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func current(now: Date = Date()) -> BedtimePlan? {
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let plan = try? JSONDecoder().decode(BedtimePlan.self, from: data),
            now.timeIntervalSince(plan.savedAt) < maximumAge
        else {
            return nil
        }
        return plan
    }
}

extension BedtimeRecommendation {
    init(plan: BedtimePlan) {
        self.init(
            recommendedBedtime: plan.recommendedBedtime,
            wakeTime: plan.wakeTime,
            targetSleepDuration: plan.targetSleepHours,
            reason: nil
        )
    }
}
