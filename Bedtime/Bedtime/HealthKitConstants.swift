//
//  HealthKitConstants.swift
//  Bedtime
//

import HealthKit

extension HKCategoryType {
    /// The built-in sleep analysis type. Always available on HealthKit-capable devices.
    static let sleepAnalysis = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
}
