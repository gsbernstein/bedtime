//
//  LegacyPreferencesMigration.swift
//  Bedtime
//
//  Created by Greg on 11/22/26.
//

import Foundation
import SQLite3
import UIKit

/// One-time migration from the legacy SwiftData SQLite store (`default.store`) into `UserDefaults`.
/// Never touches the SQLite file while protected data is unavailable (before first unlock) and never
/// deletes the store file.
@MainActor
enum LegacyPreferencesMigration {
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

    static func migrateIfNeeded(into defaults: UserDefaults) {
        guard !defaults.bool(forKey: UserPreferences.Keys.migratedFromSwiftData) else { return }
        guard UIApplication.shared.isProtectedDataAvailable else { return }

        if UserPreferences.Keys.all.contains(where: { defaults.object(forKey: $0) != nil }) {
            defaults.set(true, forKey: UserPreferences.Keys.migratedFromSwiftData)
            return
        }

        let storeURL = URL.applicationSupportDirectory.appendingPathComponent("default.store")
        guard FileManager.default.fileExists(atPath: storeURL.path) else {
            defaults.set(true, forKey: UserPreferences.Keys.migratedFromSwiftData)
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
            defaults.set(true, forKey: UserPreferences.Keys.migratedFromSwiftData)
            return
        }

        let targetColumns = LegacyColumn.all.filter { existingColumns.contains($0) }
        guard !targetColumns.isEmpty else {
            defaults.set(true, forKey: UserPreferences.Keys.migratedFromSwiftData)
            return
        }

        guard let rows = fetchLegacyRows(columns: targetColumns, db: db) else {
            return
        }

        if let chosen = rows.first(where: { $0.differsFromDefaults }) ?? rows.first {
            if let sleepGoalHours = chosen.sleepGoalHours {
                defaults.set(sleepGoalHours, forKey: UserPreferences.Keys.sleepGoalHours)
            }
            if let wakeTimeTimestamp = chosen.wakeTimeTimestamp {
                defaults.set(wakeTimeTimestamp, forKey: UserPreferences.Keys.wakeTime)
            }
            if let sleepBankDays = chosen.sleepBankDays {
                defaults.set(sleepBankDays, forKey: UserPreferences.Keys.sleepBankDays)
            }
            if let earliestBedtimeTimestamp = chosen.earliestBedtimeTimestamp {
                defaults.set(earliestBedtimeTimestamp, forKey: UserPreferences.Keys.earliestReasonableBedtime)
            }
            if let useDecimalDurations = chosen.useDecimalDurations {
                defaults.set(useDecimalDurations, forKey: UserPreferences.Keys.useDecimalDurations)
            }
            if let hideSleepBankChart = chosen.hideSleepBankChart {
                defaults.set(hideSleepBankChart, forKey: UserPreferences.Keys.hideSleepBankChart)
            }
        }

        defaults.set(true, forKey: UserPreferences.Keys.migratedFromSwiftData)
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
                row.wakeTimeTimestamp = sqlite3_column_double(stmt, idx)
            }
            if let idx = columnIndices[LegacyColumn.sleepBankDays], sqlite3_column_type(stmt, idx) != SQLITE_NULL {
                row.sleepBankDays = Int(sqlite3_column_int64(stmt, idx))
            }
            if let idx = columnIndices[LegacyColumn.earliestReasonableBedtime], sqlite3_column_type(stmt, idx) != SQLITE_NULL {
                row.earliestBedtimeTimestamp = sqlite3_column_double(stmt, idx)
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
    var wakeTimeTimestamp: Double?
    var sleepBankDays: Int?
    var earliestBedtimeTimestamp: Double?
    var useDecimalDurations: Bool?
    var hideSleepBankChart: Bool?

    var differsFromDefaults: Bool {
        if let sleepGoalHours, abs(sleepGoalHours - 8.0) > 1e-6 {
            return true
        }
        if let wakeTimeTimestamp {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: Date(timeIntervalSinceReferenceDate: wakeTimeTimestamp))
            if comps.hour != 7 || comps.minute != 0 {
                return true
            }
        }
        if let sleepBankDays, sleepBankDays != 7 {
            return true
        }
        if let earliestBedtimeTimestamp {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: Date(timeIntervalSinceReferenceDate: earliestBedtimeTimestamp))
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
