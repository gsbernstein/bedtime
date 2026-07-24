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
/// `requestAuthorization` succeeding only means the user chose
/// whether or not to provide permission. We use this flag to avoid re-prompting,
/// not as proof of access. Write/share permission (for debug) is handled separately by
/// `requireWriteAuthorization(for:)`, which can re-prompt when needed.
enum PermissionsRequestState: Equatable, CustomStringConvertible {
    case loading
    case shouldRequest
    case hasRequested

    var description: String {
        switch self {
        case .loading: return "loading"
        case .shouldRequest: return "shouldRequest"
        case .hasRequested: return "hasRequested"
        }
    }
}

@MainActor
class HealthKitManager: ObservableObject {
    private let healthStore = HKHealthStore()
    private let sourcePreferences: SourcePreferences
    private var rawSleepSamples: [HKCategorySample] = []
    private var cancellables = Set<AnyCancellable>()
    
    @Published private(set) var permissionsRequestState: PermissionsRequestState = .loading
    @Published private(set) var isRequestingAccess = false
    @Published var sleepSessions: [Date: [SleepSession]] = [:]
    @Published var errorMessage: String?
    @Published var availableSources: [HKSource]?
    
    init(sourcePreferences: SourcePreferences) {
        self.sourcePreferences = sourcePreferences
        
        sourcePreferences.objectWillChange
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.reprocessStoredSamples()
            }
            .store(in: &cancellables)

