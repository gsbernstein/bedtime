//
//  AppColors.swift
//  Bedtime
//

import SwiftUI

/// Every color the app uses, keyed by the active `AppTheme`. Callers grab an
/// `@Environment(\.appTheme)` and pass it through rather than reading a fixed constant, so
/// switching themes in Settings updates the whole UI without any other code changes.
enum AppColors {
    // MARK: - Accent

    static func accent(_ theme: AppTheme) -> Color {
        switch theme {
        case .system: return .blue
        case .cozy, .cozyBlack: return cozyAccent
        }
    }

    // MARK: - Card accents

    static func bedtime(_ theme: AppTheme) -> Color { accent(theme) }
    static func lastNight(_ theme: AppTheme) -> Color { accent(theme) }

    static func recentSleep(_ theme: AppTheme) -> Color {
        switch theme {
        case .system: return .purple
        case .cozy, .cozyBlack: return cozyRecentSleep
        }
    }

    static func healthKit(_ theme: AppTheme) -> Color {
        switch theme {
        case .system: return .red
        case .cozy, .cozyBlack: return cozyHealthKit
        }
    }

    // MARK: - Status

    static func positive(_ theme: AppTheme) -> Color {
        switch theme {
        case .system: return .green
        case .cozy, .cozyBlack: return cozyPositive
        }
    }

    static func negative(_ theme: AppTheme) -> Color {
        switch theme {
        case .system: return .red
        case .cozy, .cozyBlack: return cozyNegative
        }
    }

    static func warning(_ theme: AppTheme) -> Color {
        switch theme {
        case .system: return .orange
        case .cozy, .cozyBlack: return cozyWarning
        }
    }

    // MARK: - Sleep stages

    static func sleepDeep(_ theme: AppTheme) -> Color {
        switch theme {
        case .system: return .blue
        case .cozy, .cozyBlack: return cozySleepDeep
        }
    }

    static func sleepREM(_ theme: AppTheme) -> Color {
        switch theme {
        case .system: return .purple
        case .cozy, .cozyBlack: return recentSleep(theme)
        }
    }

    static func sleepCore(_ theme: AppTheme) -> Color {
        switch theme {
        case .system: return .indigo
        case .cozy, .cozyBlack: return cozySleepCore
        }
    }

    static func sleepAwake(_ theme: AppTheme) -> Color {
        switch theme {
        case .system: return .orange
        case .cozy, .cozyBlack: return cozySleepAwake
        }
    }

    static func sleepInBed(_ theme: AppTheme) -> Color {
        switch theme {
        case .system: return .gray
        case .cozy, .cozyBlack: return cozySleepInBed
        }
    }

    // MARK: - Backgrounds

    static func background(_ theme: AppTheme) -> Color {
        switch theme {
        case .system:
            return dynamicColor(light: .secondarySystemBackground, dark: .systemBackground)
        case .cozy:
            return cozyColor(light: creamBackground, dark: cozyDarkBackground)
        case .cozyBlack:
            return cozyColor(light: creamBackground, dark: pureBlack)
        }
    }

    static func cardBackground(_ theme: AppTheme) -> Color {
        switch theme {
        case .system:
            return dynamicColor(light: .systemBackground, dark: .tertiarySystemBackground)
        case .cozy:
            return cozyColor(light: creamCardBackground, dark: cozyDarkCardBackground)
        case .cozyBlack:
            return cozyColor(light: creamCardBackground, dark: nearBlackCardBackground)
        }
    }

    // MARK: - Cozy palette

    /// Warm coral from the app icon (#f8987c).
    private static let cozyAccent = cozyColor(light: (0.973, 0.596, 0.486), dark: (0.961, 0.659, 0.573))

    /// Dusty mauve brown from the icon (#9b786d).
    private static let cozyRecentSleep = cozyColor(light: (0.608, 0.471, 0.427), dark: (0.729, 0.588, 0.533))

    /// Soft terracotta rose for health prompts.
    private static let cozyHealthKit = cozyColor(light: (0.788, 0.482, 0.420), dark: (0.878, 0.573, 0.506))

    /// Muted sage green.
    private static let cozyPositive = cozyColor(light: (0.541, 0.671, 0.478), dark: (0.620, 0.749, 0.557))

    /// Warm terracotta red.
    private static let cozyNegative = cozyColor(light: (0.788, 0.482, 0.420), dark: (0.878, 0.573, 0.506))

    /// Soft amber peach.
    private static let cozyWarning = cozyColor(light: (0.910, 0.620, 0.451), dark: (0.941, 0.698, 0.541))

    /// Deep warm brown (#826056).
    private static let cozySleepDeep = cozyColor(light: (0.510, 0.376, 0.337), dark: (0.639, 0.502, 0.463))

    /// Plum brown for core sleep.
    private static let cozySleepCore = cozyColor(light: (0.478, 0.345, 0.380), dark: (0.588, 0.455, 0.490))

    private static let cozySleepAwake = cozyColor(light: (0.969, 0.592, 0.482), dark: (0.980, 0.667, 0.573))

    /// Warm taupe (#584744).
    private static let cozySleepInBed = cozyColor(light: (0.345, 0.278, 0.267), dark: (0.478, 0.404, 0.384))

    /// Cream, shared by both cozy variants in light mode.
    private static let creamBackground: (Double, Double, Double) = (0.984, 0.957, 0.929)
    private static let creamCardBackground: (Double, Double, Double) = (0.992, 0.973, 0.953)

    /// Dark warm brown, used behind cards in the standard cozy theme's dark mode.
    private static let cozyDarkBackground: (Double, Double, Double) = (0.165, 0.129, 0.118)
    private static let cozyDarkCardBackground: (Double, Double, Double) = (0.239, 0.196, 0.173)

    /// True black, used behind cards in the cozy-black theme's dark mode.
    private static let pureBlack: (Double, Double, Double) = (0, 0, 0)
    /// Slightly lighter than pure black so cards stay visible against the black background.
    private static let nearBlackCardBackground: (Double, Double, Double) = (0.110, 0.110, 0.110)

    private static func cozyColor(light: (Double, Double, Double), dark: (Double, Double, Double)) -> Color {
        Color(
            uiColor: UIColor { traits in
                let rgb = traits.userInterfaceStyle == .dark ? dark : light
                return UIColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
            }
        )
    }

    private static func dynamicColor(light: UIColor, dark: UIColor) -> Color {
        Color(
            uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark ? dark : light
            }
        )
    }
}
