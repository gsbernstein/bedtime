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
    var preferences: UserPreferences
    var sourcePreferences: SourcePreferences
    var healthKitManager: HealthKitManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var tempSleepGoal: Double
    @State private var tempWakeTime: Date
    @State private var tempSleepBankDays: Double
    @State private var tempMaxSleepHoursPerNight: Double
    @State private var tempMinSleepHoursPerNight: Double
    @State private var tempExcludedSources: Set<String>
    
    init(preferences: UserPreferences, sourcePreferences: SourcePreferences, healthKitManager: HealthKitManager) {
        self.preferences = preferences
        self.sourcePreferences = sourcePreferences
        self.healthKitManager = healthKitManager
        self._tempSleepGoal = State(initialValue: preferences.sleepGoalHours)
        self._tempWakeTime = State(initialValue: preferences.wakeTime)
        self._tempSleepBankDays = State(initialValue: Double(preferences.sleepBankDays))
        self._tempMaxSleepHoursPerNight = State(initialValue: preferences.maxSleepHoursPerNight)
        self._tempMinSleepHoursPerNight = State(initialValue: preferences.minSleepHoursPerNight)
        self._tempExcludedSources = State(initialValue: sourcePreferences.excludedBundleIdentifiers)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Sleep Goal") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Target Sleep Duration")
                            Spacer()
                            Text(TimeFormatter.formatDuration(tempSleepGoal*60*60))
                                .foregroundStyle(.secondary)
                        }
                        
                        Slider(value: $tempSleepGoal, in: 6...12, step: 0.25) {
                            EmptyView()
                        }
                            .accentColor(.blue)
                    }
                }
                
                Section("Wake Time") {
                    DatePicker(
                        "Wake Time",
                        selection: $tempWakeTime,
                        displayedComponents: .hourAndMinute
                    )
                }
                
                Section("Sleep Bank Calculation") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Days to Consider")
                            Spacer()
                            Text("\(String(format: "%.0f", tempSleepBankDays)) days")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $tempSleepBankDays, in: 3...14, step: 1) {
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
                            Text("\(String(format: "%.0f", tempMaxSleepHoursPerNight)) hours")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $tempMaxSleepHoursPerNight, in: 8...16, step: 1) {
                            Text("Max")
                        }
                        .accentColor(.blue)
                        
                        HStack {
                            Text("Min sleep hours per night")
                            Spacer()
                            Text("\(String(format: "%.0f", tempMinSleepHoursPerNight)) hours")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $tempMinSleepHoursPerNight, in: 2...10, step: 1) {
                            Text("Min")
                        }
                        .accentColor(.blue)
                    }
                }
                
                Section("Data Sources") {
                    if let availableSources = healthKitManager.availableSources {
                        let allExcluded = !availableSources.contains(where: { !tempExcludedSources.contains($0.bundleIdentifier) })
                        let noLongerRelevant = tempExcludedSources.filter { !availableSources.map(\.bundleIdentifier).contains($0) }
                        
                        ForEach(availableSources, id: \.bundleIdentifier) { source in
                            let isSelected = !tempExcludedSources.contains(source.bundleIdentifier)
                            
                            Toggle(isOn: Binding(
                                get: { isSelected },
                                set: { newValue in
                                    if newValue {
                                        tempExcludedSources.remove(source.bundleIdentifier)
                                    } else {
                                        tempExcludedSources.insert(source.bundleIdentifier)
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
                                tempExcludedSources.remove(bundleIdentifier)
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
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveSettings()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func saveSettings() {
        preferences.sleepGoalHours = tempSleepGoal
        preferences.wakeTime = tempWakeTime
        preferences.sleepBankDays = Int(tempSleepBankDays)
        preferences.maxSleepHoursPerNight = tempMaxSleepHoursPerNight
        preferences.minSleepHoursPerNight = tempMinSleepHoursPerNight
        preferences.lastUpdated = Date()
        sourcePreferences.excludedBundleIdentifiers = tempExcludedSources
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
