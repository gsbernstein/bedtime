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
}

enum SleepInsightsEngine {
    /// Lookback durations scanned for local minima / motivators (matches Settings range).
    static let windowRange = 3...14

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

        guard let message = buildNarrative(
            congratulation: congratulation,
            motivator: motivator,
            goalHours: goalHours,
            maxSleepHours: maxSleepHours
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
            motivatorIsCatchable: motivatorIsCatchable
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

    /// Among local minima with a non-negative balance, pick the longest lookback.
    /// Falls back to the longest non-negative window when no local minimum qualifies.
    static func selectCongratulation(from snapshots: [SleepWindowBalance]) -> SleepWindowBalance? {
        let nonNegativeMinima = localMinima(in: snapshots).filter(\.isAhead)
        if let longestMinimum = nonNegativeMinima.max(by: { $0.days < $1.days }) {
            return longestMinimum
        }
        return snapshots.filter(\.isAhead).max(by: { $0.days < $1.days })
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

    /// Whether tonight's recommended sleep duration can fully cover this window's debt.
    static func isCatchableInOneNight(
        balance: Double,
        goalHours: Double,
        maxSleepHours: Double
    ) -> Bool {
        let sleepNeeded = goalHours - balance
        return sleepNeeded <= maxSleepHours
    }

    /// A point lower than both neighbors (plateaus count as minima).
    static func localMinima(in snapshots: [SleepWindowBalance]) -> [SleepWindowBalance] {
        guard !snapshots.isEmpty else { return [] }
        guard snapshots.count > 1 else { return snapshots }

        return snapshots.enumerated().compactMap { index, snapshot in
            let previous = index > 0 ? snapshots[index - 1].balance : .infinity
            let next = index < snapshots.count - 1 ? snapshots[index + 1].balance : .infinity
            return snapshot.balance <= previous && snapshot.balance <= next ? snapshot : nil
        }
    }

    // MARK: - Narrative

    static func buildNarrative(
        congratulation: SleepWindowBalance?,
        motivator: SleepWindowBalance?,
        goalHours: Double,
        maxSleepHours: Double
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
            return aheadNarrative(window: congrats)

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

    private static func aheadNarrative(window: SleepWindowBalance) -> String {
        let aheadPhrase = formatHoursNaturally(window.aheadHours)
        return "You're \(aheadPhrase) ahead over the last \(dayCountPhrase(window.days)). Nice work — keep it up!"
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
