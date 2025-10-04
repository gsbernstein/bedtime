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
        healthKitManager.calculateSleepBank(
            goalHours: userPreferences.sleepGoalHours,
            recentDays: userPreferences.sleepBankDays
        )
    }
    
    private var bedtimeRecommendation: BedtimeRecommendation {
        healthKitManager.generateBedtimeRecommendation(
            wakeTime: userPreferences.wakeTime,
            sleepGoal: userPreferences.sleepGoalHours,
            sleepBank: sleepBank
        )
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // HealthKit Authorization
                    if !healthKitManager.isAuthorized {
                        HealthKitAuthorizationCard(healthKitManager: healthKitManager)
                    } else {
                        // Header
                        VStack(spacing: 8) {
                            Text("Sleep Bank")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            
                            Text(sleepBank.statusDescription)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top)
                        
                        // Sleep Bank Card
                        SleepBankCard(sleepBank: sleepBank)
                        
                        // Bedtime Recommendation Card
                        BedtimeRecommendationCard(recommendation: bedtimeRecommendation)
                        
                        // Recent Sleep Sessions
                        if !healthKitManager.sleepSessions.isEmpty {
                            RecentSleepSessionsCard(sessions: Array(healthKitManager.sleepSessions.prefix(7)))
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Bedtime")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Settings") {
                        showingSettings = true
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(preferences: userPreferences)
            }
        }
        .onAppear {
            if healthKitManager.isAuthorized {
                Task {
                    await healthKitManager.fetchSleepData()
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: UserPreferences.self, inMemory: true)
}

