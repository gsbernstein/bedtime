//
//  HealthKitManager.swift
//  Bedtime
//
//  Created by Greg on 10/4/25.
//

import Foundation
import HealthKit
import Combine

/// HealthKit intentionally does **not** report whether read access was granted —
/// `requestAuthorization` succeeding only means the sheet was dismissed. There is
/// no separate "already has permission" case; returning users reach `.hasRequested`
/// when the silent re-check completes without showing the sheet.
///
/// HealthKit intentionally does **not** report whether read access was granted —
/// `requestAuthorization` succeeding only means the user chose
/// whether or not to provide permission. We use this flag to avoid re-prompting,
/// not as proof of access. Write/share permission (for debug) is handled separately by
/// `requireWriteAuthorization(for:)`, which can re-prompt when needed.
enum PermissionsRequestState: Equatable {
    case loading
    case shouldRequest
    case hasRequested
}

@MainActor
class HealthKitManager: ObservableObject {
    private let healthStore = HKHealthStore()
    private let sourcePreferences: SourcePreferences
    private var rawSleepSamples: [HKCategorySample] = []
    private var cancellables = Set<AnyCancellable>()
    /// Long-lived query that re-loads data whenever HealthKit sleep samples change.
    /// Registered once, after the first successful fetch; torn down in `deinit`.
    private var observerQuery: HKObserverQuery?
    
    @Published private(set) var permissionsRequestState: PermissionsRequestState = .loading
    @Published var sleepSessions: [Date: [SleepSession]] = [:]
    /// All sessions regardless of source preferences — used for per-source comparison UI.
    @Published private(set) var allSleepSessions: [Date: [SleepSession]] = [:]
    @Published var errorMessage: String?
    @Published var availableSources: [HKSource]?
    
