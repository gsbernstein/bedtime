//
//  UserPreferences.swift
//  Bedtime
//
//  Created by Greg on 10/4/25.
//

import Combine
import Foundation
import SwiftUI

@MainActor
final class UserPreferences: ObservableObject {
    enum Keys {
        static let sleepGoalHours = "userPreferences.sleepGoalHours"
        static let wakeTime = "userPreferences.wakeTime"
        static let sleepBankDays = "userPreferences.sleepBankDays"
        static let earliestReasonableBedtime = "userPreferences.earliestReasonableBedtime"
        static let useDecimalDurations = "userPreferences.useDecimalDurations"
        static let hideSleepBankChart = "userPreferences.hideSleepBankChart"
        static let migratedFromSwiftData = "userPreferences.migratedFromSwiftData"

        static let all = [
            sleepGoalHours,
            wakeTime,
            sleepBankDays,
            earliestReasonableBedtime,
            useDecimalDurations,
            hideSleepBankChart,
        ]
    }

    private let defaults: UserDefaults
    private let shouldMigrateLegacyStore: Bool

    @AppStorage var sleepGoalHours: Double {
        willSet { objectWillChange.send() }
    }

    @AppStorage private var wakeTimeTimestamp: Double? {
        willSet { objectWillChange.send() }
    }

    @AppStorage var sleepBankDays: Int {
        willSet { objectWillChange.send() }
    }

    @AppStorage private var earliestBedtimeTimestamp: Double? {
        willSet { objectWillChange.send() }
    }

    /// When true, durations use decimal hours ("5.1h"); otherwise "5h 6m".
    @AppStorage var useDecimalDurations: Bool {
        willSet { objectWillChange.send() }
    }

    /// When true, the sleep balance waterfall chart is hidden from the Sleep Balance card.
    @AppStorage var hideSleepBankChart: Bool {
        willSet { objectWillChange.send() }
    }

    var wakeTime: Date {
        get {
            wakeTimeTimestamp.map(Date.init(timeIntervalSinceReferenceDate:))
                ?? Calendar.current.date(from: DateComponents(hour: 7, minute: 0))
                ?? Date()
        }
        set {
            wakeTimeTimestamp = newValue.timeIntervalSinceReferenceDate
        }
    }

    var earliestReasonableBedtime: Date {
        get {
            earliestBedtimeTimestamp.map(Date.init(timeIntervalSinceReferenceDate:))
                ?? Calendar.current.date(from: DateComponents(hour: 21, minute: 0))
                ?? Date()
        }
        set {
            earliestBedtimeTimestamp = newValue.timeIntervalSinceReferenceDate
        }
    }

    var durationDisplayStyle: DurationDisplayStyle {
        useDecimalDurations ? .decimal : .hoursAndMinutes
    }

    /// Convenience accessor for the nominal sleep-window length from this
    /// schedule's stored times. Now-aware/DST math lives in `SleepWindow`.
    var nominalMaxSleepHours: Double {
        SleepWindow.nominalWindowHours(earliestBedtime: earliestReasonableBedtime, wakeTime: wakeTime)
    }

    init(defaults: UserDefaults = .standard, migrateLegacyStore: Bool = true) {
        self.defaults = defaults
        self.shouldMigrateLegacyStore = migrateLegacyStore

        if migrateLegacyStore {
            LegacyPreferencesMigration.migrateIfNeeded(into: defaults)
        }

        _sleepGoalHours = AppStorage(wrappedValue: 8.0, Keys.sleepGoalHours, store: defaults)
        _wakeTimeTimestamp = AppStorage(Keys.wakeTime, store: defaults)
        _sleepBankDays = AppStorage(wrappedValue: 7, Keys.sleepBankDays, store: defaults)
        _earliestBedtimeTimestamp = AppStorage(Keys.earliestReasonableBedtime, store: defaults)
        _useDecimalDurations = AppStorage(wrappedValue: false, Keys.useDecimalDurations, store: defaults)
        _hideSleepBankChart = AppStorage(wrappedValue: false, Keys.hideSleepBankChart, store: defaults)
    }

    /// Isolated preferences instance for SwiftUI previews that never reads or mutates `UserDefaults.standard`.
    static func preview(
        sleepGoalHours: Double? = nil,
        wakeTime: Date? = nil,
        sleepBankDays: Int? = nil,
        earliestReasonableBedtime: Date? = nil,
        useDecimalDurations: Bool? = nil,
        hideSleepBankChart: Bool? = nil
    ) -> UserPreferences {
        let previewDefaults = UserDefaults(suiteName: "bedtime.preview.\(UUID().uuidString)")!
        let prefs = UserPreferences(defaults: previewDefaults, migrateLegacyStore: false)
        if let sleepGoalHours { prefs.sleepGoalHours = sleepGoalHours }
        if let wakeTime { prefs.wakeTime = wakeTime }
        if let sleepBankDays { prefs.sleepBankDays = sleepBankDays }
        if let earliestReasonableBedtime { prefs.earliestReasonableBedtime = earliestReasonableBedtime }
        if let useDecimalDurations { prefs.useDecimalDurations = useDecimalDurations }
        if let hideSleepBankChart { prefs.hideSleepBankChart = hideSleepBankChart }
        return prefs
    }

    /// Reloads persisted settings (and retries legacy migration if needed, e.g. after first unlock).
    func reload() {
        if shouldMigrateLegacyStore {
            LegacyPreferencesMigration.migrateIfNeeded(into: defaults)
        }
        objectWillChange.send()
    }
}
