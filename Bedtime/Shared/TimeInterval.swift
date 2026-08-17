//
//  TimeInterval.swift
//  Bedtime
//
//  Created by Greg Bernstein on 8/13/26.
//

import Foundation

extension TimeInterval {

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
