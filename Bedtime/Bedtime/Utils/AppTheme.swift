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
    /// Warm palette inspired by the app icon: coral accents, cream backgrounds, dusty
    /// mauve/brown sleep-stage colors.
    case cozy
    /// The cozy palette with a true-black background and cards in dark mode, for OLED
    /// displays and users who prefer maximum contrast.
    case cozyBlack

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .cozy: return "Cozy"
        case .cozyBlack: return "Cozy (Black)"
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
