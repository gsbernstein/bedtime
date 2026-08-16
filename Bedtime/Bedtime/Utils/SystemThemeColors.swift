//
//  SystemThemeColors.swift
//  Bedtime
//

import SwiftUI

/// The original default iOS system colors, exactly as they were before the cozy palette
/// existed (see the app's git history for the extraction commit that predates it).
struct SystemThemeColors: ThemeColorPalette {
    let accent = Color.blue
    let recentSleep = Color.purple
    let healthKit = Color.red
    let positive = Color.green
    let negative = Color.red
    let warning = Color.orange
    let sleepDeep = Color.blue
    let sleepCore = Color.indigo
    let sleepAwake = Color.orange
    let sleepInBed = Color.gray
    let background = dynamicColor(light: .secondarySystemBackground, dark: .systemBackground)
    let cardBackground = dynamicColor(light: .systemBackground, dark: .tertiarySystemBackground)
    let primary = Color.primary
    let secondary = Color.secondary
}
