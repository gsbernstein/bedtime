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
    let allSessions: [SleepSession]
    let excludedSourceIDs: Set<String>
    let isExpanded: Bool
    let sleepGoal: Double
    /// Whether this night counts toward the sleep-bank lookback window.
    var isIncludedInSleepBank: Bool = true
    let onToggle: () -> Void
    @Environment(\.durationDisplayStyle) private var durationStyle
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter
    }

    private var totalSleepHours: Double {
        sessions.map(\.durationInHours).reduce(0, +)
    }
    
    private var balanceImpact: (value: Double, isPositive: Bool, color: Color) {
        let difference = totalSleepHours - sleepGoal
        return (
            abs(difference),
            difference >= 0,
            Constants.sleepDurationColor(
                hours: totalSleepHours,
                goal: sleepGoal,
                graceColor: .secondary
            )
        )
    }
    
    private var hasSessions: Bool {
        !sessions.isEmpty
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Rectangle()
                .fill(isIncludedInSleepBank ? Color.accentColor : Color.secondary.opacity(0.2))
                .frame(width: 3)
                .accessibilityHidden(true)

            VStack(spacing: 0) {
                // Day header (always visible)
                Button(action: onToggle) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(dateFormatter.string(from: date))
                                .font(.subheadline)
                                .fontWeight(.medium)

                            if hasSessions {
                                Text("\(TimeFormatter.formatTimeOfDay(sessions.last!.startDate)) - \(TimeFormatter.formatTimeOfDay(sessions.first!.endDate))")
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
                            if hasSessions {
                                Text(TimeFormatter.formatDuration(
                                    sessions.reduce(0) { $0 + $1.duration },
                                    style: durationStyle
                                ))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)

                                HStack(spacing: 2) {
                                    Text(balanceImpact.isPositive ? "+" : "-")
                                        .font(.caption)
                                        .foregroundColor(balanceImpact.color)

                                    Text(TimeFormatter.formatHours(balanceImpact.value, style: durationStyle))
                                        .font(.caption)
                                        .foregroundColor(balanceImpact.color)
                                }
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

                SleepSourceComparisonView(
                    sessions: allSessions,
                    excludedSourceIDs: excludedSourceIDs
                )
                .padding(.leading, 4)

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
        .opacity(isIncludedInSleepBank ? 1 : 0.45)
        .accessibilityHint(isIncludedInSleepBank ? "Included in sleep balance" : "Not included in sleep balance")
    }
}
