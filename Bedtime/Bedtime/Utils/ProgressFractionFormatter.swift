//
//  ProgressFractionFormatter.swift
//  Bedtime
//
//  Human-readable progress phrases for partial catch-up messaging.
//

import Foundation

enum ProgressFractionFormatter {
    /// Describes how far extra sleep tonight gets you toward clearing `debtHours`.
    static func progressPhrase(debtHours: Double, extraSleepHours: Double) -> String {
        guard debtHours > 0, extraSleepHours > 0 else {
            return "a little closer"
        }

        let progress = min(extraSleepHours / debtHours, 1)
        return progressPhrase(for: progress)
    }

    static func progressPhrase(for progress: Double) -> String {
        let p = min(max(progress, 0), 1)

        if p >= 0.9 {
            return "really close"
        }

        let (numerator, denominator, value) = bestSimpleFraction(for: p)
        let error = abs(p - value)
        let qualifier = error <= 0.07 ? "almost" : "about"

        if denominator == 2 {
            if p > 0.5 {
                return "over halfway"
            }
            return "\(qualifier) halfway"
        }

        return "\(qualifier) \(numerator)/\(denominator) of the way"
    }

    private static func bestSimpleFraction(for progress: Double) -> (numerator: Int, denominator: Int, value: Double) {
        var best: (numerator: Int, denominator: Int, value: Double)?
        var bestScore = Double.infinity

        for denominator in 2...5 {
            for numerator in 1..<denominator {
                let value = Double(numerator) / Double(denominator)
                let error = abs(progress - value)
                // Prefer a tighter fit, then a smaller denominator.
                let score = error + Double(denominator) * 0.001
                if score < bestScore {
                    bestScore = score
                    best = (numerator, denominator, value)
                }
            }
        }

        return best ?? (1, 2, 0.5)
    }
}
