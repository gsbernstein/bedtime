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
    
    var body: some View {
        CardComponent {
            VStack(spacing: 16) {
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
                    VStack(alignment: .leading, spacing: 8) {
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
                    
                    VStack(alignment: .center, spacing: 8) {
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
                    
                    VStack(alignment: .trailing, spacing: 8) {
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
            }
        }
    }
}

#Preview {
    SleepBankCard(sleepBank: SleepBank(currentBalance: -0.8, goalHours: 8, averageHours: 7.5))
    SleepBankCard(sleepBank: SleepBank(currentBalance: -0.3, goalHours: 8, averageHours: 7.8))
    SleepBankCard(sleepBank: SleepBank(currentBalance: 0.8, goalHours: 8, averageHours: 8.5))
    SleepBankCard(sleepBank: SleepBank(currentBalance: 0, goalHours: 8, averageHours: nil))
}
