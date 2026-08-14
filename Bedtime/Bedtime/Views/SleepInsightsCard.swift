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
    /// Called with the new goal in hours when the raise-goal button is tapped.
    var onRaiseGoal: ((Double) -> Void)? = nil
    @Environment(\.durationDisplayStyle) private var durationStyle

    private var accentColor: Color {
        if insight.congratulationWindow != nil {
            return AppColors.positive
        }
        return AppColors.warning
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

    private func formattedGoal(_ hours: Double) -> String {
        TimeFormatter.formatHours(hours, style: durationStyle, maxFractionDigits: 2)
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
                    .tint(AppColors.warning)
                    .padding(.top, 4)
                }

                if let goalIncrease = insight.suggestedGoalIncrease, let onRaiseGoal {
                    Button {
                        onRaiseGoal(goalIncrease.suggestedGoalHours)
                    } label: {
                        Label(
                            "Raise goal to \(formattedGoal(goalIncrease.suggestedGoalHours))",
                            systemImage: "arrow.up.circle"
                        )
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(AppColors.positive)
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
        sleepBank: SleepBank(currentBalance: 0.5, goalHours: 8, averageHours: 8.04, recentNights: [])
    )
    let behind = SleepWindowBalance(
        days: 3,
        balance: -0.75,
        sleepBank: SleepBank(currentBalance: -0.75, goalHours: 8, averageHours: 7.75, recentNights: [])
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
        motivatorIsCatchable: true,
        suggestedGoalIncrease: nil
    )

    SleepInsightsCard(
        insight: insight,
        currentSleepBankDays: 7,
        onApplyDays: { _ in }
    )
    .padding()
    .background(Color.backgroundBehindCards)
}

#Preview("Motivator only") {
    let behind = SleepWindowBalance(
        days: 5,
        balance: -1.25,
        sleepBank: SleepBank(currentBalance: -1.25, goalHours: 8, averageHours: 7.75, recentNights: [])
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
        motivatorIsCatchable: true,
        suggestedGoalIncrease: nil
    )

    SleepInsightsCard(
        insight: insight,
        currentSleepBankDays: 7,
        onApplyDays: { _ in }
    )
    .padding()
    .background(Color.backgroundBehindCards)
}

#Preview("Caught up everywhere") {
    let ahead = SleepWindowBalance(
        days: 14,
        balance: 5.6,
        sleepBank: SleepBank(currentBalance: 5.6, goalHours: 8, averageHours: 8.4, recentNights: [])
    )
    let goalIncrease = SuggestedGoalIncrease(
        currentGoalHours: 8,
        suggestedGoalHours: 8.25,
        windowDays: 14
    )
    let insight = SleepBankInsight(
        message: SleepInsightsEngine.buildNarrative(
            congratulation: ahead,
            motivator: nil,
            goalHours: 8,
            maxSleepHours: 10,
            goalIncrease: goalIncrease
        )!,
        congratulationWindow: ahead,
        motivatorWindow: nil,
        motivatorIsCatchable: false,
        suggestedGoalIncrease: goalIncrease
    )

    SleepInsightsCard(
        insight: insight,
        currentSleepBankDays: 7,
        onApplyDays: { _ in },
        onRaiseGoal: { _ in }
    )
    .padding()
    .background(Color.backgroundBehindCards)
}
