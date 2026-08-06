//
//  SleepInsightsCard.swift
//  Bedtime
//
//  Surfaces auto-selected flattering and motivating sleep-bank windows.
//

import SwiftUI

struct SleepInsightsCard: View {
    let insight: SleepBankInsight
    var currentSleepBankDays: Int = 7
    var onApplyDays: ((Int) -> Void)? = nil

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

    /// The behind window is the only actionable suggestion. "Motivator" is an
    /// internal selection concept, so the UI describes only the date range.
    private var suggestedDays: Int? {
        guard let window = insight.motivatorWindow,
              !window.isAhead,
              window.days != currentSleepBankDays else {
            return nil
        }
        return window.days
    }

    var body: some View {
        CardComponent {
            VStack(alignment: .leading, spacing: 12) {
                CardHeader(
                    icon: iconName,
                    iconColor: accentColor,
                    title: "Sleep Insight"
                )

                Text(insight.message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let suggestedDays, let onApplyDays {
                    Button {
                        onApplyDays(suggestedDays)
                    } label: {
                        Label("Use the last \(suggestedDays) days", systemImage: "calendar")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                        }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                    .padding(.top, 4)
                }
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

    SleepInsightsCard(insight: insight, currentSleepBankDays: 7) { _ in }
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

    SleepInsightsCard(insight: insight, currentSleepBankDays: 7) { _ in }
        .padding()
        .background(Color.backgroundBehindCards)
}
