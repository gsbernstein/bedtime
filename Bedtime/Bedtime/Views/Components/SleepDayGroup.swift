//
//  SleepDayGroup.swift
//  Bedtime
//
//  Created by Greg on 10/4/25.
//

import SwiftUI

struct SleepDayGroup: View {
    let date: Date
    let sessions: [SleepSession]
    let isExpanded: Bool
    let sleepGoal: Double
    let onToggle: () -> Void
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter
    }
    
    private var balanceImpact: (value: Double, isPositive: Bool, color: Color) {
        let totalSleepHours = sessions.map(\.durationInHours).reduce(0, +)
        let difference = totalSleepHours - sleepGoal
        let color = difference >= 0 ? Color.green : difference < -0.5 ? Color.red : Color.secondary
        return (abs(difference), difference >= 0, color)
    }
    
    private var hasSessions: Bool {
        !sessions.isEmpty
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Day header (always visible)
            Button(action: hasSessions ? onToggle : {}) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(dateFormatter.string(from: date))
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        if hasSessions {
                            Text("\(timeFormatter.string(from: sessions.last?.startDate ?? Date())) - \(timeFormatter.string(from: sessions.first?.endDate ?? Date()))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("No sleep data")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(TimeFormatter.formatDuration(sessions.reduce(0) { $0 + $1.duration }))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(hasSessions ? .primary : .secondary)
                        
                        HStack(spacing: 2) {
                            Text(balanceImpact.isPositive ? "+" : "-")
                                .font(.caption)
                                .foregroundColor(balanceImpact.color)
                            
                            Text(String(format: "%.1fh", balanceImpact.value))
                                .font(.caption)
                                .foregroundColor(balanceImpact.color)
                        }
                    }
                    
                    if hasSessions {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!hasSessions)
            
            // Session details (expandable)
            if isExpanded && hasSessions {
                VStack(spacing: 4) {
                    ForEach(Array(sessions.enumerated()), id: \.offset) { index, session in
                        SleepSessionRow(session: session)
                        
                        if index < sessions.count - 1 {
                            Divider()
                        }
                    }
                }
                .padding(.leading, 16)
                .padding(.bottom, 8)
            }
        }
    }
}
