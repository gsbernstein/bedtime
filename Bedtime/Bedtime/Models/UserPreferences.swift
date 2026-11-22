//
//  UserPreferences.swift
//  Bedtime
//
//  Created by Greg on 10/4/25.
//

import Foundation
import Observation
import SQLite3
import UIKit

@MainActor
@Observable
final class UserPreferences {
    private enum Keys {
        static let sleepGoalHours = "userPreferences.sleepGoalHours"
        static let wakeTime = "userPreferences.wakeTime"
        static let sleepBankDays = "userPreferences.sleepBankDays"
        static let earliestReasonableBedtime = "userPreferences.earliestReasonableBedtime"
        static let useDecimalDurations = "userPreferences.useDecimalDurations"
        static let hideSleepBankChart = "userPreferences.hideSleepBankChart"
        static let migratedFromSwiftData = "userPreferences.migratedFromSwiftData"

        static let allPreferenceKeys = [
            sleepGoalHours,
            wakeTime,
            sleepBankDays,
            earliestReasonableBedtime,
            useDecimalDurations,
            hideSleepBankChart,
        ]
    }

    private enum Defaults {
        static let sleepGoalHours: Double = 8.0
        static let sleepBankDays: Int = 7
        static let useDecimalDurations: Bool = false
        static let hideSleepBankChart: Bool = false

        static var wakeTime: Date {
            Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? Date()
        }

        static var earliestReasonableBedtime: Date {
            Calendar.current.date(from: DateComponents(hour: 21, minute: 0)) ?? Date()
        }
    }

    private enum LegacyColumn {
        static let sleepGoalHours = "ZSLEEPGOALHOURS"
        static let wakeTime = "ZWAKETIME"
        static let sleepBankDays = "ZSLEEPBANKDAYS"
        static let earliestReasonableBedtime = "ZEARLIESTREASONABLEBEDTIME"
        static let useDecimalDurations = "ZUSEDECIMALDURATIONS"
        static let hideSleepBankChart = "ZHIDESLEEPBANKCHART"

        static let all = [
            sleepGoalHours,
            wakeTime,
            sleepBankDays,
            earliestReasonableBedtime,
            useDecimalDurations,
            hideSleepBankChart,
        ]
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let shouldMigrateLegacyStore: Bool
    @ObservationIgnored private var isLoading = false

    var sleepGoalHours: Double {
        didSet {
            if !isLoading {
                defaults.set(sleepGoalHours, forKey: Keys.sleepGoalHours)
            }
        }
    }

    var wakeTime: Date {
        didSet {
            if !isLoading {
                defaults.set(wakeTime, forKey: Keys.wakeTime)
            }
        }
    }

    var sleepBankDays: Int {
        didSet {
            if !isLoading {
                defaults.set(sleepBankDays, forKey: Keys.sleepBankDays)
            }
        }
    }

    var earliestReasonableBedtime: Date {
        didSet {
            if !isLoading {
                defaults.set(earliestReasonableBedtime, forKey: Keys.earliestReasonableBedtime)
            }
        }
    }

    /// When true, durations use decimal hours ("5.1h"); otherwise "5h 6m".
    var useDecimalDurations: Bool {
        didSet {
            if !isLoading {
                defaults.set(useDecimalDurations, forKey: Keys.useDecimalDurations)
            }
        }
    }

    /// When true, the sleep balance waterfall chart is hidden from the Sleep Balance card.
    var hideSleepBankChart: Bool {
        didSet {
            if !isLoading {
                defaults.set(hideSleepBankChart, forKey: Keys.hideSleepBankChart)
            }
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
            Self.migrateFromLegacySwiftDataIfNeeded(into: defaults)
        }

        self.sleepGoalHours = (defaults.object(forKey: Keys.sleepGoalHours) as? Double) ?? Defaults.sleepGoalHours
        self.wakeTime = (defaults.object(forKey: Keys.wakeTime) as? Date) ?? Defaults.wakeTime
        self.sleepBankDays = (defaults.object(forKey: Keys.sleepBankDays) as? Int) ?? Defaults.sleepBankDays
        self.earliestReasonableBedtime = (defaults.object(forKey: Keys.earliestReasonableBedtime) as? Date) ?? Defaults.earliestReasonableBedtime
        self.useDecimalDurations = (defaults.object(forKey: Keys.useDecimalDurations) as? Bool) ?? Defaults.useDecimalDurations
        self.hideSleepBankChart = (defaults.object(forKey: Keys.hideSleepBankChart) as? Bool) ?? Defaults.hideSleepBankChart
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
            migrateFromLegacySwiftDataIfNeeded()
        }

