//
//  Constants.swift
//  Bedtime
//
//  Created by Greg on 10/17/25.
//

import Foundation
import SwiftUI

class Constants {
    static let iconWidth: CGFloat = 30
    static let cardHeaderSpacing: CGFloat = 12
    static let sleepHistoryDays = 30
    /// Only suggest opening source apps that have written sleep data within this window.
    static let recentSourceAppLookbackDays = 7
    /// Allowed lookback for sleep-bank / insight window selection (Settings slider, insights, list handle).
    static let sleepBankDaysRange = 3...14
    /// Hours under goal that still count as close enough to avoid a red status color.
    static let sleepGoalGraceHours: Double = 0.5
    /// Selectable nightly sleep goals (Settings slider and the goal editor on the main screen).
    static let sleepGoalHoursRange = 6.0...12.0
    static let sleepGoalStepHours: Double = 0.25

    /// Goal choices as step offsets from the lowest goal, so pickers can tag
    /// options with values that compare exactly.
    static var sleepGoalStepIndices: ClosedRange<Int> {
        let steps = (sleepGoalHoursRange.upperBound - sleepGoalHoursRange.lowerBound) / sleepGoalStepHours
        return 0...Int(steps.rounded())
    }

    static func sleepGoalHours(atStepIndex index: Int) -> Double {
        let clamped = min(max(index, sleepGoalStepIndices.lowerBound), sleepGoalStepIndices.upperBound)
        return sleepGoalHoursRange.lowerBound + Double(clamped) * sleepGoalStepHours
    }

    static func sleepGoalStepIndex(forHours hours: Double) -> Int {
        let steps = (snappedSleepGoalHours(hours) - sleepGoalHoursRange.lowerBound) / sleepGoalStepHours
        return min(max(Int(steps.rounded()), sleepGoalStepIndices.lowerBound), sleepGoalStepIndices.upperBound)
    }

    /// Clamps to the allowed range and snaps to a selectable step.
    static func snappedSleepGoalHours(
        _ hours: Double,
        rounding: FloatingPointRoundingRule = .toNearestOrAwayFromZero
    ) -> Double {
        let clamped = min(max(hours, sleepGoalHoursRange.lowerBound), sleepGoalHoursRange.upperBound)
        let steps = (clamped - sleepGoalHoursRange.lowerBound) / sleepGoalStepHours
        // Values already on a step stay put despite floating-point noise, so
        // rounding down can't shed a whole step (e.g. 8.25h becoming 8h).
        let snapped = abs(steps - steps.rounded()) < 1e-6 ? steps.rounded() : steps.rounded(rounding)
        return sleepGoalHoursRange.lowerBound + snapped * sleepGoalStepHours
    }

    static func sleepGoalColor(difference: Double) -> KeyPath<ThemeColorPalette, Color>? {
        if difference >= 0 { return \.positive }
        if difference < -sleepGoalGraceHours { return \.negative }
        return nil // "grace" coloring when you're pretty close
    }

    static func sleepDurationColor(hours: Double, goal: Double) -> KeyPath<ThemeColorPalette, Color>? {
        sleepGoalColor(difference: hours - goal)
    }
}
