//
//  RecentSleepSessionsCard.swift
//  Bedtime
//
//  Created by Greg on 10/4/25.
//

import SwiftUI

struct RecentSleepSessionsCard: View {
    
    init(
        sessions: [Date: [SleepSession]],
        allSessions: [Date: [SleepSession]],
        excludedSourceIDs: Set<String>,
        sleepGoal: Double,
        sleepBankDays: Binding<Int>,
        dayCount: Int = Constants.sleepHistoryDays
    ) {
        self.sleepGoal = sleepGoal
        self.excludedSourceIDs = excludedSourceIDs
        self._sleepBankDays = sleepBankDays
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        self.sortedSessions = (0..<dayCount).compactMap { offset -> (Date, [SleepSession], [SleepSession])? in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let dayStart = calendar.startOfDay(for: day)
            return (dayStart, sessions[dayStart] ?? [], allSessions[dayStart] ?? [])
        }
    }
    
    let sortedSessions: [(Date, [SleepSession], [SleepSession])]
    let sleepGoal: Double
    let excludedSourceIDs: Set<String>
    @Binding var sleepBankDays: Int
    
    @State private var expandedNights: Set<Date> = []
    
    /// Index of the last night currently included in the sleep-bank lookback.
    private var lastIncludedIndex: Int {
        min(sleepBankDays, sortedSessions.count) - 1
    }
    
    private var sleepBankDaysBinding: Binding<Int> {
        Binding(
            get: { sleepBankDays },
            set: { newValue in
                sleepBankDays = min(
                    Constants.sleepBankDaysRange.upperBound,
                    max(Constants.sleepBankDaysRange.lowerBound, newValue)
                )
            }
        )
    }
    
    var body: some View {
        CardComponent {
            VStack(spacing: 16) {
                CardHeader(
                    icon: "chart.line.uptrend.xyaxis",
                    iconColor: .purple,
                    title: "Recent Sleep"
                )
                
                VStack(spacing: 0) {
                    ForEach(0..<sortedSessions.count, id: \.self) { index in
                        let entry = sortedSessions[index]
                        let night = entry.0
                        let isIncluded = index < sleepBankDays

                        SleepDayGroup(
                            date: night,
                            sessions: entry.1,
                            allSessions: entry.2,
                            excludedSourceIDs: excludedSourceIDs,
                            isExpanded: expandedNights.contains(night),
                            sleepGoal: sleepGoal,
                            isIncludedInSleepBank: isIncluded,
                            onToggle: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if expandedNights.contains(night) {
                                        expandedNights.remove(night)
                                    } else {
                                        expandedNights.insert(night)
                                    }
                                }
                            }
                        )
                        
                        if index == lastIncludedIndex {
                            IncludedDaysRangeHandle(days: sleepBankDaysBinding)
                        } else if index < sortedSessions.count - 1 {
                            Divider()
                                .opacity(isIncluded ? 1 : 0.5)
                                .padding(.leading, 11)
                                .overlay(alignment: .leading) {
                                    Rectangle()
                                        .fill(isIncluded ? Color.accentColor : Color.secondary.opacity(0.2))
                                        .frame(width: 3)
                                        .accessibilityHidden(true)
                                }
                        }
                    }
                }
            }
        }
    }
}

#if DEBUG

import HealthKit

/// Builds one session per tracked night so the previews can exercise the range handle,
/// which moves the boundary between included and excluded nights.
private struct RecentSleepSessionsCardPreview: View {
    /// Hours slept per night, most recent first. `nil` is a night with no tracked sleep.
    let hoursPerNight: [Double?]

    @State private var days = 5

    /// Each night ends at 7am on the day it is keyed under, matching how the card looks
    /// sessions up by the start of their day.
    private var sessionsByNight: [Date: [SleepSession]] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var sessions: [Date: [SleepSession]] = [:]
        for (offset, hours) in hoursPerNight.enumerated() {
            guard let hours,
                  let night = calendar.date(byAdding: .day, value: -offset, to: today),
                  let wakeTime = calendar.date(byAdding: .hour, value: 7, to: night)
            else { continue }
            sessions[night] = [
                SleepSession(
                    startDate: wakeTime.addingTimeInterval(-hours * 3600),
                    endDate: wakeTime,
                    sleepType: .asleepUnspecified,
                    source: .init(source: .default(), version: nil)
                )
            ]
        }
        return sessions
    }

    var body: some View {
        ScrollView {
            RecentSleepSessionsCard(
                sessions: sessionsByNight,
                allSessions: sessionsByNight,
                excludedSourceIDs: [],
                sleepGoal: 8,
                sleepBankDays: $days,
                dayCount: hoursPerNight.count
            )
            .padding()
        }
        .background(Color.backgroundBehindCards)
    }
}

#Preview("Tracked every night") {
    RecentSleepSessionsCardPreview(hoursPerNight: [7.4, 8.2, 6.8, 8.6, 7.1, 8.0, 6.5, 7.9])
}

#Preview("Missing nights") {
    RecentSleepSessionsCardPreview(hoursPerNight: [nil, 8.2, nil, nil, 7.1, 8.0, nil, 7.9])
}

#endif