        isLoading = true
        defer { isLoading = false }

        let loadedSleepGoalHours = (defaults.object(forKey: Keys.sleepGoalHours) as? Double) ?? Defaults.sleepGoalHours
        if sleepGoalHours != loadedSleepGoalHours {
            sleepGoalHours = loadedSleepGoalHours
        }

        let loadedWakeTime = (defaults.object(forKey: Keys.wakeTime) as? Date) ?? Defaults.wakeTime
        if wakeTime != loadedWakeTime {
            wakeTime = loadedWakeTime
        }

        let loadedSleepBankDays = (defaults.object(forKey: Keys.sleepBankDays) as? Int) ?? Defaults.sleepBankDays
        if sleepBankDays != loadedSleepBankDays {
            sleepBankDays = loadedSleepBankDays
        }

        let loadedEarliestBedtime = (defaults.object(forKey: Keys.earliestReasonableBedtime) as? Date) ?? Defaults.earliestReasonableBedtime
        if earliestReasonableBedtime != loadedEarliestBedtime {
            earliestReasonableBedtime = loadedEarliestBedtime
        }

        let loadedUseDecimalDurations = (defaults.object(forKey: Keys.useDecimalDurations) as? Bool) ?? Defaults.useDecimalDurations
        if useDecimalDurations != loadedUseDecimalDurations {
            useDecimalDurations = loadedUseDecimalDurations
        }

        let loadedHideSleepBankChart = (defaults.object(forKey: Keys.hideSleepBankChart) as? Bool) ?? Defaults.hideSleepBankChart
        if hideSleepBankChart != loadedHideSleepBankChart {
            hideSleepBankChart = loadedHideSleepBankChart
        }
    }

    private func migrateFromLegacySwiftDataIfNeeded() {
        Self.migrateFromLegacySwiftDataIfNeeded(into: defaults)
    }

    /// One-time migration from the previous SwiftData SQLite store (`default.store`) into `UserDefaults`.
    /// Never touches the SQLite file while protected data is unavailable (before first unlock) and never
    /// deletes the store file.
    private static func migrateFromLegacySwiftDataIfNeeded(into defaults: UserDefaults) {
        guard !defaults.bool(forKey: Keys.migratedFromSwiftData) else { return }
        guard UIApplication.shared.isProtectedDataAvailable else { return }

        if Keys.allPreferenceKeys.contains(where: { defaults.object(forKey: $0) != nil }) {
            defaults.set(true, forKey: Keys.migratedFromSwiftData)
            return
        }

        let storeURL = URL.applicationSupportDirectory.appendingPathComponent("default.store")
        guard FileManager.default.fileExists(atPath: storeURL.path) else {
            defaults.set(true, forKey: Keys.migratedFromSwiftData)
            return
        }

        var db: OpaquePointer?
        let openStatus = sqlite3_open_v2(storeURL.path, &db, SQLITE_OPEN_READWRITE, nil)
        defer {
            if let db {
                sqlite3_close(db)
            }
        }
        guard openStatus == SQLITE_OK, let db else {
            return
        }

        guard let existingColumns = fetchColumns(table: "ZUSERPREFERENCES", db: db) else {
            return
        }
        guard !existingColumns.isEmpty else {
            defaults.set(true, forKey: Keys.migratedFromSwiftData)
            return
        }

        let targetColumns = LegacyColumn.all.filter { existingColumns.contains($0) }
        guard !targetColumns.isEmpty else {
            defaults.set(true, forKey: Keys.migratedFromSwiftData)
            return
        }

        guard let rows = fetchLegacyRows(columns: targetColumns, db: db) else {
            return
        }

        if let chosen = rows.first(where: { $0.differsFromDefaults }) ?? rows.first {
            if let sleepGoalHours = chosen.sleepGoalHours {
                defaults.set(sleepGoalHours, forKey: Keys.sleepGoalHours)
            }
            if let wakeTime = chosen.wakeTime {
                defaults.set(wakeTime, forKey: Keys.wakeTime)
            }
            if let sleepBankDays = chosen.sleepBankDays {
                defaults.set(sleepBankDays, forKey: Keys.sleepBankDays)
            }
            if let earliestReasonableBedtime = chosen.earliestReasonableBedtime {
                defaults.set(earliestReasonableBedtime, forKey: Keys.earliestReasonableBedtime)
            }
            if let useDecimalDurations = chosen.useDecimalDurations {
                defaults.set(useDecimalDurations, forKey: Keys.useDecimalDurations)
            }
            if let hideSleepBankChart = chosen.hideSleepBankChart {
                defaults.set(hideSleepBankChart, forKey: Keys.hideSleepBankChart)
            }
        }

        defaults.set(true, forKey: Keys.migratedFromSwiftData)
    }

