//
//  AppTheme.swift
//  Bedtime
//

import SwiftUI

/// The visual theme the app renders with. Stored on `UserPreferences` and threaded through
/// the view hierarchy via `EnvironmentValues.appTheme` so every color lookup can react to it.
enum AppTheme: String, CaseIterable, Identifiable, Codable {
    /// The original look: default iOS system colors and backgrounds.
    case system
    /// Warm palette inspired by the app icon: a dusty blue accent from the sleep cap, cream
    /// backgrounds, and a distinguishable spread of warm sleep-stage colors.
    case cozy

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .cozy: return "Cozy"
        }
    }

    /// The concrete color palette for this theme. Call sites read through this rather than
    /// switching on the theme themselves.
    var colors: any ThemeColorPalette {
        switch self {
        case .system: return SystemThemeColors()
        case .cozy: return CozyThemeColors()
        }
    }
}

private struct AppThemeKey: EnvironmentKey {
    static let defaultValue: AppTheme = .cozy
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}
