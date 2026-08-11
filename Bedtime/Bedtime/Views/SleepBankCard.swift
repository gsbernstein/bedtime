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
    @Environment(\.durationDisplayStyle) private var durationStyle

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
                    iconColor: sleepBank.statusColor,
                    title: "Sleep Balance"
                ) {
                    Text(sleepBank.statusDescription(style: durationStyle))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Equal-width columns so Status stays centered regardless of
                // how wide Average / Goal strings are (e.g. "6h 35m" vs "7h").
                HStack(alignment: .top, spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Average")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let averageHours = sleepBank.averageHours {
                            Text(TimeFormatter.formatHours(averageHours, style: durationStyle))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(sleepBank.statusColor)
                        } else {
                            Text("no recent data")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(alignment: .center, spacing: 4) {
                        Text("Status")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if sleepBank.averageHours != nil {
                            HStack(alignment: .lastTextBaseline, spacing: 4) {
                                Text(TimeFormatter.formatHours(abs(sleepBank.currentBalance), style: durationStyle))
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(sleepBank.statusColor)
                                
                                Text(sleepBank.isInDebt ? "behind" : "ahead")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Text("unknown")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    
                    goalColumn
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                
                if !fullWindowBank.balanceImpacts.isEmpty {
                    VStack(spacing: 4) {
                        BalanceWaterfallChart(
                            nights: fullWindowBank.recentNights,
                            impacts: fullWindowBank.balanceImpacts,
                            domain: chartBalanceBounds,
                            selectedDays: $sleepBankDays
                        )
                        .frame(height: 64)
                        
                        HStack {
                            Text("Last \(sleepBankDays) days")
                            Spacer()
                            Text("Tap to change")
                        }
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    }
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
            .popover(isPresented: $isEditingGoal) {
                SleepGoalEditor(goalHours: sleepGoalHours)
                    .presentationCompactAdaptation(.popover)
            }
        } else {
            goalLabel(showsEditAffordance: false)
        }
    }

    private func goalLabel(showsEditAffordance: Bool) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
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

#Preview {
    struct PreviewHost: View {
        @State private var days = 7
        @State private var goalHours = 8.0
        
        private let hoursPerNight: [Double?] = [
            6.5, 7.2, nil, 7.8, 6.8, 7.4, 7.0,
            8.4, 8.1, 7.6, 6.9, 7.2, 8.0, 7.1
        ]
        
        private var allNights: [NightSummary] {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            return hoursPerNight.enumerated().map { offset, hours in
                let daysAgo = hoursPerNight.count - 1 - offset
                return NightSummary(
                    date: calendar.date(byAdding: .day, value: -daysAgo, to: today) ?? today,
                    totalHours: hours ?? 0,
                    hasData: hours != nil
                )
            }
        }
        
        private func bank(lastDays: Int) -> SleepBank {
            let nights = allNights.suffix(lastDays)
            let withData = nights.filter(\.hasData)
            let total = withData.map(\.totalHours).reduce(0, +)
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
        }
    }
    
    return PreviewHost()
}
