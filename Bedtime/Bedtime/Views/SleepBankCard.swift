//
//  SleepBankCard.swift
//  Bedtime
//
//  Created by Greg on 10/4/25.
//

import SwiftUI

struct SleepBankCard: View {
    let sleepBank: SleepBank
    @Environment(\.durationDisplayStyle) private var durationStyle
    
    private var chartBalanceBounds: ClosedRange<Double> {
        let values = sleepBank.balanceImpacts.flatMap { [$0.priorBalance, $0.newBalance] }
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
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Goal")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(TimeFormatter.formatHours(
                            sleepBank.goalHours,
                            style: durationStyle,
                            maxFractionDigits: 2
                        ))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                
                if !sleepBank.balanceImpacts.isEmpty {
                    BalanceWaterfallChart(
                        nights: sleepBank.recentNights,
                        impacts: sleepBank.balanceImpacts,
                        domain: chartBalanceBounds
                    )
                    .frame(height: 56)
                }
            }
        }
    }
}

#Preview {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    func night(_ daysAgo: Int, _ hours: Double, hasData: Bool = true) -> NightSummary {
        NightSummary(
            date: calendar.date(byAdding: .day, value: -daysAgo, to: today) ?? today,
            totalHours: hasData ? hours : 0,
            hasData: hasData
        )
    }
    let inDebtNights: [NightSummary] = [
        night(6, 6.5), night(5, 7.2), night(4, 0, hasData: false), night(3, 7.8),
        night(2, 6.8), night(1, 7.4), night(0, 7.0)
    ]
    
    return ScrollView {
        SleepBankCard(sleepBank: SleepBank(
            currentBalance: -0.8,
            goalHours: 8,
            averageHours: 7.5,
            recentNights: inDebtNights
        ))
        .padding()
    }
}
