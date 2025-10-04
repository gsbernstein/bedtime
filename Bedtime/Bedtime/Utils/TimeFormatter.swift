//
//  TimeFormatter.swift
//  Bedtime
//
//  Created by Greg on 10/4/25.
//

import Foundation

struct TimeFormatter {
    static func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        return "\(hours):\(String(format: "%02d", minutes))"
    }
}
