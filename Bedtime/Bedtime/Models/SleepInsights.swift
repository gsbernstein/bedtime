//
//  SleepInsights.swift
//  Bedtime
//
//  Heuristics that pick flattering congrats windows and motivating debt
//  windows across lookback durations, then weave them into a narrative.
//

import Foundation

struct SleepWindowBalance: Equatable {
    let days: Int
    let balance: Double
    let sleepBank: SleepBank

    var isAhead: Bool { balance >= 0 }
    var aheadHours: Double { max(0, balance) }
    var behindHours: Double { max(0, -balance) }
}

struct SleepBankInsight: Equatable {
    let message: String
    let congratulationWindow: SleepWindowBalance?
    let motivatorWindow: SleepWindowBalance?
    let motivatorIsCatchable: Bool
    /// Present only when there's nothing to catch up on, so the insight can
    /// offer a bigger goal instead of a catch-up nudge.
    let suggestedGoalIncrease: SuggestedGoalIncrease?
}

/// A goal the recent nightly average already clears, offered when every
/// lookback window is caught up.
struct SuggestedGoalIncrease: Equatable {
    let currentGoalHours: Double
    let suggestedGoalHours: Double
    /// Lookback the surplus was measured over.
    let windowDays: Int

    var increaseHours: Double { suggestedGoalHours - currentGoalHours }
}

enum SleepInsightsEngine {
    /// Lookback durations scanned for motivator windows (matches Settings range).
    static var windowRange: ClosedRange<Int> { Constants.sleepBankDaysRange }

    /// Nights of data the full window needs before a surplus is treated as spare
    /// capacity rather than a couple of lucky logged nights.
    static let goalRaiseMinimumTrackedNights = 10

    static func generateInsight(
        sleepSessions: [Date: [SleepSession]],
        goalHours: Double,
        maxSleepHours: Double
    ) -> SleepBankInsight? {
        let snapshots = windowBalances(sleepSessions: sleepSessions, goalHours: goalHours)
        guard snapshots.contains(where: { $0.sleepBank.averageHours != nil }) else {
            return nil
        }

        let congratulation = selectCongratulation(from: snapshots)
        let motivator = selectMotivator(
            from: snapshots,
            goalHours: goalHours,
            maxSleepHours: maxSleepHours
        )

        let goalIncrease = suggestedGoalIncrease(
            from: snapshots,
            goalHours: goalHours,
            maxSleepHours: maxSleepHours
        )

        guard let message = buildNarrative(
            congratulation: congratulation,
            motivator: motivator,
            goalHours: goalHours,
            maxSleepHours: maxSleepHours,
            goalIncrease: goalIncrease
        ) else {
            return nil
        }

        let motivatorIsCatchable = motivator.map {
            isCatchableInOneNight(balance: $0.balance, goalHours: goalHours, maxSleepHours: maxSleepHours)
        } ?? false

        return SleepBankInsight(
            message: message,
            congratulationWindow: congratulation,
            motivatorWindow: motivator,
            motivatorIsCatchable: motivatorIsCatchable,
            suggestedGoalIncrease: goalIncrease
        )
    }

    // MARK: - Window series

    static func windowBalances(
        sleepSessions: [Date: [SleepSession]],
        goalHours: Double
    ) -> [SleepWindowBalance] {
        windowRange.map { days in
            let bank = ViewModel.calculateSleepBank(
                sleepSessions: sleepSessions,
                goalHours: goalHours,
                recentDays: days
            )
            return SleepWindowBalance(days: days, balance: bank.currentBalance, sleepBank: bank)
        }
    }

    // MARK: - Selection heuristics

    /// Longest lookback where cumulative balance is still non-negative.
    static func selectCongratulation(from snapshots: [SleepWindowBalance]) -> SleepWindowBalance? {
        snapshots.filter(\.isAhead).max(by: { $0.days < $1.days })
    }

