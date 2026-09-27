//
//  TimeFormatter.swift
//  Bedtime
//
//  Created by Greg on 10/4/25.
//

import Foundation
import SwiftUI

/// How durations are shown throughout the app.
enum DurationDisplayStyle: String, Codable, CaseIterable, Identifiable {
    /// Compact hours and minutes, e.g. "5h 6m".
    case hoursAndMinutes
    /// Decimal hours, e.g. "5.1h" (or "7.25h" when more precision is needed).
    case decimal

    var id: String { rawValue }

    var settingsLabel: String {
        switch self {
        case .hoursAndMinutes: return "Hours & minutes"
        case .decimal: return "Decimal hours"
        }
    }

    var settingsExample: String {
        switch self {
        case .hoursAndMinutes: return "5h 6m"
        case .decimal: return "5.1h"
        }
    }
}

private struct DurationDisplayStyleKey: EnvironmentKey {
    static let defaultValue: DurationDisplayStyle = .hoursAndMinutes
}

extension EnvironmentValues {
    var durationDisplayStyle: DurationDisplayStyle {
        get { self[DurationDisplayStyleKey.self] }
        set { self[DurationDisplayStyleKey.self] = newValue }
    }
}

struct TimeFormatter {
    /// Clock times are always 12-hour with a meridiem, e.g. "11:10 PM".
    static func formatTimeOfDay(_ date: Date) -> String {
        timeOfDayFormatter.string(from: date)
    }

    /// Formats a duration from a `TimeInterval` (seconds).
    static func formatDuration(
        _ duration: TimeInterval,
        style: DurationDisplayStyle,
        maxFractionDigits: Int = 1
    ) -> String {
        formatHours(duration / 3600.0, style: style, maxFractionDigits: maxFractionDigits)
    }

    /// Formats a duration expressed in hours.
    /// - Parameter maxFractionDigits: Used only for `.decimal`. Measured values use 1;
    ///   quarter-hour goals may need 2 (e.g. "7.25h").
    static func formatHours(
        _ hours: Double,
        style: DurationDisplayStyle,
        maxFractionDigits: Int = 1
    ) -> String {
        switch style {
        case .hoursAndMinutes:
            return formatHoursAndMinutes(hours)
        case .decimal:
            return formatDecimalHours(hours, maxFractionDigits: maxFractionDigits)
        }
    }

    // MARK: - Private

    private static let timeOfDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    private static func formatHoursAndMinutes(_ hours: Double) -> String {
        let totalMinutes = Int((abs(hours) * 60).rounded())
        let wholeHours = totalMinutes / 60
        let minutes = totalMinutes % 60

        switch (wholeHours, minutes) {
        case (0, 0):
            return "0m"
        case (0, let m):
            return "\(m)m"
        case (let h, 0):
            return "\(h)h"
        case (let h, let m):
            return "\(h)h \(m)m"
        }
    }

    private static func formatDecimalHours(_ hours: Double, maxFractionDigits: Int) -> String {
        let value = abs(hours)
        let digits = max(0, maxFractionDigits)

        if digits == 0 {
            return "\(Int(value.rounded()))h"
        }

        // Fixed precision for the common 1-decimal case ("5.1h"); for goals, allow
        // up to two decimals and trim trailing zeros ("7.25h", "8.5h", "8h").
        if digits == 1 {
            return String(format: "%.1fh", value)
        }

        var formatted = String(format: "%.\(digits)f", value)
        if formatted.contains(".") {
            while formatted.last == "0" {
                formatted.removeLast()
            }
            if formatted.last == "." {
                formatted.removeLast()
            }
        }
        return "\(formatted)h"
    }
}
