//
//  CozyThemeColors.swift
//  Bedtime
//

import SwiftUI

/// Warm palette inspired by the app icon: coral accents, cream backgrounds, dusty
/// mauve/brown sleep-stage colors.
struct CozyThemeColors: ThemeColorPalette {
    /// Cream, shared with `CozyBlackThemeColors` in light mode.
    static let cream: (Double, Double, Double) = (0.984, 0.957, 0.929)
    static let creamCard: (Double, Double, Double) = (0.992, 0.973, 0.953)

    /// Dark warm brown, used behind cards in dark mode.
    private static let darkBrown: (Double, Double, Double) = (0.165, 0.129, 0.118)
    private static let darkBrownCard: (Double, Double, Double) = (0.239, 0.196, 0.173)

    /// Warm coral from the app icon (#f8987c).
    let accent = dynamicColor(light: (0.973, 0.596, 0.486), dark: (0.961, 0.659, 0.573))

    /// Dusty mauve brown from the icon (#9b786d).
    let recentSleep = dynamicColor(light: (0.608, 0.471, 0.427), dark: (0.729, 0.588, 0.533))

    /// Soft terracotta rose for health prompts.
    let healthKit = dynamicColor(light: (0.788, 0.482, 0.420), dark: (0.878, 0.573, 0.506))

    /// Muted sage green.
    let positive = dynamicColor(light: (0.541, 0.671, 0.478), dark: (0.620, 0.749, 0.557))

    /// Warm terracotta red.
    let negative = dynamicColor(light: (0.788, 0.482, 0.420), dark: (0.878, 0.573, 0.506))

    /// Soft amber peach.
    let warning = dynamicColor(light: (0.910, 0.620, 0.451), dark: (0.941, 0.698, 0.541))

    /// Deep warm brown (#826056).
    let sleepDeep = dynamicColor(light: (0.510, 0.376, 0.337), dark: (0.639, 0.502, 0.463))

    /// Plum brown for core sleep.
    let sleepCore = dynamicColor(light: (0.478, 0.345, 0.380), dark: (0.588, 0.455, 0.490))

    let sleepAwake = dynamicColor(light: (0.969, 0.592, 0.482), dark: (0.980, 0.667, 0.573))

    /// Warm taupe (#584744).
    let sleepInBed = dynamicColor(light: (0.345, 0.278, 0.267), dark: (0.478, 0.404, 0.384))

    let background = dynamicColor(light: CozyThemeColors.cream, dark: (0, 0, 0))
    let cardBackground = dynamicColor(light: CozyThemeColors.creamCard, dark: Self.creamCard)

    let primary: Color = .primary
    let secondary: Color = .secondary
}
