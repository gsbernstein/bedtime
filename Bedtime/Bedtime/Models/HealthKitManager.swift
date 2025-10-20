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
    @Published var inBedSessions: [Date: [SleepSession]] = [:]
    @Published var daySleepData: [Date: DaySleepData] = [:]
    @Published var errorMessage: String?
    private var observerQuery: HKObserverQuery?
        
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
            setupObserverQuery()
            enableBackgroundDelivery()
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
        // Separate "In Bed" from "Asleep" sessions
        let allSessions = samples.compactMap { SleepSession(sample: $0) }
        
        let asleepSessions = allSessions.filter { session in
            HKCategoryValueSleepAnalysis.allAsleepValues.contains(session.sleepType)
        }
        
        let inBedSessions = allSessions.filter { session in
            session.sleepType == .inBed
        }
        
        self.sleepSessions = Dictionary(grouping: asleepSessions) { $0.dateForGrouping }
        self.inBedSessions = Dictionary(grouping: inBedSessions) { $0.dateForGrouping }
        
        // Create DaySleepData for each day
        var newDaySleepData: [Date: DaySleepData] = [:]
        let allDays = Set(self.sleepSessions.keys).union(Set(self.inBedSessions.keys))
        
        for day in allDays {
            let dayAsleepSessions = self.sleepSessions[day] ?? []
            let dayInBedSessions = self.inBedSessions[day] ?? []
            let allDaySessions = dayAsleepSessions + dayInBedSessions
            newDaySleepData[day] = DaySleepData(date: day, allSessions: allDaySessions)
        }
        
        self.daySleepData = newDaySleepData
    }
    
    private func setupObserverQuery() {
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        
        observerQuery = HKObserverQuery(sampleType: sleepType, predicate: nil) { [weak self] _, completionHandler, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.errorMessage = "Observer query error: \(error.localizedDescription)"
                    completionHandler()
                    return
                }
                
                Task {
                    do {
                        try await self?.fetchSleepData()
                    } catch {
                        self?.errorMessage = "Failed to fetch updated sleep data: \(error.localizedDescription)"
                    }
                    completionHandler()
                }
            }
        }
        
        if let query = observerQuery {
            healthStore.execute(query)
        }
    }
    
    private func enableBackgroundDelivery() {
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        
        healthStore.enableBackgroundDelivery(for: sleepType, frequency: .immediate) { [weak self] success, error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.errorMessage = "Failed to enable background delivery: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func calculateTimeInBedBuffer() -> Double {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -14, to: endDate) ?? endDate
        
        var totalBuffer: Double = 0
        var validDays = 0
        
        for day in stride(from: startDate, to: endDate, by: 86400) {
            let dayStart = calendar.startOfDay(for: day)
            
            if let dayAsleepSessions = sleepSessions[dayStart],
               let dayInBedSessions = inBedSessions[dayStart] {
                
                // Calculate total asleep time for the day
                let totalAsleepTime = dayAsleepSessions.reduce(0) { $0 + $1.durationInHours }
                
                // Calculate total in bed time for the day
                let totalInBedTime = dayInBedSessions.reduce(0) { $0 + $1.durationInHours }
                
                if totalInBedTime > 0 && totalAsleepTime > 0 {
                    let dayBuffer = totalInBedTime - totalAsleepTime
                    totalBuffer += dayBuffer
                    validDays += 1
                }
            }
        }
        
        // Return average buffer, default to 30 minutes if no data
        return validDays > 0 ? totalBuffer / Double(validDays) : 0.5
    }
    
    deinit {
        if let query = observerQuery {
            healthStore.stop(query)
        }
    }
}
