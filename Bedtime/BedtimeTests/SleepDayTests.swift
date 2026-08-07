//
//  SleepDayTests.swift
//  BedtimeTests
//

import Foundation
import Testing

@testable import Bedger

/// A fixed zone keeps the 6pm boundary and the DST cases deterministic wherever these
/// run. `SleepDay` takes a calendar for exactly this reason.
private let testCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/New_York")!
    return calendar
}()

private func moment(_ month: Int, _ dayOfMonth: Int, hour: Int, minute: Int = 0) -> Date {
    testCalendar.date(
        from: DateComponents(year: 2025, month: month, day: dayOfMonth, hour: hour, minute: minute)
    )!
}

/// The bucket key for a calendar day, which is that day's midnight.
private func sleepDay(_ month: Int, _ dayOfMonth: Int) -> Date {
    testCalendar.startOfDay(for: moment(month, dayOfMonth, hour: 12))
}

@Suite("Sleep day boundaries")
struct SleepDayBoundaryTests {
    @Test("A sleep day runs from 6pm to 6pm")
    func sleepDayCutAtSixPM() {
        #expect(SleepDay.containing(moment(6, 10, hour: 17, minute: 59), calendar: testCalendar) == sleepDay(6, 10))
        #expect(SleepDay.containing(moment(6, 10, hour: 18), calendar: testCalendar) == sleepDay(6, 11))
    }

    @Test("An evening bedtime and the morning it leads into share a day")
    func overnightSleepSharesOneDay() {
        let bedtime = SleepDay.containing(moment(6, 10, hour: 23), calendar: testCalendar)
        let wake = SleepDay.containing(moment(6, 11, hour: 7), calendar: testCalendar)

        #expect(bedtime == sleepDay(6, 11))
        #expect(wake == sleepDay(6, 11))
    }

    @Test("Sleep is credited to the day it ends on")
    func sleepCreditedToWakeDay() {
        // 10pm–2am: the midpoint lands at midnight, which belongs to the second day.
        let midpoint = moment(6, 11, hour: 0)

        #expect(SleepDay.containing(midpoint, calendar: testCalendar) == sleepDay(6, 11))
    }

    @Test("A night spanning spring forward is credited to the morning")
    func springForwardNight() {
        // 2am jumps to 3am on 9 March 2025, so this night is seven hours long.
        let bedtime = moment(3, 8, hour: 23)
        let wake = moment(3, 9, hour: 7)
        #expect(wake.timeIntervalSince(bedtime) == 7 * 3600)

        let midpoint = bedtime.addingTimeInterval(wake.timeIntervalSince(bedtime) / 2)

        #expect(SleepDay.containing(midpoint, calendar: testCalendar) == sleepDay(3, 9))
    }

    @Test("A night spanning fall back is credited to the morning")
    func fallBackNight() {
        // 2am repeats on 2 November 2025, so this night is nine hours long.
        let bedtime = moment(11, 1, hour: 23)
        let wake = moment(11, 2, hour: 7)
        #expect(wake.timeIntervalSince(bedtime) == 9 * 3600)

        let midpoint = bedtime.addingTimeInterval(wake.timeIntervalSince(bedtime) / 2)

        #expect(SleepDay.containing(midpoint, calendar: testCalendar) == sleepDay(11, 2))
    }
}

@Suite("Featured night selection")
struct FeaturedNightTests {
    /// Stands in for a night's sessions; only the presence of a key matters here.
    private let recorded = ["session"]

    @Test("Waking in the small hours features tonight's sleep so far")
    func smallHoursPrefersNightUnderway() {
        let nights = [sleepDay(6, 10): recorded, sleepDay(6, 11): recorded]

        let featured = SleepDay.featured(
            in: nights,
            now: moment(6, 11, hour: 2, minute: 30),
            calendar: testCalendar
        )

        #expect(featured == sleepDay(6, 11))
    }

    @Test("The small hours fall back when tonight has nothing recorded yet")
    func smallHoursFallsBack() {
        let nights = [sleepDay(6, 10): recorded]

        let featured = SleepDay.featured(
            in: nights,
            now: moment(6, 11, hour: 2, minute: 30),
            calendar: testCalendar
        )

        #expect(featured == sleepDay(6, 10))
    }

    @Test("Daytime features the night that just ended")
    func daytimeFeaturesCompletedNight() {
        let nights = [sleepDay(6, 11): recorded]

        let featured = SleepDay.featured(
            in: nights,
            now: moment(6, 11, hour: 12),
            calendar: testCalendar
        )

        #expect(featured == sleepDay(6, 11))
    }

    @Test("Daytime with no sleep recorded stays empty rather than falling back")
    func daytimeDoesNotFallBack() {
        let nights = [sleepDay(6, 10): recorded]

        let featured = SleepDay.featured(
            in: nights,
            now: moment(6, 11, hour: 12),
            calendar: testCalendar
        )

        // Selects the empty night, leaving the no-data state free to prompt a sync.
        #expect(featured == sleepDay(6, 11))
        #expect(nights[featured] == nil)
    }

    @Test("Evening doesn't resurrect last night")
    func eveningDoesNotFallBack() {
        let nights = [sleepDay(6, 11): recorded]

        let featured = SleepDay.featured(
            in: nights,
            now: moment(6, 11, hour: 23),
            calendar: testCalendar
        )

        #expect(featured == sleepDay(6, 12))
        #expect(nights[featured] == nil)
    }

    @Test("An evening nap counts as the night underway")
    func eveningNapIsTonight() {
        // A 9–11pm nap on the 11th has a midpoint of 10pm, so it buckets to the 12th.
        let nights = [sleepDay(6, 11): recorded, sleepDay(6, 12): recorded]

        let featured = SleepDay.featured(
            in: nights,
            now: moment(6, 11, hour: 23),
            calendar: testCalendar
        )

        #expect(featured == sleepDay(6, 12))
    }

    @Test("Falling back stops at the small hours cutoff")
    func fallbackStopsAtCutoff() {
        let nights = [sleepDay(6, 10): recorded]
        let justBefore = SleepDay.featured(
            in: nights,
            now: moment(6, 11, hour: Constants.smallHoursEndHour - 1, minute: 59),
            calendar: testCalendar
        )
        let atCutoff = SleepDay.featured(
            in: nights,
            now: moment(6, 11, hour: Constants.smallHoursEndHour),
            calendar: testCalendar
        )

        #expect(justBefore == sleepDay(6, 10))
        #expect(atCutoff == sleepDay(6, 11))
    }
}