        Task { @MainActor in
            await self.bootstrap()
        }
    }
    
    private func bootstrap() async {
        DiagnosticLogger.log("HealthKit bootstrap — state=\(permissionsRequestState)")
        do {
            try checkHealthKitAvailability()
            DiagnosticLogger.log("HealthKit is available")
        } catch {
            errorMessage = error.localizedDescription
            permissionsRequestState = .shouldRequest
            DiagnosticLogger.log("HealthKit unavailable: \(error.localizedDescription)")
            return
        }

        logAuthorizationHints()

        // Try loading without prompting first — works when the user already granted access.
        await attemptSilentDataLoad()
    }

    /// Called from the "Grant Access" button. Always presents (or re-presents) the
    /// HealthKit authorization flow, then reloads data.
    func requestAccessFromUser() async {
        guard !isRequestingAccess else {
            DiagnosticLogger.log("requestAccessFromUser ignored — already in progress")
            return
        }

        isRequestingAccess = true
        errorMessage = nil
        DiagnosticLogger.log("User tapped Grant Access")

        defer { isRequestingAccess = false }

        do {
            try checkHealthKitAvailability()
            logAuthorizationHints()
            DiagnosticLogger.log("Calling requestAuthorization for sleep analysis…")
            try await healthStore.requestAuthorization(
                toShare: [],
                read: [HKCategoryType.sleepAnalysis]
            )
            DiagnosticLogger.log("requestAuthorization returned")
            permissionsRequestState = .hasRequested
            try await loadSleepData()
            logLoadResults(context: "after user grant")
            if rawSleepSamples.isEmpty {
                errorMessage = permissionDeniedOrNoDataMessage
            }
        } catch {
            permissionsRequestState = .shouldRequest
            errorMessage = error.localizedDescription
            DiagnosticLogger.log("requestAccessFromUser failed: \(error.localizedDescription)")
        }
    }

    func fetchSleepData() async throws {
        DiagnosticLogger.log("fetchSleepData — state=\(permissionsRequestState)")
        do {
            if permissionsRequestState != .hasRequested {
                try await healthStore.requestAuthorization(
                    toShare: [],
                    read: [HKCategoryType.sleepAnalysis]
                )
                permissionsRequestState = .hasRequested
                DiagnosticLogger.log("fetchSleepData authorized")
            }
            try await loadSleepData()
            logLoadResults(context: "fetchSleepData")
        } catch {
            errorMessage = error.localizedDescription
            DiagnosticLogger.log("fetchSleepData error: \(error.localizedDescription)")
            throw error
        }
    }

    func resumeLoadingIfNeeded() async {
        guard permissionsRequestState == .loading else { return }
        DiagnosticLogger.log("resumeLoadingIfNeeded")
        await bootstrap()
    }

    private func attemptSilentDataLoad() async {
        DiagnosticLogger.log("Attempting silent data load (no auth prompt)")
        do {
            try await loadSleepData()
            logLoadResults(context: "silent load")
            if rawSleepSamples.isEmpty {
                permissionsRequestState = .shouldRequest
                DiagnosticLogger.log("Silent load returned 0 samples — showing permission UI")
            } else {
                permissionsRequestState = .hasRequested
                DiagnosticLogger.log("Silent load succeeded — skipping permission UI")
            }
        } catch {
            permissionsRequestState = .shouldRequest
            errorMessage = error.localizedDescription
            DiagnosticLogger.log("Silent load error: \(error.localizedDescription)")
        }
    }

    private var permissionDeniedOrNoDataMessage: String {
        "No sleep data was returned from Apple Health. If you previously denied access, open Settings → Health → Data Access & Devices → Bedger and turn on Sleep."
    }

    private func logLoadResults(context: String) {
        let sourceNames = availableSources?.map(\.name).joined(separator: ", ") ?? "none"
        DiagnosticLogger.log(
            "\(context): rawSamples=\(rawSleepSamples.count), " +
            "groupedDays=\(sleepSessions.count), " +
            "sources=\(availableSources?.count ?? 0) [\(sourceNames)]"
        )
    }

    private func logAuthorizationHints() {
        let writeStatus = healthStore.authorizationStatus(for: HKCategoryType.sleepAnalysis)
        DiagnosticLogger.log(
            "Sleep analysis write/share authorizationStatus=\(writeStatus.rawValue) " +
            "(HealthKit does not expose read authorization status)"
        )
    }
    
    private func checkHealthKitAvailability() throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw NSError(domain: "HealthKitManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "HealthKit is not available on this device"])
        }
    }
    
    private func loadSleepData() async throws {
        try await fetchSleepDataForDisplay()
        await discoverAvailableSources()
    }
    
    private func fetchSleepDataForDisplay() async throws {
        let calendar = Calendar.current
        let endDate = Date()
        let today = calendar.startOfDay(for: endDate)
        guard let startDate = calendar.date(byAdding: .day, value: -Constants.sleepHistoryDays, to: today) else {
            throw NSError(domain: "HealthKitManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to calculate start date"])
        }

        DiagnosticLogger.log("Querying sleep samples from \(startDate) to \(endDate)")
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let query = HKSampleQuery(
                sampleType: HKCategoryType.sleepAnalysis,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { [weak self] _, samples, error in
                DispatchQueue.main.async {
                    if let error = error {
                        DiagnosticLogger.log("Display query error: \(error.localizedDescription)")
                        self?.errorMessage = "Failed to fetch sleep data: \(error.localizedDescription)"
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    guard let samples = samples as? [HKCategorySample] else {
                        DiagnosticLogger.log("Display query returned no samples (nil cast)")
                        self?.errorMessage = "No sleep data found"
                        continuation.resume()
                        return
                    }

                    DiagnosticLogger.log("Display query returned \(samples.count) raw samples")
                    self?.rawSleepSamples = samples
                    self?.processSleepSamples(samples)
                    continuation.resume()
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    private func discoverAvailableSources() async {
        DiagnosticLogger.log("Discovering sleep data sources…")
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
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
                    defer { continuation.resume() }
                    
                    if let error = error {
                        DiagnosticLogger.log("Source discovery error: \(error.localizedDescription)")
                        return
                    }
                    
                    guard let samples = samples as? [HKCategorySample] else {
                        DiagnosticLogger.log("Source discovery returned no samples")
                        return
                    }
                    
                    let uniqueSources = Dictionary(grouping: samples) { $0.sourceRevision.source.bundleIdentifier }
                        .compactMap { _, samples -> HKSource? in
                            samples.first?.sourceRevision.source
                        }
                        .sorted { $0.name < $1.name }
                    
                    self?.availableSources = uniqueSources
                    DiagnosticLogger.log("Discovered \(uniqueSources.count) sources: \(uniqueSources.map(\.name).joined(separator: ", "))")
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    private func reprocessStoredSamples() {
        processSleepSamples(rawSleepSamples)
    }
    
    private func processSleepSamples(_ samples: [HKCategorySample]) {
        let sessions = samples
            .filter {
                sourcePreferences.isSourceSelected($0.sourceRevision.source.bundleIdentifier)
            }
            .compactMap { SleepSession(sample: $0) }

        DiagnosticLogger.log(
            "Processed \(samples.count) samples → \(sessions.count) sleep sessions " +
            "(filtered by source preferences)"
        )
        
        self.sleepSessions = Dictionary(grouping: sessions) { $0.dateForGrouping }
    }
    
    #if DEBUG
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
    
    func generateFakeSleepData(nights: Int = 14, targetSleepHours: Double = 7.5) async throws {
        try await requireWriteAuthorization(for: HKCategoryType.sleepAnalysis)
        try await DebugDataGenerator.generateFakeSleepData(
            in: healthStore,
            nights: nights,
            targetSleepHours: targetSleepHours
        )
        try await fetchSleepData()
    }
    
    func clearFakeSleepData() async throws {
        try await requireWriteAuthorization(for: HKCategoryType.sleepAnalysis)
        try await DebugDataGenerator.clearFakeSleepData(in: healthStore)
        try await fetchSleepData()
    }
    #endif
}
