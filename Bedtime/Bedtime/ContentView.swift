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
    @Environment(\.scenePhase) private var scenePhase
    @Query private var preferences: [UserPreferences]
    @StateObject private var sourcePreferences: SourcePreferences
    @StateObject private var healthKitManager: HealthKitManager
    @ObservedObject private var liveActivityManager = LiveActivityManager.shared
    @State private var showingSettings = false
    @State private var showingError = false
    @State private var error: Error?
    
    init() {
        let sourcePrefs = SourcePreferences()
        _sourcePreferences = StateObject(wrappedValue: sourcePrefs)
        _healthKitManager = StateObject(wrappedValue: HealthKitManager(sourcePreferences: sourcePrefs))
    }
    
    private var lastNightKey: Date {
        let calendar = Calendar.current
        return calendar.startOfDay(
            for: calendar.date(byAdding: .hour, value: -4, to: Date()) ?? Date()
        )
    }

    var lastNightData: [SleepSession]? {
        healthKitManager.sleepSessions[lastNightKey]
    }

    private var recentSourceAppLinks: [SleepSourceAppLink] {
        guard healthKitManager.allSleepSessions[lastNightKey] == nil else { return [] }
        return ViewModel.recentSourceAppLinks(sleepSessions: healthKitManager.allSleepSessions)
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
    
    /// Balance over the widest selectable lookback, independent of the current range, so the
    /// balance chart can show every night the range start can be moved to.
    private var fullWindowSleepBank: SleepBank {
        ViewModel.calculateSleepBank(
            sleepSessions: healthKitManager.sleepSessions,
            goalHours: userPreferences.sleepGoalHours,
            recentDays: Constants.sleepBankDaysRange.upperBound
        )
    }
    
    private var sleepBankDaysBinding: Binding<Int> {
        Binding(
            get: { userPreferences.sleepBankDays },
            set: { userPreferences.sleepBankDays = $0 }
        )
    }
    
    private var sleepGoalHoursBinding: Binding<Double> {
        Binding(
            get: { userPreferences.sleepGoalHours },
            set: { userPreferences.sleepGoalHours = $0 }
        )
    }
    
    private var bedtimeRecommendation: BedtimeRecommendation {
        ViewModel.generateBedtimeRecommendation(
            wakeTime: userPreferences.wakeTime,
            earliestBedtime: userPreferences.earliestReasonableBedtime,
            sleepGoal: userPreferences.sleepGoalHours,
            sleepBank: sleepBank,
            durationStyle: userPreferences.durationDisplayStyle
        )
    }

    private var wakeTimeBinding: Binding<Date> {
        Binding(
            get: { userPreferences.wakeTime },
            set: { userPreferences.wakeTime = $0 }
        )
    }

    private var sleepBankInsight: SleepBankInsight? {
        SleepInsightsEngine.generateInsight(
            sleepSessions: healthKitManager.sleepSessions,
            goalHours: userPreferences.sleepGoalHours,
            maxSleepHours: SleepWindow.maxSleepHours(
                earliestBedtime: userPreferences.earliestReasonableBedtime,
                wakeTime: userPreferences.wakeTime
            )
        )
    }

    var body: some View {
        let isBeforeEvening = Calendar.current.component(.hour, from: Date()) < 18
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // HealthKit Authorization
                    switch healthKitManager.permissionsRequestState {
                    case .loading:
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                    case .shouldRequest:
                        HealthKitAuthorizationCard(healthKitManager: healthKitManager)
                    case .hasRequested:
                        if isBeforeEvening {
                            LastNightCard(sleepSessions: lastNightData,
                                          goal: userPreferences.sleepGoalHours,
                                          sourceAppLinks: recentSourceAppLinks)
                        } else {
                            BedtimeRecommendationCard(
                                recommendation: bedtimeRecommendation,
                                liveActivityManager: liveActivityManager,
                                wakeTime: wakeTimeBinding
                            )
                        }

                        SleepBankCard(
                            sleepBank: sleepBank,
                            fullWindowBank: fullWindowSleepBank,
                            sleepBankDays: sleepBankDaysBinding,
                            sleepGoalHours: sleepGoalHoursBinding,
                            hideChart: userPreferences.hideSleepBankChart
                        )

                        if let sleepBankInsight {
                            SleepInsightsCard(
                                insight: sleepBankInsight,
                                currentSleepBankDays: userPreferences.sleepBankDays,
                                onApplyDays: { days in
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        userPreferences.sleepBankDays = days
                                    }
                                },
                                onRaiseGoal: { goalHours in
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        userPreferences.sleepGoalHours = goalHours
                                    }
                                }
                            )
                        }

                        if isBeforeEvening {
                            BedtimeRecommendationCard(
                                recommendation: bedtimeRecommendation,
                                liveActivityManager: liveActivityManager,
                                wakeTime: wakeTimeBinding
                            )
                        } else {
                            LastNightCard(sleepSessions: lastNightData,
                                          goal: userPreferences.sleepGoalHours,
                                          sourceAppLinks: recentSourceAppLinks)
                        }

                        // Recent Sleep Sessions
                        if !healthKitManager.sleepSessions.isEmpty || !healthKitManager.allSleepSessions.isEmpty {
                            RecentSleepSessionsCard(
                                sessions: healthKitManager.sleepSessions,
                                allSessions: healthKitManager.allSleepSessions,
                                excludedSourceIDs: sourcePreferences.excludedBundleIdentifiers,
                                sleepGoal: userPreferences.sleepGoalHours,
                                sleepBankDays: sleepBankDaysBinding
                            )
                        }
                    }
                }
                .padding()
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
            .environment(\.durationDisplayStyle, userPreferences.durationDisplayStyle)
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
            await refreshBedtimePlan()
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Refresh on return from background: the observer query's background
            // delivery is throttled, and `.task` doesn't re-run on resume, so this
            // covers data added in the Health app while we were suspended.
            guard newPhase == .active else { return }
            Task {
                try? await healthKitManager.fetchSleepData()
                await refreshBedtimePlan()
            }
        }
        .onChange(of: bedtimeRecommendation) { _, _ in
            // Catches every foreground way the recommendation can move — the
            // sleep bank range, sleep goal, or wake time — none of which go
            // through `scenePhase` above since the app never left the
            // foreground for them.
            Task {
                await refreshBedtimePlan()
            }
        }
    }

    /// Records tonight's recommendation for background entry points and brings the
    /// Live Activity in line with it.
    private func refreshBedtimePlan() async {
        let recommendation = bedtimeRecommendation
        let durationStyle = userPreferences.durationDisplayStyle

        BedtimePlanStore.save(recommendation, durationStyle: durationStyle)

        await liveActivityManager.syncWithSchedule(
            recommendation: recommendation,
            durationStyle: durationStyle,
            sourceAppLink: recentSourceAppLinks.first.map {
                BedtimeSourceAppLink(name: $0.name, url: $0.destination)
            }
        )
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

