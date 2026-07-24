//
//  SettingsView.swift
//  Bedtime
//
//  Created by Greg on 10/4/25.
//

import SwiftUI
import Combine
import HealthKit
import UIKit

struct SettingsView: View {
    @Bindable var preferences: UserPreferences
    @ObservedObject var sourcePreferences: SourcePreferences
    var healthKitManager: HealthKitManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var sleepBankDaysBinding: Binding<Double> {
        Binding(
            get: { Double(preferences.sleepBankDays) },
            set: { preferences.sleepBankDays = Int($0.rounded()) }
        )
    }

    #if DEBUG
    @State private var debugIsWorking = false
    @State private var debugMessage: String?
    #endif

    @State private var showingShareSheet = false
    @State private var copiedLogsConfirmation = false
    @State private var diagnosticsMessage: String?
    @State private var isRetryingHealthKit = false
    @ObservedObject private var diagnosticLogger = DiagnosticLogger.shared

    private var earliestBedtimeBinding: Binding<Date> {
        $preferences.earliestReasonableBedtime
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Sleep Goal") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Target Sleep Duration")
                            Spacer()
                            Text(TimeFormatter.formatDuration(preferences.sleepGoalHours*60*60))
                                .foregroundStyle(.secondary)
                        }
                        
                        Slider(value: $preferences.sleepGoalHours, in: 6...12, step: 0.25) {
                            EmptyView()
                        }
                            .accentColor(.blue)
                    }
                }
                
                Section("Wake Time") {
                    DatePicker(
                        "Wake Time",
                        selection: $preferences.wakeTime,
                        displayedComponents: .hourAndMinute
                    )
                }
                
                Section("Sleep Bank Calculation") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Days to Consider")
                            Spacer()
                            Text("\(preferences.sleepBankDays) days")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: sleepBankDaysBinding, in: 3...14, step: 1) {
                            EmptyView()
                        }
                        .accentColor(.blue)
                        
                        Text("How many recent days to include in your sleep bank calculation")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Sleep Limits") {
                    DatePicker(
                        "Earliest reasonable bedtime",
                        selection: earliestBedtimeBinding,
                        displayedComponents: .hourAndMinute
                    )

                    Text("Won't recommend sleeping before this time — allowing up to \(String(format: "%.1f", preferences.nominalMaxSleepHours)) hours per night based on your wake time (aside from DST adjustments).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Data Sources") {
                    if let availableSources = healthKitManager.availableSources {
                        let excluded = sourcePreferences.excludedBundleIdentifiers
                        let availableIDs = Set(availableSources.map(\.bundleIdentifier))
                        let allExcluded = availableIDs.isSubset(of: excluded)
                        let noLongerRelevant = excluded.filter { !availableIDs.contains($0) }
                        
                        ForEach(availableSources, id: \.bundleIdentifier) { source in
                            Toggle(isOn: Binding(
                                get: { !excluded.contains(source.bundleIdentifier) },
                                set: { newValue in
                                    if newValue {
                                        sourcePreferences.includeSource(source.bundleIdentifier)
                                    } else {
                                        sourcePreferences.excludeSource(source.bundleIdentifier)
                                    }
                                }
                            )) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(source.name)
                                        .font(.body)
                                    Text(source.bundleIdentifier)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                            }
                        }
                        
                        ForEach(Array(noLongerRelevant).sorted(), id: \.self) { bundleIdentifier in
                            Button(action: {
                                sourcePreferences.includeSource(bundleIdentifier)
                            }) {
                                Text("Source \(bundleIdentifier) is no longer available. Tap to delete.")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                        
                        if allExcluded {
                            Text("No sources selected. Sleep data will not be displayed.")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        
                    } else {
                        Text("No sources discovered yet. Please log some sleep data to Apple Health.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Diagnostics") {
                    LabeledContent("HealthKit state") {
                        Text(String(describing: healthKitManager.permissionsRequestState))
                            .foregroundStyle(.secondary)
                    }

                    LabeledContent("Sleep samples") {
                        Text("\(healthKitManager.sleepSessions.values.flatMap { $0 }.count)")
                            .foregroundStyle(.secondary)
                    }

                    LabeledContent("Log entries") {
                        Text("\(diagnosticLogger.entries.count)")
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        showingShareSheet = true
                    } label: {
                        Label("Share Diagnostic Logs", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        UIPasteboard.general.string = diagnosticLogger.exportText()
                        copiedLogsConfirmation = true
                    } label: {
                        Label("Copy Logs to Clipboard", systemImage: "doc.on.doc")
                    }

                    Button {
                        retryHealthKitAccess()
                    } label: {
                        if isRetryingHealthKit {
                            HStack {
                                ProgressView()
                                Text("Retrying…")
                            }
                        } else {
                            Label("Retry HealthKit Access", systemImage: "arrow.clockwise")
                        }
                    }
                    .disabled(isRetryingHealthKit)

                    if copiedLogsConfirmation {
                        Text("Logs copied. Paste into a message or email to send to the developer.")
                            .font(.caption)
                            .foregroundColor(.green)
                    }

                    if let diagnosticsMessage {
                        Text(diagnosticsMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text("If sleep data isn't loading, share or copy these logs and send them to the developer.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .sheet(isPresented: $showingShareSheet) {
                    ShareSheet(items: [diagnosticLogger.exportText()])
                }

                #if DEBUG
                Section("Developer") {
                    Button {
                        runDebugTask {
                            try await healthKitManager.generateFakeSleepData(
                                nights: 14,
                                targetSleepHours: preferences.sleepGoalHours
                            )
                            return "Generated 14 nights of fake sleep data."
                        }
                    } label: {
                        Label("Generate Fake Sleep Data (14 nights)", systemImage: "wand.and.stars")
                    }
                    .disabled(debugIsWorking)
                    
                    Button(role: .destructive) {
                        runDebugTask {
                            try await healthKitManager.clearFakeSleepData()
                            return "Cleared fake sleep data."
                        }
                    } label: {
                        Label("Delete Generated Sleep Data", systemImage: "trash")
                    }
                    .disabled(debugIsWorking)
                    
                    if debugIsWorking {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Working...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let debugMessage {
                        Text(debugMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Fake samples are tagged so deletion only removes data this app wrote.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                #endif
                
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if horizontalSizeClass == .compact {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
        }
    }
    
    private func retryHealthKitAccess() {
        isRetryingHealthKit = true
        diagnosticsMessage = nil
        Task { @MainActor in
            await healthKitManager.requestAccessFromUser()
            diagnosticsMessage = healthKitManager.errorMessage ?? "HealthKit access retry finished."
            isRetryingHealthKit = false
        }
    }

    #if DEBUG
    /// Runs a debug action while toggling the working state and surfacing
    /// either a success message or the error description in the UI.
    private func runDebugTask(_ work: @escaping () async throws -> String) {
        debugIsWorking = true
        debugMessage = nil
        Task { @MainActor in
            do {
                let message = try await work()
                debugMessage = message
            } catch {
                debugMessage = "Error: \(error.localizedDescription)"
            }
            debugIsWorking = false
        }
    }
    #endif
}

#Preview {
    let sourcePreferences = SourcePreferences()
    SettingsView(
        preferences: UserPreferences(),
        sourcePreferences: sourcePreferences,
        healthKitManager: HealthKitManager(sourcePreferences: sourcePreferences)
    )
}
