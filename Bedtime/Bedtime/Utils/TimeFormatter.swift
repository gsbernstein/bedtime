//
//  TimeFormatter.swift
//  Bedtime
//
//  Created by Greg on 10/4/25.
//

import Foundation

struct TimeFormatter {
    static func formatDuration(_ duration: TimeInterval) -> String {
        let totalMinutes = Int((duration / 60).rounded())
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return "\(hours):\(String(format: "%02d", minutes))"
    }
}
