//
//  CozyThemeColors.swift
//  Bedtime
//

import SwiftUI

/// Warm palette inspired by the app icon: a dusty slate blue accent lifted from the badger's
/// sleep cap, cream backgrounds in light mode, a true-black background with near-black cards
/// in dark mode, and a spread of warm sleep-stage colors (plum, brown, rose, orange, taupe)
/// chosen to stay distinguishable from one another and from the blue accent.
///
/// Every color here comes from the asset catalog (`Assets.xcassets/CozyColors/*.colorset`)
/// rather than inline RGB values, so the palette can be tweaked visually in Xcode's color
/// picker without touching code.
struct CozyThemeColors: ThemeColorPalette {
    let accent = Color.cozyAccent
    let recentSleep = Color.cozyRecentSleep
    let healthKit = Color.cozyHealthKit
    let positive = Color.cozyPositive
    let negative = Color.cozyNegative
    let warning = Color.cozyWarning
    let sleepDeep = Color.cozySleepDeep
    let sleepCore = Color.cozySleepCore
    let sleepAwake = Color.cozySleepAwake
    let sleepInBed = Color.cozySleepInBed
    let background = Color.cozyBackground
    let cardBackground = Color.cozyCardBackground
    let primary = Color.cozyPrimary
    let secondary = Color.cozySecondary
}
