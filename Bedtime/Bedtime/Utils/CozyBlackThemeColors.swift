//
//  CozyBlackThemeColors.swift
//  Bedtime
//

import SwiftUI

/// The cozy palette with a true-black background and near-black cards in dark mode, for
/// OLED displays and users who prefer maximum contrast. Everything but the backgrounds is
/// forwarded to `CozyThemeColors` so the two stay in sync automatically.
struct CozyBlackThemeColors: ThemeColorPalette {
    /// Slightly lighter than pure black so cards stay visible against the black background.
    private static let nearBlackCard: (Double, Double, Double) = (0.110, 0.110, 0.110)

    private let base = CozyThemeColors()

    var accent: Color { base.accent }
    var recentSleep: Color { base.recentSleep }
    var healthKit: Color { base.healthKit }
    var positive: Color { base.positive }
    var negative: Color { base.negative }
    var warning: Color { base.warning }
    var sleepDeep: Color { base.sleepDeep }
    var sleepCore: Color { base.sleepCore }
    var sleepAwake: Color { base.sleepAwake }
    var sleepInBed: Color { base.sleepInBed }

    let background = dynamicColor(light: CozyThemeColors.cream, dark: (0, 0, 0))
    let cardBackground = dynamicColor(light: CozyThemeColors.creamCard, dark: Self.nearBlackCard)
}
