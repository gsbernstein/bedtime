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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query private var preferences: [UserPreferences]
    @StateObject private var sourcePreferences: SourcePreferences
    @StateObject private var healthKitManager: HealthKitManager
    @State private var showingSettings = false
    @State private var showingError = false
    @State private var error: Error?
    
    init() {
        let sourcePrefs = SourcePreferences()
        _sourcePreferences = StateObject(wrappedValue: sourcePrefs)
        _healthKitManager = StateObject(wrappedValue: HealthKitManager(sourcePreferences: sourcePrefs))
    }
    
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

    private var sleepBankInsight: SleepBankInsight? {
        SleepInsightsEngine.generateInsight(
            sleepSessions: healthKitManager.sleepSessions,
            goalHours: userPreferences.sleepGoalHours,
            maxSleepHours: userPreferences.maxSleepHoursPerNight
        )
    }

    var body: some View {
        let isBeforeEvening = Calendar.current.component(.hour, from: Date()) < 18
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // HealthKit Authorization
                    if !healthKitManager.hasRequestedAuthorization {
                        HealthKitAuthorizationCard(healthKitManager: healthKitManager)
                    } else {
                        if isBeforeEvening {
                            LastNightCard(sleepSessions: lastNightData,
                                          goal: userPreferences.sleepGoalHours)
                        } else {
                            BedtimeRecommendationCard(recommendation: bedtimeRecommendation)
                        }

                        SleepBankCard(sleepBank: sleepBank)

                        if let sleepBankInsight {
                            SleepInsightsCard(insight: sleepBankInsight)
                        }

                        if isBeforeEvening {
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
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
            .background(Color.backgroundBehindCards)
            .navigationTitle("Bedger")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Settings", systemImage: "gear") {
                        showingSettings.toggle()
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
            .settingsPresentation(
                isPresented: $showingSettings,
                useInspector: horizontalSizeClass == .regular
            ) {
                SettingsView(
                    preferences: userPreferences,
                    sourcePreferences: sourcePreferences,
                    healthKitManager: healthKitManager
                )
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

private extension View {
    /// Presents settings as an inspector pane when `useInspector` is true (iPad regular width)
    /// and as a sheet otherwise (iPhone / iPad split-screen).
    @ViewBuilder
    func settingsPresentation<SettingsContent: View>(
        isPresented: Binding<Bool>,
        useInspector: Bool,
        @ViewBuilder content: @escaping () -> SettingsContent
    ) -> some View {
        if useInspector {
            inspector(isPresented: isPresented) {
                content()
                    .inspectorColumnWidth(min: 320, ideal: 380, max: 480)
            }
        } else {
            sheet(isPresented: isPresented, content: content)
        }
    }
}

