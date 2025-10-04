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
    @Published var sleepSessions: [SleepSession] = []
    @Published var errorMessage: String?
    
    init() {
        checkHealthKitAvailability()
    }
    
    private func checkHealthKitAvailability() {
        guard HKHealthStore.isHealthDataAvailable() else {
            errorMessage = "HealthKit is not available on this device"
            return
        }
    }
    
    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            errorMessage = "HealthKit is not available on this device"
            return
        }
        
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        
        do {
            try await healthStore.requestAuthorization(toShare: [], read: [sleepType])
            isAuthorized = true
            await fetchSleepData()
        } catch {
            errorMessage = "Failed to request HealthKit authorization: \(error.localizedDescription)"
        }
    }
    
    func fetchSleepData() async {
        guard isAuthorized else { return }
        
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -30, to: endDate) ?? endDate
        
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
        var sessions: [SleepSession] = []
        
        for sample in samples {
            // Only process "inBed" sleep analysis samples for total sleep time
            if sample.value == HKCategoryValueSleepAnalysis.inBed.rawValue {
                let session = SleepSession(
                    startDate: sample.startDate,
                    endDate: sample.endDate
                )
                sessions.append(session)
            }
        }
        
        // Sort by start date (most recent first)
        self.sleepSessions = sessions.sorted { $0.startDate > $1.startDate }
    }
    
    func calculateSleepBank(goalHours: Double, recentDays: Int = 7) -> SleepBank {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -recentDays, to: endDate) ?? endDate
        
        // Filter sessions from the last N days
        let recentSessions = sleepSessions.filter { session in
            session.startDate >= startDate && session.startDate <= endDate
        }
        
        // Calculate total sleep hours in the period
        let totalSleepHours = recentSessions.reduce(0) { $0 + $1.durationInHours }
        
        // Calculate expected sleep hours (goal * number of days)
        let expectedSleepHours = goalHours * Double(recentDays)
        
        // Calculate current balance (actual - expected)
        let currentBalance = totalSleepHours - expectedSleepHours
        
        return SleepBank(
            currentBalance: currentBalance,
            goalHours: goalHours,
            recentSessions: recentSessions
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