    /// Prefers the most behind lookback that can still be caught up in one night.
    /// Falls back to the shortest behind window when debt is too large to clear tonight.
    static func selectMotivator(
        from snapshots: [SleepWindowBalance],
        goalHours: Double,
        maxSleepHours: Double
    ) -> SleepWindowBalance? {
        let behind = snapshots.filter { !$0.isAhead }
        guard !behind.isEmpty else { return nil }

        if let catchable = behind
            .filter({ isCatchableInOneNight(balance: $0.balance, goalHours: goalHours, maxSleepHours: maxSleepHours) })
            .min(by: { $0.balance < $1.balance }) {
            return catchable
        }

        return behind.min(by: { $0.days < $1.days })
    }

    /// A bigger goal to offer when there's no debt anywhere in the scanned
    /// windows — including the longest one — so the surplus is spare capacity
    /// rather than a rebound from a bad stretch.
    static func suggestedGoalIncrease(
        from snapshots: [SleepWindowBalance],
        goalHours: Double,
        maxSleepHours: Double
    ) -> SuggestedGoalIncrease? {
        guard
            let fullWindow = snapshots.first(where: { $0.days == windowRange.upperBound }),
            fullWindow.sleepBank.averageHours != nil,
            snapshots.allSatisfy(\.isAhead)
        else {
            return nil
        }

        let trackedNights = fullWindow.sleepBank.recentNights.filter(\.hasData).count
        guard trackedNights >= goalRaiseMinimumTrackedNights else { return nil }

        let surplusPerNight = fullWindow.aheadHours / Double(trackedNights)
        // Never suggest more than the sleep window allows, and round down so the
        // recent average already clears the new goal.
        let ceiling = min(Constants.sleepGoalHoursRange.upperBound, maxSleepHours)
        let suggested = Constants.snappedSleepGoalHours(
            min(goalHours + surplusPerNight, ceiling),
            rounding: .down
        )

        guard suggested > goalHours + Constants.sleepGoalStepHours / 2 else { return nil }

        return SuggestedGoalIncrease(
            currentGoalHours: goalHours,
            suggestedGoalHours: suggested,
            windowDays: fullWindow.days
        )
    }

    /// Whether tonight's recommended sleep duration can fully cover this window's debt.
    static func isCatchableInOneNight(
        balance: Double,
        goalHours: Double,
        maxSleepHours: Double
    ) -> Bool {
        let sleepNeeded = goalHours - balance
        return sleepNeeded <= maxSleepHours
    }

    // MARK: - Narrative

    static func buildNarrative(
        congratulation: SleepWindowBalance?,
        motivator: SleepWindowBalance?,
        goalHours: Double,
        maxSleepHours: Double,
        goalIncrease: SuggestedGoalIncrease? = nil
    ) -> String? {
        switch (congratulation, motivator) {
        case let (congrats?, motivator?) where congrats.isAhead && !motivator.isAhead:
            let catchable = isCatchableInOneNight(
                balance: motivator.balance,
                goalHours: goalHours,
                maxSleepHours: maxSleepHours
            )
            return combinedNarrative(
                congratulation: congrats,
                motivator: motivator,
                motivatorIsCatchable: catchable,
                goalHours: goalHours,
                maxSleepHours: maxSleepHours
            )

        case let (congrats?, _) where congrats.isAhead:
            return aheadNarrative(window: congrats, goalIncrease: goalIncrease)

        case let (_, motivator?) where !motivator.isAhead:
            let catchable = isCatchableInOneNight(
                balance: motivator.balance,
                goalHours: goalHours,
                maxSleepHours: maxSleepHours
            )
            return behindNarrative(
                window: motivator,
                isCatchable: catchable,
                goalHours: goalHours,
                maxSleepHours: maxSleepHours
            )

        default:
            return nil
        }
    }

