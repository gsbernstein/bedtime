//
//  SleepInsightsCard.swift
//  Bedtime
//
//  Surfaces auto-selected flattering and motivating sleep-bank windows.
//

import SwiftUI

struct SleepInsightsCard: View {
    let insight: SleepBankInsight

    private var accentColor: Color {
        if insight.congratulationWindow != nil {
            return .green
        }
        return .orange
    }

    private var iconName: String {
        if insight.congratulationWindow != nil && insight.motivatorWindow?.isAhead == false {
            return "sparkles"
        }
        if insight.congratulationWindow != nil {
            return "hand.thumbsup.fill"
        }
        return "bolt.fill"
    }

    var body: some View {
        CardComponent {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: iconName)
                    .font(.title2)
                    .foregroundColor(accentColor)
                    .frame(width: Constants.iconWidth)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Sleep Insight")
                        .font(.headline)

                    Text(insight.message)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
        }
    }
}

#Preview("Ahead and behind") {
    let ahead = SleepWindowBalance(
        days: 12,
        balance: 0.5,
        sleepBank: SleepBank(currentBalance: 0.5, goalHours: 8, averageHours: 8.04)
    )
    let behind = SleepWindowBalance(
        days: 3,
        balance: -0.75,
        sleepBank: SleepBank(currentBalance: -0.75, goalHours: 8, averageHours: 7.75)
    )
    let insight = SleepBankInsight(
        message: SleepInsightsEngine.buildNarrative(
            congratulation: ahead,
            motivator: behind,
            goalHours: 8,
            maxSleepHours: 10
        )!,
        congratulationWindow: ahead,
        motivatorWindow: behind,
        motivatorIsCatchable: true
    )

    SleepInsightsCard(insight: insight)
        .padding()
        .background(Color.backgroundBehindCards)
}

#Preview("Motivator only") {
    let behind = SleepWindowBalance(
        days: 5,
        balance: -1.25,
        sleepBank: SleepBank(currentBalance: -1.25, goalHours: 8, averageHours: 7.75)
    )
    let insight = SleepBankInsight(
        message: SleepInsightsEngine.buildNarrative(
            congratulation: nil,
            motivator: behind,
            goalHours: 8,
            maxSleepHours: 10
        )!,
        congratulationWindow: nil,
        motivatorWindow: behind,
        motivatorIsCatchable: true
    )

    SleepInsightsCard(insight: insight)
        .padding()
        .background(Color.backgroundBehindCards)
}
