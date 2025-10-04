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
    @State private var tempSleepBankDays: Int
    
    init(preferences: UserPreferences) {
        self.preferences = preferences
        self._tempSleepGoal = State(initialValue: preferences.sleepGoalHours)
        self._tempWakeTime = State(initialValue: preferences.wakeTime)
        self._tempSleepBankDays = State(initialValue: preferences.sleepBankDays)
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
                                .foregroundColor(.secondary)
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
                    .datePickerStyle(.wheel)
                }
                
                Section("Sleep Bank Calculation") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Days to Consider")
                            Spacer()
                            Text("\(tempSleepBankDays) days")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: Binding(
                            get: { Double(tempSleepBankDays) },
                            set: { tempSleepBankDays = Int($0) }
                        ), in: 3...14, step: 1)
                        .accentColor(.blue)
                        
                        Text("How many recent days to include in your sleep bank calculation")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Current Settings") {
                    HStack {
                        Text("Sleep Goal")
                        Spacer()
                        Text(preferences.sleepGoalString)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Wake Time")
                        Spacer()
                        Text(preferences.wakeTimeString)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Sleep Bank Period")
                        Spacer()
                        Text("\(preferences.sleepBankDays) days")
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
        preferences.sleepBankDays = tempSleepBankDays
        preferences.lastUpdated = Date()
    }
}
