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
    /// Hours under goal that still count as close enough to avoid a red status color.
    static let sleepGoalGraceHours: Double = 0.5

    static func sleepGoalColor(difference: Double, graceColor: Color) -> Color {
        if difference >= 0 { return .green }
        if difference < -sleepGoalGraceHours { return .red }
        return graceColor
    }

    static func sleepDurationColor(hours: Double, goal: Double, graceColor: Color) -> Color {
        sleepGoalColor(difference: hours - goal, graceColor: graceColor)
    }
}
