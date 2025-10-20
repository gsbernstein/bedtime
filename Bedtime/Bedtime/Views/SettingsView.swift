//
//  SettingsView.swift
//  Bedtime
//
//  Created by Greg on 10/4/25.
//

import SwiftUI
import Combine

struct SettingsView: View {
    var preferences: UserPreferences
    @Environment(\.dismiss) private var dismiss
    @State private var tempSleepGoal: Double
    @State private var tempWakeTime: Date
    @State private var tempMaxSleepHoursPerNight: Double
    @State private var tempMinSleepHoursPerNight: Double
    
    init(preferences: UserPreferences) {
        self.preferences = preferences
        self._tempSleepGoal = State(initialValue: preferences.sleepGoalHours)
        self._tempWakeTime = State(initialValue: preferences.wakeTime)
        self._tempMaxSleepHoursPerNight = State(initialValue: preferences.maxSleepHoursPerNight)
        self._tempMinSleepHoursPerNight = State(initialValue: preferences.minSleepHoursPerNight)
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
        preferences.maxSleepHoursPerNight = tempMaxSleepHoursPerNight
        preferences.minSleepHoursPerNight = tempMinSleepHoursPerNight
        preferences.lastUpdated = Date()
    }
}

#Preview {
    SettingsView(preferences: UserPreferences())
}
