//
//  TimeInterval.swift
//  Bedtime
//
//  Created by Greg Bernstein on 8/13/26.
//

import Foundation

nonisolated extension TimeInterval {

    static func minutes(_ minutes: Int) -> TimeInterval {
        TimeInterval(60 * minutes)
    }

    static func minutes(_ minutes: Double) -> TimeInterval {
        TimeInterval(60 * minutes)
    }

    static func hours(_ hours: Int) -> TimeInterval {
        TimeInterval(60 * 60 * hours)
    }

    static func hours(_ hours: Double) -> TimeInterval {
        TimeInterval(60 * 60 * hours)
    }

    static func days(_ days: Int) -> TimeInterval {
        TimeInterval(24 * 60 * 60 * days)
    }

}

nonisolated extension Calendar {

    /// Adds a time interval by calendar arithmetic rather than raw elapsed
    /// seconds, so a wind-down window or lead time still lands on the same
    /// wall-clock offset across a DST transition. Falls back to
    /// `addingTimeInterval` on the rare date this can't be resolved.
    func date(byAdding interval: TimeInterval, to date: Date) -> Date {
        let seconds = Int(interval.rounded())
        return self.date(byAdding: .second, value: seconds, to: date) ?? date.addingTimeInterval(interval)
    }

}
