//
//  SleepDay.swift
//  Bedtime
//

import Foundation

/// The calendar day a stretch of sleep is credited to.
///
/// Sleep that crosses midnight belongs to the day it ends on, so sleep days are cut
/// at 6pm rather than midnight: shifting an instant forward six hours and taking that
/// day's start files an evening bedtime and the morning it leads into under one day.
enum SleepDay {
    /// How far an instant is shifted before its day is taken, which puts the boundary
    /// between one sleep day and the next at 6pm.
    static let shift: TimeInterval = 6 * 60 * 60

    /// The sleep day `date` belongs to. Applied to a session's midpoint this buckets
    /// the session; applied to `now` it gives the sleep day currently underway.
    static func containing(_ date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date.addingTimeInterval(shift))
    }

    /// The sleep day before `day`.
    static func previous(before day: Date, calendar: Calendar = .current) -> Date? {
        calendar.date(byAdding: .day, value: -1, to: day)
    }
}
