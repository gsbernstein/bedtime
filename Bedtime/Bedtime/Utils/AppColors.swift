//
//  AppColors.swift
//  Bedtime
//

import SwiftUI

enum AppColors {
    // MARK: - Accent

    /// Warm coral from the app icon (#f8987c).
    static let accent = cozyColor(light: (0.973, 0.596, 0.486), dark: (0.961, 0.659, 0.573))

    // MARK: - Card accents

    static let bedtime = accent
    static let lastNight = accent

    /// Dusty mauve brown from the icon (#9b786d).
    static let recentSleep = cozyColor(light: (0.608, 0.471, 0.427), dark: (0.729, 0.588, 0.533))

    /// Soft terracotta rose for health prompts.
    static let healthKit = cozyColor(light: (0.788, 0.482, 0.420), dark: (0.878, 0.573, 0.506))

    // MARK: - Status

    /// Muted sage green.
    static let positive = cozyColor(light: (0.541, 0.671, 0.478), dark: (0.620, 0.749, 0.557))

    /// Warm terracotta red.
    static let negative = cozyColor(light: (0.788, 0.482, 0.420), dark: (0.878, 0.573, 0.506))

    /// Soft amber peach.
    static let warning = cozyColor(light: (0.910, 0.620, 0.451), dark: (0.941, 0.698, 0.541))

    // MARK: - Sleep stages

    /// Deep warm brown (#826056).
    static let sleepDeep = cozyColor(light: (0.510, 0.376, 0.337), dark: (0.639, 0.502, 0.463))

    static let sleepREM = recentSleep

    /// Plum brown for core sleep.
    static let sleepCore = cozyColor(light: (0.478, 0.345, 0.380), dark: (0.588, 0.455, 0.490))

    static let sleepAwake = cozyColor(light: (0.969, 0.592, 0.482), dark: (0.980, 0.667, 0.573))

    /// Warm taupe (#584744).
    static let sleepInBed = cozyColor(light: (0.345, 0.278, 0.267), dark: (0.478, 0.404, 0.384))

    private static func cozyColor(light: (Double, Double, Double), dark: (Double, Double, Double)) -> Color {
        Color(
            uiColor: UIColor { traits in
                let rgb = traits.userInterfaceStyle == .dark ? dark : light
                return UIColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
            }
        )
    }
}
