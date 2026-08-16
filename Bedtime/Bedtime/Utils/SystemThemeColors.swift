//
//  SystemThemeColors.swift
//  Bedtime
//

import SwiftUI

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
