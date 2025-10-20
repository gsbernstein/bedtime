//
//  ContentView.swift
//  Bedtime
//
//  Created by Greg on 10/4/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var preferences: [UserPreferences]
    @StateObject private var healthKitManager = HealthKitManager()
    @State private var showingSettings = false
    @State private var showingError = false
    @State private var error: Error?
    
    var lastNightData: [SleepSession]? {
        let calendar = Calendar.current
        let lastNight = calendar.startOfDay(for: calendar.date(byAdding: .hour, value: -4, to: Date()) ?? Date())
        return healthKitManager.sleepSessions[lastNight]
    }
    
    private var userPreferences: UserPreferences {
        if let existing = preferences.first {
            return existing
        } else {
            let new = UserPreferences()
            modelContext.insert(new)
            return new
        }
    }
    
    private var sleepBank: SleepBank {
        ViewModel.calculateSleepBank(
            sleepSessions: healthKitManager.sleepSessions,
            goalHours: userPreferences.sleepGoalHours,
            recentDays: userPreferences.sleepBankDays
        )
    }
    
    private var bedtimeRecommendation: BedtimeRecommendation {
        ViewModel.generateBedtimeRecommendation(
            wakeTime: userPreferences.wakeTime,
            sleepGoal: userPreferences.sleepGoalHours,
            sleepBank: sleepBank,
            maxSleepHours: userPreferences.maxSleepHoursPerNight,
            minSleepHours: userPreferences.minSleepHoursPerNight
        )
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.backgroundBehindCards.edgesIgnoringSafeArea(.all)
                ScrollView {
                    VStack(spacing: 20) {
                        // HealthKit Authorization
                        if !healthKitManager.isAuthorized {
                            HealthKitAuthorizationCard(healthKitManager: healthKitManager)
                        } else {
                            
                            if Calendar.current.component(.hour, from: Date()) < 18 {
                                LastNightCard(sleepSessions: lastNightData,
                                            goal: userPreferences.sleepGoalHours)
                            } else {
                                BedtimeRecommendationCard(recommendation: bedtimeRecommendation)
                            }
                            
                            SleepBankCard(sleepBank: sleepBank)
                            
                            if Calendar.current.component(.hour, from: Date()) < 18 {
                                BedtimeRecommendationCard(recommendation: bedtimeRecommendation)
                            } else {
                                LastNightCard(sleepSessions: lastNightData,
                                            goal: userPreferences.sleepGoalHours)
                            }
                            
                            // Recent Sleep Sessions
                            if !healthKitManager.sleepSessions.isEmpty {
                                RecentSleepSessionsCard(sessions: healthKitManager.sleepSessions, sleepGoal: userPreferences.sleepGoalHours)
                            }
                        }
                    }
                    .padding()
                }
                .navigationTitle("Bedtime")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Settings", systemImage: "gear") {
                            showingSettings = true
                        }
                    }
                }
                .refreshable {
                    do {
                        try await healthKitManager.fetchSleepData()
                    } catch {
                        showingError = true
                        self.error = error
                    }
                }
                .alert(isPresented: $showingError) {
                    Alert(title: Text("Error"), message: Text("Error refreshing sleep data: \(error?.localizedDescription ?? "Unknown error")"), dismissButton: .default(Text("OK")))
                }
                .sheet(isPresented: $showingSettings) {
                    SettingsView(preferences: userPreferences)
                }
            }
        }
        .task {
            try? await healthKitManager.fetchSleepData()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: UserPreferences.self, inMemory: true)
}