    init(sourcePreferences: SourcePreferences) {
        self.sourcePreferences = sourcePreferences
        
        do {
            try checkHealthKitAvailability()
        } catch {
            errorMessage = error.localizedDescription
            permissionsRequestState = .shouldRequest
        }
        
        // Listen for preference changes to re-filter data immediately
        sourcePreferences.objectWillChange
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.reprocessStoredSamples()
            }
            .store(in: &cancellables)
    }
    
    deinit {
        if let observerQuery {
            healthStore.stop(observerQuery)
        }
    }

    private func checkHealthKitAvailability() throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw NSError(domain: "HealthKitManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "HealthKit is not available on this device"])
        }
    }
    
    /// Presents the HealthKit authorization sheet for read access if we haven't
    /// already. No-op on subsequent calls — see `PermissionsRequestState` for
    /// why we can't verify if read access was actually granted.
    func requestAuthorization() async throws {
        guard permissionsRequestState != .hasRequested else { return }
        
        try checkHealthKitAvailability()
        
        do {
            try await healthStore.requestAuthorization(
                toShare: [],
                read: [HKCategoryType.sleepAnalysis]
            )
            permissionsRequestState = .hasRequested
        } catch {
            throw NSError(domain: "HealthKitManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to request HealthKit authorization: \(error.localizedDescription)"])
        }
    }
    
    func fetchSleepData() async throws {
        defer {
            if permissionsRequestState == .loading {
                permissionsRequestState = .shouldRequest
            }
        }
        do {
            try await requestAuthorization()
            try await loadSleepData()
            startObservingSleepChanges()
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    private func loadSleepData() async throws {
        // Source discovery scans all of history, so start it alongside the display
        // fetch instead of after it. Only the display fetch is load-bearing.
        async let discoveredSources = discoverAvailableSources()

        let predicate = try displayWindowPredicate()
        let samples = try await fetchSleepSamples(matching: predicate)
        rawSleepSamples = samples
        processSleepSamples(samples)

        if let discoveredSources = await discoveredSources {
            availableSources = discoveredSources
        }
    }
    
    /// Registers an `HKObserverQuery` so the app re-loads sleep data whenever
    /// HealthKit gains new samples — no manual pull-to-refresh needed — and enables
    /// background delivery so those updates arrive even while the app is suspended.
    /// Idempotent: safe to call from every `fetchSleepData()`; only registers once.
    private func startObservingSleepChanges() {
        guard observerQuery == nil else { return }

        let query = HKObserverQuery(
            sampleType: HKCategoryType.sleepAnalysis,
            predicate: nil
        ) { [weak self] _, completionHandler, error in
            // HealthKit invokes this handler off the main thread, so hop to the main
            // actor to touch `errorMessage`/`loadSleepData`. Always call
            // `completionHandler()` so HealthKit releases its background assertion and
            // stops retrying the notification.
            Task { @MainActor in
                defer { completionHandler() }
                guard let self else { return }
                if let error {
                    self.errorMessage = "Sleep data observer error: \(error.localizedDescription)"
                    return
                }
                do {
                    try await self.loadSleepData()
                } catch {
                    self.errorMessage = "Failed to refresh sleep data: \(error.localizedDescription)"
                }
            }
        }

        observerQuery = query
        healthStore.execute(query)
        enableBackgroundDelivery()
    }

    /// Asks HealthKit to wake the app (subject to system throttling) whenever new
    /// sleep samples land, so the observer query fires while backgrounded. Requires
    /// the `com.apple.developer.healthkit.background-delivery` entitlement.
    private func enableBackgroundDelivery() {
        healthStore.enableBackgroundDelivery(
            for: HKCategoryType.sleepAnalysis,
            frequency: .immediate
        ) { [weak self] _, error in
            guard let error else { return }
            let message = "Failed to enable background updates: \(error.localizedDescription)"
            Task { @MainActor [weak self] in
                self?.errorMessage = message
            }
        }
    }
    
    /// Predicate covering the window the UI can display.
    private func displayWindowPredicate() throws -> NSPredicate {
        let calendar = Calendar.current
        let endDate = Date()
        let today = calendar.startOfDay(for: endDate)
        // Fetch one extra day before the UI range: grouping (midpoint + 6h) can assign
        // sessions that start the previous evening to the oldest displayed day, including
        // short blocks (e.g. 9–11pm) as well as overnight sleep.
        guard let startDate = calendar.date(byAdding: .day, value: -Constants.sleepHistoryDays, to: today) else {
            throw NSError(domain: "HealthKitManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to calculate start date"])
        }
        
        return HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
    }
    
    /// Every source that has ever written sleep data, or `nil` when discovery failed.
    ///
    /// Best-effort by design: the app still works without the source list (it only
    /// drives the Settings filter), so a failure here leaves any previously
    /// discovered sources in place rather than failing the surrounding refresh.
    private func discoverAvailableSources() async -> [HKSource]? {
        // Query all of history so sources that stopped writing recently still appear.
        let predicate = HKQuery.predicateForSamples(
            withStart: Date.distantPast,
            end: Date(),
            options: .strictStartDate
        )
        
        do {
            let samples = try await fetchSleepSamples(matching: predicate)
            var seenBundleIDs = Set<String>()
            return samples
                .map(\.sourceRevision.source)
                .filter { seenBundleIDs.insert($0.bundleIdentifier).inserted }
                .sorted { $0.name < $1.name }
        } catch {
            errorMessage = "Failed to discover sleep sources: \(error.localizedDescription)"
            return nil
        }
    }
    
    /// Bridges `HKSampleQuery`'s completion handler to async/await so callers actually
    /// await the samples — and see query errors — instead of resuming as soon as the
    /// query has been handed to HealthKit.
    private func fetchSleepSamples(matching predicate: NSPredicate) async throws -> [HKCategorySample] {
        let healthStore = self.healthStore
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKCategoryType.sleepAnalysis,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                
                continuation.resume(returning: samples?.compactMap { $0 as? HKCategorySample } ?? [])
            }
            
            healthStore.execute(query)
        }
    }
    
    private func reprocessStoredSamples() {
        processSleepSamples(rawSleepSamples)
    }
    
    private func processSleepSamples(_ samples: [HKCategorySample]) {
        let allSessions = samples.compactMap { SleepSession(sample: $0) }
        self.allSleepSessions = Dictionary(grouping: allSessions) { $0.dateForGrouping }
        
        let includedSessions = allSessions.filter {
            sourcePreferences.isSourceSelected($0.source.source.bundleIdentifier)
        }
        self.sleepSessions = Dictionary(grouping: includedSessions) { $0.dateForGrouping }
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
            permissionsRequestState = .hasRequested
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
