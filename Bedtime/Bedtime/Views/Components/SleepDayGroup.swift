//
//  SleepDayGroup.swift
//  Bedtime
//
//  Created by Greg on 10/4/25.
//

import SwiftUI

struct SleepDayGroup: View {
    let date: Date
    let daySleepData: DaySleepData
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
        formatter.dateFormat = "MMM d"
        return formatter
    }
    
    private var balanceImpact: (value: Double, isPositive: Bool, color: Color) {
        let totalSleepHours = daySleepData.totalNightSleepHours
        let difference = totalSleepHours - sleepGoal
        let color = difference >= 0 ? Color.green : difference < -0.5 ? Color.red : Color.secondary
        return (abs(difference), difference >= 0, color)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Day header (always visible)
            Button(action: onToggle) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(dateFormatter.string(from: date))
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        if !daySleepData.nightSleep.isEmpty {
                            Text("\(timeFormatter.string(from: daySleepData.nightSleep.last?.startDate ?? Date())) - \(timeFormatter.string(from: daySleepData.nightSleep.first?.endDate ?? Date()))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("No night sleep data")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(TimeFormatter.formatDuration(daySleepData.totalNightSleepHours * 3600))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 2) {
                            Text(balanceImpact.isPositive ? "+" : "-")
                                .font(.caption)
                                .foregroundColor(balanceImpact.color)
                            
                            Text(String(format: "%.1fh", balanceImpact.value))
                                .font(.caption)
                                .foregroundColor(balanceImpact.color)
                        }
                    }
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Session details (expandable)
            if isExpanded {
                VStack(spacing: 4) {
                    // Night sleep sessions
                    if !daySleepData.nightSleep.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Night Sleep")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            ForEach(Array(daySleepData.nightSleep.enumerated()), id: \.offset) { index, session in
                                SleepSessionRow(session: session)
                                
                                if index < daySleepData.nightSleep.count - 1 {
                                    Divider()
                                }
                            }
                        }
                    }
                    
                    // Nap sessions
                    if !daySleepData.naps.isEmpty {
                        if !daySleepData.nightSleep.isEmpty {
                            Divider()
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Naps (\(String(format: "%.1f", daySleepData.totalNapHours))h)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            ForEach(Array(daySleepData.naps.enumerated()), id: \.offset) { index, session in
                                SleepSessionRow(session: session)
                                
                                if index < daySleepData.naps.count - 1 {
                                    Divider()
                                }
                            }
                        }
                    }
                }
                .padding(.leading, 16)
                .padding(.bottom, 8)
            }
        }
    }
}
