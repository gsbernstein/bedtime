//
//  DebugDataGenerator.swift
//  Bedtime
//
//  Debug-only helper that fills HealthKit with synthetic sleep data so we can
//  exercise the app without relying on a real Apple Watch / device history.
//

#if DEBUG

import Foundation
import HealthKit

enum DebugDataGenerator {
    /// Metadata key stamped on every sample we write so we can find / delete
    /// our own fake data later without touching the user's real samples.
    static let fakeDataMetadataKey = "com.bedger.debug.fakeData"

    /// Generates a series of synthetic sleep nights ending today and writes
    /// them to HealthKit. Each night is composed of multiple stage samples
    /// (core / deep / REM / brief awakenings) to mimic what an Apple Watch
    /// would record.
    static func generateFakeSleepData(
        in healthStore: HKHealthStore,
        nights: Int,
        targetSleepHours: Double
    ) async throws {
        var samples: [HKCategorySample] = []
        let calendar = Calendar.current
        let now = Date()

        for nightOffset in 0..<nights {
            // Anchor each night to ~11pm of the previous calendar day, then
            // wiggle the bedtime / duration so the data isn't perfectly flat.
            guard let nightAnchor = calendar.date(
                byAdding: .day,
                value: -nightOffset,
                to: calendar.startOfDay(for: now)
            ) else { continue }

            let bedtimeJitterMinutes = Int.random(in: -45...45)
            guard let bedtime = calendar.date(
                byAdding: .minute,
                value: -60 + bedtimeJitterMinutes, // 11pm +/- jitter
                to: nightAnchor
            ) else { continue }

            // Sleep duration in seconds: target hours +/- ~1h.
            let jitterHours = Double.random(in: -1.0...0.75)
            let durationSeconds = max(4.0, targetSleepHours + jitterHours) * 3600

            // Skip nights that haven't happened yet (e.g. tonight if it's
            // still afternoon). Only emit nights whose end is in the past.
            let nightEnd = bedtime.addingTimeInterval(durationSeconds)
            if nightEnd > now { continue }

            samples.append(contentsOf: makeNightSamples(
                bedtime: bedtime,
                duration: durationSeconds
            ))
        }

        guard !samples.isEmpty else { return }

        try await healthStore.save(samples)
    }

    /// Deletes every sample previously written by `generateFakeSleepData`.
    /// Real samples (from Apple Watch, third-party trackers, etc.) are left
    /// alone because they don't carry our metadata marker.
    static func clearFakeSleepData(in healthStore: HKHealthStore) async throws {
        let predicate = HKQuery.predicateForObjects(
            withMetadataKey: fakeDataMetadataKey
        )

        try await healthStore.deleteObjects(of: HKCategoryType.sleepAnalysis, predicate: predicate)
    }

    // MARK: - Night composition

    /// Builds a sequence of stage samples for a single night. We cycle through
    /// core / deep / REM with the occasional brief awake interruption, which
    /// roughly matches what HealthKit consumers expect to see.
    private static func makeNightSamples(
        bedtime: Date,
        duration: TimeInterval
    ) -> [HKCategorySample] {
        var samples: [HKCategorySample] = []
        var cursor = bedtime
        let end = bedtime.addingTimeInterval(duration)

        // Stage rotation: roughly 90-minute cycles of core -> deep -> REM,
        // with short awake blips between cycles.
        let cycle: [(HKCategoryValueSleepAnalysis, ClosedRange<Double>)] = [
            (.asleepCore, 25...45),
            (.asleepDeep, 15...30),
            (.asleepCore, 15...25),
            (.asleepREM,  15...25),
            (.awake,       1...4),
        ]

        var stageIndex = 0
        while cursor < end {
            let (stage, minutesRange) = cycle[stageIndex % cycle.count]
            let minutes = Double.random(in: minutesRange)
            let stageEnd = min(cursor.addingTimeInterval(minutes * 60), end)

            // Skip zero-length tail segments.
            if stageEnd > cursor {
                samples.append(HKCategorySample(
                    type: HKCategoryType.sleepAnalysis,
                    value: stage.rawValue,
                    start: cursor,
                    end: stageEnd,
                    metadata: [fakeDataMetadataKey: true]
                ))
            }

            cursor = stageEnd
            stageIndex += 1
        }

        return samples
    }
}

#endif