    private static func fetchColumns(table: String, db: OpaquePointer) -> Set<String>? {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "PRAGMA table_info(\(table))", -1, &stmt, nil) == SQLITE_OK,
              let stmt else {
            return nil
        }
        defer { sqlite3_finalize(stmt) }

        var columns: Set<String> = []
        var stepResult = sqlite3_step(stmt)
        while stepResult == SQLITE_ROW {
            if let namePtr = sqlite3_column_text(stmt, 1) {
                columns.insert(String(cString: namePtr).uppercased())
            }
            stepResult = sqlite3_step(stmt)
        }
        guard stepResult == SQLITE_DONE else {
            return nil
        }
        return columns
    }

    private static func fetchLegacyRows(columns: [String], db: OpaquePointer) -> [LegacyPreferencesRow]? {
        let query = "SELECT \(columns.joined(separator: ", ")) FROM ZUSERPREFERENCES"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK,
              let stmt else {
            return nil
        }
        defer { sqlite3_finalize(stmt) }

        let columnIndices = Dictionary(uniqueKeysWithValues: columns.enumerated().map { ($0.element, Int32($0.offset)) })
        var rows: [LegacyPreferencesRow] = []
        var stepResult = sqlite3_step(stmt)
        while stepResult == SQLITE_ROW {
            var row = LegacyPreferencesRow()
            if let idx = columnIndices[LegacyColumn.sleepGoalHours], sqlite3_column_type(stmt, idx) != SQLITE_NULL {
                row.sleepGoalHours = sqlite3_column_double(stmt, idx)
            }
            if let idx = columnIndices[LegacyColumn.wakeTime], sqlite3_column_type(stmt, idx) != SQLITE_NULL {
                row.wakeTime = Date(timeIntervalSinceReferenceDate: sqlite3_column_double(stmt, idx))
            }
            if let idx = columnIndices[LegacyColumn.sleepBankDays], sqlite3_column_type(stmt, idx) != SQLITE_NULL {
                row.sleepBankDays = Int(sqlite3_column_int64(stmt, idx))
            }
            if let idx = columnIndices[LegacyColumn.earliestReasonableBedtime], sqlite3_column_type(stmt, idx) != SQLITE_NULL {
                row.earliestReasonableBedtime = Date(timeIntervalSinceReferenceDate: sqlite3_column_double(stmt, idx))
            }
            if let idx = columnIndices[LegacyColumn.useDecimalDurations], sqlite3_column_type(stmt, idx) != SQLITE_NULL {
                row.useDecimalDurations = sqlite3_column_int64(stmt, idx) != 0
            }
            if let idx = columnIndices[LegacyColumn.hideSleepBankChart], sqlite3_column_type(stmt, idx) != SQLITE_NULL {
                row.hideSleepBankChart = sqlite3_column_int64(stmt, idx) != 0
            }
            rows.append(row)
            stepResult = sqlite3_step(stmt)
        }
        guard stepResult == SQLITE_DONE else {
            return nil
        }
        return rows
    }
}

private struct LegacyPreferencesRow {
    var sleepGoalHours: Double?
    var wakeTime: Date?
    var sleepBankDays: Int?
    var earliestReasonableBedtime: Date?
    var useDecimalDurations: Bool?
    var hideSleepBankChart: Bool?

    var differsFromDefaults: Bool {
        if let sleepGoalHours, abs(sleepGoalHours - 8.0) > 1e-6 {
            return true
        }
        if let wakeTime {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: wakeTime)
            if comps.hour != 7 || comps.minute != 0 {
                return true
            }
        }
        if let sleepBankDays, sleepBankDays != 7 {
            return true
        }
        if let earliestReasonableBedtime {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: earliestReasonableBedtime)
            if comps.hour != 21 || comps.minute != 0 {
                return true
            }
        }
        if let useDecimalDurations, useDecimalDurations {
            return true
        }
        if let hideSleepBankChart, hideSleepBankChart {
            return true
        }
        return false
    }
}
