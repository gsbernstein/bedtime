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
        dayCount: Int = Constants.sleepHistoryDays
    ) {
        self.sleepGoal = sleepGoal
        self.excludedSourceIDs = excludedSourceIDs
        
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
    
    @State private var expandedNights: Set<Date> = []
    
    
    var body: some View {
        CardComponent {
            VStack(spacing: 16) {
                CardHeader(
                    icon: "chart.line.uptrend.xyaxis",
                    iconColor: .purple,
                    title: "Recent Sleep"
                )
                
                // Grouped sleep sessions
                VStack(spacing: 8) {
                    ForEach(sortedSessions, id: \.0) { night, nightSessions, allNightSessions in
                        SleepDayGroup(
                            date: night,
                            sessions: nightSessions,
                            allSessions: allNightSessions,
                            excludedSourceIDs: excludedSourceIDs,
                            isExpanded: expandedNights.contains(night),
                            sleepGoal: sleepGoal,
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
                        
                        if night != sortedSessions.last?.0 {
                            Divider()
                        }
                    }
                }
            }
        }
    }
}
