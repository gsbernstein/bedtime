//
//  SettingsView.swift
//  Bedtime
//
//  Created by Greg on 10/4/25.
//

import SwiftUI
import Combine
import HealthKit

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
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Max sleep hours per night")
                            Spacer()
                            Text("\(String(format: "%.0f", preferences.maxSleepHoursPerNight)) hours")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $preferences.maxSleepHoursPerNight, in: 8...16, step: 1) {
                            Text("Max")
                        }
                        .accentColor(.blue)
                        
                        HStack {
                            Text("Min sleep hours per night")
                            Spacer()
                            Text("\(String(format: "%.0f", preferences.minSleepHoursPerNight)) hours")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $preferences.minSleepHoursPerNight, in: 2...10, step: 1) {
                            Text("Min")
                        }
                        .accentColor(.blue)
                    }
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
}

#Preview {
    let sourcePreferences = SourcePreferences()
    SettingsView(
        preferences: UserPreferences(),
        sourcePreferences: sourcePreferences,
        healthKitManager: HealthKitManager(sourcePreferences: sourcePreferences)
    )
}
