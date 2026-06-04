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
    private var rawSleepSamples: [HKCategorySample] = []
    private var cancellables = Set<AnyCancellable>()
    
    /// True once we've presented the HealthKit authorization sheet.
    ///
    /// HealthKit intentionally does **not** report whether read access was
    /// granted — `requestAuthorization` succeeding only means the sheet was
    /// dismissed. We use this flag to avoid re-prompting for read-only access,
    /// not as proof of access. Write/share permission is handled separately by
    /// `requireWriteAuthorization(for:)`, which can re-prompt when needed.
    @Published private(set) var hasRequestedAuthorization = false
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
        
        // Listen for preference changes to re-filter data immediately
        sourcePreferences.objectWillChange
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.reprocessStoredSamples()
            }
            .store(in: &cancellables)
    }
    
    private func checkHealthKitAvailability() throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw NSError(domain: "HealthKitManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "HealthKit is not available on this device"])
        }
    }
    
    /// Presents the HealthKit authorization sheet for read access if we haven't
    /// already. No-op on subsequent calls — see `hasRequestedAuthorization` for
    /// why we can't verify read access was actually granted.
    func requestAuthorization() async throws {
        guard !hasRequestedAuthorization else { return }
        
        try checkHealthKitAvailability()
        
        do {
            try await healthStore.requestAuthorization(
                toShare: [],
                read: [HKCategoryType.sleepAnalysis]
            )
            hasRequestedAuthorization = true
        } catch {
            throw NSError(domain: "HealthKitManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to request HealthKit authorization: \(error.localizedDescription)"])
        }
    }
    
    func fetchSleepData() async throws {
        try await requestAuthorization()
        try await loadSleepData()
    }
    
    private func loadSleepData() async throws {
        _ = try await [fetchSleepDataForDisplay(), discoverAvailableSources()]
    }
    
    private func fetchSleepDataForDisplay() async throws {
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -Constants.sleepHistoryDays, to: endDate) else {
            throw NSError(domain: "HealthKitManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to calculate start date"])
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        let query = HKSampleQuery(
            sampleType: HKCategoryType.sleepAnalysis,
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
                
                self?.rawSleepSamples = samples
                self?.processSleepSamples(samples)
            }
        }
        
        healthStore.execute(query)
    }
    
    private func discoverAvailableSources() async throws {
        // Query all time to discover all sources that have ever provided sleep data
        // Use a very old start date to get all historical data
        let predicate = HKQuery.predicateForSamples(
            withStart: Date.distantPast,
            end: Date(),
            options: .strictStartDate
        )
        
        let query = HKSampleQuery(
            sampleType: HKCategoryType.sleepAnalysis,
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
    
    private func reprocessStoredSamples() {
        processSleepSamples(rawSleepSamples)
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
    
    #if DEBUG
    /// Prompts for write access to `type` (plus read access to sleep analysis),
    /// then verifies share authorization succeeded. Unlike read access, HealthKit
    /// does report write/share status via `authorizationStatus(for:)`.
    ///
    /// Re-prompts when needed — e.g. after a read-only authorization — so callers
    /// don't need to invoke `requestAuthorization()` first.
    func requireWriteAuthorization(for type: HKSampleType) async throws {
        try checkHealthKitAvailability()
        
        do {
            try await healthStore.requestAuthorization(
                toShare: [type],
                read: [HKCategoryType.sleepAnalysis]
            )
            hasRequestedAuthorization = true
        } catch {
            throw NSError(domain: "HealthKitManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to request HealthKit authorization: \(error.localizedDescription)"])
        }
        
        switch healthStore.authorizationStatus(for: type) {
        case .sharingAuthorized:
            return
        case .sharingDenied:
            throw NSError(
                domain: "HealthKitManager",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "HealthKit write access was denied. Enable sharing in Settings → Health → Data Access & Devices."]
            )
        case .notDetermined:
            throw NSError(
                domain: "HealthKitManager",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: "HealthKit write access has not been granted yet."]
            )
        @unknown default:
            throw NSError(
                domain: "HealthKitManager",
                code: 5,
                userInfo: [NSLocalizedDescriptionKey: "Unknown HealthKit authorization status."]
            )
        }
    }
    
    /// Writes a batch of fake sleep nights into HealthKit and refreshes the
    /// in-memory cache so the UI updates immediately. Debug builds only.
    func generateFakeSleepData(nights: Int = 14, targetSleepHours: Double = 7.5) async throws {
        try await requireWriteAuthorization(for: HKCategoryType.sleepAnalysis)
        try await DebugDataGenerator.generateFakeSleepData(
            in: healthStore,
            nights: nights,
            targetSleepHours: targetSleepHours
        )
        try await fetchSleepData()
    }
    
    /// Deletes every sample previously written by this app's debug utilities
    /// (real samples are untouched).
    func clearFakeSleepData() async throws {
        try await requireWriteAuthorization(for: HKCategoryType.sleepAnalysis)
        try await DebugDataGenerator.clearFakeSleepData(in: healthStore)
        try await fetchSleepData()
    }
    #endif
}
