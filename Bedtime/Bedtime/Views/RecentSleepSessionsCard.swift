//
//  RecentSleepSessionsCard.swift
//  Bedtime
//
//  Created by Greg on 10/4/25.
//

import SwiftUI

struct RecentSleepSessionsCard: View {
    
    init(sessions: [Date: [SleepSession]], sleepGoal: Double, dayCount: Int = Constants.sleepHistoryDays) {
        self.sleepGoal = sleepGoal
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        self.sortedSessions = (0..<dayCount).compactMap { offset -> (Date, [SleepSession])? in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let dayStart = calendar.startOfDay(for: day)
            return (dayStart, sessions[dayStart] ?? [])
        }
    }
    
    let sortedSessions: [(Date, [SleepSession])]
    let sleepGoal: Double
    
    @State private var expandedNights: Set<Date> = []
    
    
    var body: some View {
        CardComponent {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.title2)
                        .foregroundColor(.purple)
                        .frame(width: Constants.iconWidth)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Recent Sleep")
                            .font(.headline)
                    }
                    
                    Spacer()
                }
                
                // Grouped sleep sessions
                VStack(spacing: 8) {
                    ForEach(sortedSessions, id: \.0) { night, nightSessions in
                        SleepDayGroup(
                            date: night,
                            sessions: nightSessions,
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
