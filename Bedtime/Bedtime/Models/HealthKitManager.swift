//
//  HealthKitManager.swift
//  Bedtime
//
//  Created by Greg on 10/4/25.
//

import Foundation
import HealthKit
import Combine

@MainActor
class HealthKitManager: ObservableObject {
    private let healthStore = HKHealthStore()
    @Published var isAuthorized = false
    @Published var sleepSessions: [Date: [SleepSession]] = [:]
    @Published var errorMessage: String?
        
    init() {
        do {
            try checkHealthKitAvailability()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func checkHealthKitAvailability() throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw NSError(domain: "HealthKitManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "HealthKit is not available on this device"])
        }
    }
    
    func requestAuthorization() async throws {
        try checkHealthKitAvailability()
        
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        
        do {
            try await healthStore.requestAuthorization(toShare: [], read: [sleepType])
            isAuthorized = true
            try await fetchSleepData()
        } catch {
            throw NSError(domain: "HealthKitManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to request HealthKit authorization: \(error.localizedDescription)"])
        }
    }
    
    func fetchSleepData() async throws  {
        if !isAuthorized {
            try await requestAuthorization()
        }
        
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -30, to: endDate) else {
            throw NSError(domain: "HealthKitManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to calculate start date"])
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        let query = HKSampleQuery(
            sampleType: sleepType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
        ) { [weak self] _, samples, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.errorMessage = "Failed to fetch sleep data: \(error.localizedDescription)"
                    return
                }
                
                guard let samples = samples as? [HKCategorySample] else {
                    self?.errorMessage = "No sleep data found"
                    return
                }
                
                self?.processSleepSamples(samples)
            }
        }
        
        healthStore.execute(query)
    }
    
    private func processSleepSamples(_ samples: [HKCategorySample]) {        
        // Sort by start date (most recent first)
        let sessions = samples
            .compactMap { SleepSession(sample: $0) }
        
        self.sleepSessions = Dictionary(grouping: sessions) { $0.dateForGrouping }
    }
    
    func calculateSleepBank(goalHours: Double, recentDays: Int) -> SleepBank {
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
    
    func generateBedtimeRecommendation(
        wakeTime: Date,
        sleepGoal: Double,
        sleepBank: SleepBank
    ) -> BedtimeRecommendation {
        let calendar = Calendar.current
        
        // Calculate how much sleep we need tonight
        let baseSleepNeeded = sleepGoal
        
        // If we're in debt, we need extra sleep to catch up
        let extraSleepNeeded = max(0, -sleepBank.currentBalance)
        let totalSleepNeeded = baseSleepNeeded + extraSleepNeeded
        
        // Calculate recommended bedtime
        let recommendedBedtime = calendar.date(byAdding: .hour, value: -Int(totalSleepNeeded), to: wakeTime) ?? wakeTime
        
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
