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
    
    private var clampedSleepBankDays: Int {
        min(
            Constants.sleepBankDaysRange.upperBound,
            max(Constants.sleepBankDaysRange.lowerBound, sleepBankDays)
        )
    }
    
    /// Index of the last night currently included in the sleep-bank lookback.
    private var lastIncludedIndex: Int {
        min(clampedSleepBankDays, sortedSessions.count) - 1
    }
    
    private var sleepBankDaysBinding: Binding<Int> {
        Binding(
            get: { clampedSleepBankDays },
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
                ) {
                    Text("\(clampedSleepBankDays) days in Sleep Balance")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 0) {
                    ForEach(0..<sortedSessions.count, id: \.self) { index in
                        let entry = sortedSessions[index]
                        let night = entry.0
                        let isIncluded = index < clampedSleepBankDays
                        
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
        .onAppear {
            if sleepBankDays != clampedSleepBankDays {
                sleepBankDays = clampedSleepBankDays
            }
        }
    }
}
