//
//  RecentSleepSessionsCard.swift
//  Bedtime
//
//  Created by Greg on 10/4/25.
//

import SwiftUI

struct RecentSleepSessionsCard: View {
    
    init(sessions: [Date: [SleepSession]], sleepGoal: Double) {
        self.sessions = sessions
        self.sortedSessions = sessions.sorted { $0.key > $1.key }
        self.sleepGoal = sleepGoal
    }
    
    let sessions: [Date: [SleepSession]]
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