    private static func combinedNarrative(
        congratulation: SleepWindowBalance,
        motivator: SleepWindowBalance,
        motivatorIsCatchable: Bool,
        goalHours: Double,
        maxSleepHours: Double
    ) -> String {
        let aheadPhrase = formatHoursNaturally(congratulation.aheadHours)
        let behindPhrase = formatHoursNaturally(motivator.behindHours)
        let motivatorDays = dayCountPhrase(motivator.days)

        if congratulation.days == motivator.days {
            return """
            You're \(aheadPhrase) ahead over the last \(dayCountPhrase(congratulation.days)). \
            Still feeling tired? A solid night tonight could help you build on that.
            """
        }

        if motivatorIsCatchable {
            return """
            You're \(aheadPhrase) ahead over the last \(dayCountPhrase(congratulation.days))! \
            Still feeling tired? You're a bit behind over the last \(motivatorDays) — about \(behindPhrase). \
            Want to try make up for it tonight?
            """
        }

        let partialCatchUp = partialCatchUpClause(
            debtHours: motivator.behindHours,
            goalHours: goalHours,
            maxSleepHours: maxSleepHours,
            capitalizeBut: false
        )

        return """
        You're \(aheadPhrase) ahead over the last \(dayCountPhrase(congratulation.days))! \
        Still feeling tired? You're \(behindPhrase) behind over the last \(motivatorDays) — \
        \(partialCatchUp)
        """
    }

    private static func aheadNarrative(
        window: SleepWindowBalance,
        goalIncrease: SuggestedGoalIncrease?
    ) -> String {
        let aheadPhrase = formatHoursNaturally(window.aheadHours)
        guard goalIncrease != nil else {
            return "You're \(aheadPhrase) ahead over the last \(dayCountPhrase(window.days)). Nice work — keep it up!"
        }

        return """
        You're \(aheadPhrase) ahead over the last \(dayCountPhrase(window.days)) and caught up every way \
        we look at it. You're clearing your goal with room to spare — ready to aim a little higher?
        """
    }

    private static func behindNarrative(
        window: SleepWindowBalance,
        isCatchable: Bool,
        goalHours: Double,
        maxSleepHours: Double
    ) -> String {
        let behindPhrase = formatHoursNaturally(window.behindHours)
        if isCatchable {
            return "You're \(behindPhrase) behind over the last \(dayCountPhrase(window.days)). Want to try make up for it tonight?"
        }

        let partialCatchUp = partialCatchUpClause(
            debtHours: window.behindHours,
            goalHours: goalHours,
            maxSleepHours: maxSleepHours
        )

        return """
        You're \(behindPhrase) behind over the last \(dayCountPhrase(window.days)). \
        \(partialCatchUp)
        """
    }

    private static func partialCatchUpClause(
        debtHours: Double,
        goalHours: Double,
        maxSleepHours: Double,
        capitalizeBut: Bool = true
    ) -> String {
        let extraTonight = max(0, maxSleepHours - goalHours)
        let but = capitalizeBut ? "But" : "but"
        guard extraTonight > 0.01, debtHours > 0 else {
            return "\(but) aim for as much sleep as you can tonight."
        }

        let extraPhrase = formatHoursNaturally(extraTonight)
        let fraction = ProgressFractionFormatter.progressPhrase(
            debtHours: debtHours,
            extraSleepHours: extraTonight
        )

        if fraction == "really close" {
            return "\(but) you can reasonably add \(extraPhrase), getting you really close."
        }

        return "\(but) you can reasonably add \(extraPhrase), getting you \(fraction) there."
    }

    static func dayCountPhrase(_ days: Int) -> String {
        days == 1 ? "day" : "\(days) days"
    }

    static func formatHoursNaturally(_ hours: Double) -> String {
        let totalMinutes = max(1, Int((abs(hours) * 60).rounded()))
        let wholeHours = totalMinutes / 60
        let minutes = totalMinutes % 60

        switch (wholeHours, minutes) {
        case (0, let m):
            return "\(m) minute\(m == 1 ? "" : "s")"
        case (let h, 0):
            return "\(h) hour\(h == 1 ? "" : "s")"
        case (let h, let m):
            return "\(h) hour\(h == 1 ? "" : "s") \(m) minute\(m == 1 ? "" : "s")"
        }
    }
}
