//
//  ThemeColorPalette.swift
//  Bedtime
//

import SwiftUI

/// Every color a theme supplies. `AppTheme.colors` hands back the conforming palette for the
/// active theme, so callers read `theme.colors.accent` (or resolve a `KeyPath<ThemeColorPalette,
/// Color>` picked elsewhere) instead of switching on the theme themselves.
protocol ThemeColorPalette {
    var accent: Color { get }
    var recentSleep: Color { get }
    var healthKit: Color { get }
    var positive: Color { get }
    var negative: Color { get }
    var warning: Color { get }
    var sleepDeep: Color { get }
    var sleepCore: Color { get }
    var sleepAwake: Color { get }
    var sleepInBed: Color { get }
    var background: Color { get }
    var cardBackground: Color { get }
    var primary: Color { get }
    var secondary: Color { get }
}

extension ThemeColorPalette {
    // These card accents and the REM sleep stage are visually just the accent/recent-sleep
    // colors; conforming palettes don't need to restate them.
    var bedtime: Color { accent }
    var lastNight: Color { accent }
    var sleepREM: Color { recentSleep }
}

/// Builds a `Color` that resolves to `light` or `dark` RGB depending on the current
/// `UIUserInterfaceStyle`, the same way asset-catalog colors do.
func dynamicColor(light: (Double, Double, Double), dark: (Double, Double, Double)) -> Color {
    Color(
        uiColor: UIColor { traits in
            let rgb = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
        }
    )
}

/// Builds a `Color` that switches between two `UIColor`s (typically semantic system colors)
/// depending on the current `UIUserInterfaceStyle`.
func dynamicColor(light: UIColor, dark: UIColor) -> Color {
    Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        }
    )
}
