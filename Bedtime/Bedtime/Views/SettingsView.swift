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
    @State private var tempSleepBankDays: Double
    
    init(preferences: UserPreferences) {
        self.preferences = preferences
        self._tempSleepGoal = State(initialValue: preferences.sleepGoalHours)
        self._tempWakeTime = State(initialValue: preferences.wakeTime.date!)
        self._tempSleepBankDays = State(initialValue: Double(preferences.sleepBankDays))
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
        preferences.wakeTime = Calendar.current.dateComponents([.hour, .minute], from: tempWakeTime)
        preferences.sleepBankDays = Int(tempSleepBankDays)
        preferences.lastUpdated = Date()
    }
}
