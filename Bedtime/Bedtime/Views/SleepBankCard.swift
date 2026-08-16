//
//  SleepBankCard.swift
//  Bedtime
//
//  Created by Greg on 10/4/25.
//

import SwiftUI

struct SleepBankCard: View {
    /// Balance over the selected range, which the Average / Status / Goal columns report.
    let sleepBank: SleepBank
    /// Balance over the full lookback window. The chart draws this instead of the selected
    /// range so it stays a fixed width and can offer every night as a range start.
    let fullWindowBank: SleepBank
    @Binding var sleepBankDays: Int
    /// When provided, the goal is tappable and edits this value directly.
    var sleepGoalHours: Binding<Double>? = nil
    /// When true, the balance waterfall chart is omitted from the card.
    var hideChart: Bool = false
    @Environment(\.durationDisplayStyle) private var durationStyle
    @Environment(\.appTheme) private var theme

    private var colors: any ThemeColorPalette { theme.colors }

    @State private var isEditingGoal = false

    private var formattedGoal: String {
        TimeFormatter.formatHours(
            sleepBank.goalHours,
            style: durationStyle,
            maxFractionDigits: 2
        )
    }
    
    private var chartBalanceBounds: ClosedRange<Double> {
        let values = fullWindowBank.balanceImpacts.flatMap { [$0.priorBalance, $0.newBalance] }
        guard !values.isEmpty else { return -0.75...0.75 }
        
        let dataMin = values.min() ?? 0
        let dataMax = values.max() ?? 0
        let midpoint = (dataMin + dataMax) / 2
        let visualSpan = max((dataMax - dataMin) / 0.85, 1.0)
        let halfSpan = visualSpan / 2
        
        return (midpoint - halfSpan)...(midpoint + halfSpan)
    }
    
    var body: some View {
        CardComponent {
            VStack(spacing: 10) {
                CardHeader(
                    icon: sleepBank.isInDebt ? "moon.zzz.fill" : "moon.stars.fill",
                    iconColor: colors[keyPath: sleepBank.statusColor],
                    title: "Sleep Balance"
                ) {
                    Text(sleepBank.statusDescription(days: sleepBankDays))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Equal-width columns so Status stays centered regardless of
                // how wide Average / Goal strings are (e.g. "6h 35m" vs "7h").
                HStack(alignment: .top, spacing: 0) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Average")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let averageHours = sleepBank.averageHours {
                            Text(TimeFormatter.formatHours(averageHours, style: durationStyle))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(colors[keyPath: sleepBank.statusColor])
                        } else {
                            Text("unknown")
                                .font(.subheadline)
                                .italic()
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(alignment: .center, spacing: 2) {

                        Text(sleepBank.averageHours != nil ? sleepBank.isInDebt ? "Behind" : "Ahead" : "Balance")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if sleepBank.averageHours != nil {
                            Text(TimeFormatter.formatHours(sleepBank.currentBalance, style: durationStyle))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(colors[keyPath: sleepBank.statusColor])
                        } else {
                            Text("unknown")
                                .font(.subheadline)
                                .italic()
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    
                    goalColumn
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                
                if !hideChart && !fullWindowBank.balanceImpacts.isEmpty {
                    BalanceWaterfallChart(
                        nights: fullWindowBank.recentNights,
                        impacts: fullWindowBank.balanceImpacts,
                        domain: chartBalanceBounds,
                        selectedDays: $sleepBankDays
                    )
                    .frame(height: 64)
                }
            }
        }
    }

    @ViewBuilder
    private var goalColumn: some View {
        if let sleepGoalHours {
            Button {
                isEditingGoal = true
            } label: {
                goalLabel(showsEditAffordance: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Sleep goal")
            .accessibilityValue(formattedGoal)
            .accessibilityHint("Adjusts your nightly sleep goal")
            .popover(isPresented: $isEditingGoal, arrowEdge: .bottom) {
                SleepGoalEditor(goalHours: sleepGoalHours)
                    .frame(maxWidth: 150)
                    .presentationCompactAdaptation(.popover)
            }
        } else {
            goalLabel(showsEditAffordance: false)
        }
    }

    private func goalLabel(showsEditAffordance: Bool) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("Goal")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 4) {
                Text(formattedGoal)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                if showsEditAffordance {
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
            }
        }
        .contentShape(Rectangle())
    }
}

#if DEBUG

/// Recomputes the bank from a fixed set of nights whenever the card changes the selected
/// window or the goal, so the previews stay interactive the way the real card is.
private struct SleepBankCardPreview: View {
    /// Hours slept per night, oldest first. `nil` is a night with no tracked sleep.
    let hoursPerNight: [Double?]

    @State private var days = 7
    @State private var goalHours = 8.0

    private var allNights: [NightSummary] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return hoursPerNight.enumerated().map { offset, hours in
            let daysAgo = hoursPerNight.count - 1 - offset
            return NightSummary(
                date: calendar.date(byAdding: .day, value: -daysAgo, to: today) ?? today,
                totalHours: hours
            )
        }
    }

    private func bank(lastDays: Int) -> SleepBank {
        let nights = allNights.suffix(lastDays)
        let withData = nights.filter(\.hasData)
        let total = withData.compactMap(\.totalHours).reduce(0, +)
        return SleepBank(
            currentBalance: total - goalHours * Double(withData.count),
            goalHours: goalHours,
            averageHours: withData.isEmpty ? nil : total / Double(withData.count),
            recentNights: Array(nights)
        )
    }

    var body: some View {
        ScrollView {
            SleepBankCard(
                sleepBank: bank(lastDays: days),
                fullWindowBank: bank(lastDays: allNights.count),
                sleepBankDays: $days,
                sleepGoalHours: $goalHours
            )
            .padding()
        }
        .background(Color.backgroundBehindCards)
    }
}

#Preview("Behind goal") {
    SleepBankCardPreview(hoursPerNight: [
        6.5, 7.2, nil, 7.8, 6.8, 7.4, 7.0,
        6.4, 7.1, 7.6, 6.9, 7.2, 6.6, 7.1
    ])
}

#Preview("Ahead of goal") {
    SleepBankCardPreview(hoursPerNight: [
        8.4, 8.1, 8.6, 7.9, 8.8, 8.2, 8.5,
        8.0, 8.3, 9.0, 8.1, 8.4, 8.7, 8.2
    ])
}

#Preview("No tracked sleep") {
    SleepBankCardPreview(hoursPerNight: Array<Double?>(repeating: nil, count: 14))
}

#Preview("Mostly untracked") {
    SleepBankCardPreview(hoursPerNight: [
        nil, nil, nil, 7.5, nil, nil, nil,
        nil, nil, 8.6, nil, nil, nil, nil
    ])
}

#Preview("Decimal durations") {
    SleepBankCardPreview(hoursPerNight: [
        6.5, 7.2, nil, 7.8, 6.8, 7.4, 7.0,
        6.4, 7.1, 7.6, 6.9, 7.2, 6.6, 7.1
    ])
    .environment(\.durationDisplayStyle, .decimal)
}

#endif
