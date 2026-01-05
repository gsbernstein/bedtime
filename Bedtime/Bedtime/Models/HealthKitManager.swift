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
    private let sourcePreferences: SourcePreferences
    @Published var isAuthorized = false
    @Published var sleepSessions: [Date: [SleepSession]] = [:]
    @Published var errorMessage: String?
    @Published var availableSources: [HKSource]?
    
    init(sourcePreferences: SourcePreferences) {
        self.sourcePreferences = sourcePreferences
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
        
        _ = try await [fetchSleepDataForDisplay(), discoverAvailableSources()]
    }
    
    private func fetchSleepDataForDisplay() async throws {
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
    
    private func discoverAvailableSources() async throws {
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        
        // Query all time to discover all sources that have ever provided sleep data
        // Use a very old start date to get all historical data
        let predicate = HKQuery.predicateForSamples(
            withStart: Date.distantPast,
            end: Date(),
            options: .strictStartDate
        )
        
        let query = HKSampleQuery(
            sampleType: sleepType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
        ) { [weak self] _, samples, error in
            DispatchQueue.main.async {
                if let error = error {
                    // Don't fail if we can't discover sources, just log it
                    print("Failed to discover sources: \(error.localizedDescription)")
                    return
                }
                
                guard let samples = samples as? [HKCategorySample] else {
                    return
                }
                
                // Extract unique sources from all samples
                let uniqueSources = Dictionary(grouping: samples) { $0.sourceRevision.source.bundleIdentifier }
                    .compactMap { _, samples -> HKSource? in
                        samples.first?.sourceRevision.source
                    }
                    .sorted { $0.name < $1.name }
                
                self?.availableSources = uniqueSources
            }
        }
        
        healthStore.execute(query)
    }
    
    private func processSleepSamples(_ samples: [HKCategorySample]) {        
        // Filter based on user's source preferences
        let sessions = samples
            .filter {
                sourcePreferences.isSourceSelected($0.sourceRevision.source.bundleIdentifier)
            }
            .compactMap { SleepSession(sample: $0) }
        
        self.sleepSessions = Dictionary(grouping: sessions) { $0.dateForGrouping }
    }
}
