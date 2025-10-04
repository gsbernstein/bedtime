//
//  RecentSleepSessionsCard.swift
//  Bedtime
//
//  Created by Greg on 10/4/25.
//

import SwiftUI

struct RecentSleepSessionsCard: View {
    
    init(sessions: [Date: [SleepSession]]) {
        self.sessions = sessions
        self.sortedSessions = sessions.sorted { $0.key > $1.key }
    }
    
    let sessions: [Date: [SleepSession]]
    let sortedSessions: [(Date, [SleepSession])]
    
    @State private var expandedNights: Set<Date> = []
    
    let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.title2)
                    .foregroundColor(.purple)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recent Sleep")
                        .font(.headline)
                    
                    Text("Last \(sessions.count) sessions")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Grouped sleep sessions
            VStack(spacing: 8) {
                ForEach(sortedSessions, id: \.0) { night, nightSessions in
                    VStack(spacing: 0) {
                        // Night header (always visible)
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if expandedNights.contains(night) {
                                    expandedNights.remove(night)
                                } else {
                                    expandedNights.insert(night)
                                }
                            }
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(formatter.string(from: night))
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    Text("\(nightSessions.count) session\(nightSessions.count == 1 ? "" : "s")")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(TimeFormatter.formatDuration(nightSessions.reduce(0) { $0 + $1.duration }))
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    
                                    Text("total")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Image(systemName: expandedNights.contains(night) ? "chevron.up" : "chevron.down")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Session details (expandable)
                        if expandedNights.contains(night) {
                            VStack(spacing: 4) {
                                ForEach(Array(nightSessions.enumerated()), id: \.offset) { index, session in
                                    HStack {
                                        HStack(spacing: 6) {
                                            Image(systemName: session.sleepType.icon)
                                                .font(.caption)
                                                .foregroundColor(Color(session.sleepType.color))
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("\(timeFormatter.string(from: session.startDate)) - \(timeFormatter.string(from: session.endDate))")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                
                                                Text(session.sleepType.displayName)
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        Text(TimeFormatter.formatDuration(session.duration))
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                    }
                                    .padding(.vertical, 2)
                                    
                                    if index < nightSessions.count - 1 {
                                        Divider()
                                    }
                                }
                            }
                            .padding(.leading, 16)
                            .padding(.bottom, 8)
                        }
                    }
                    
                    if night != sortedSessions.last?.0 {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}
