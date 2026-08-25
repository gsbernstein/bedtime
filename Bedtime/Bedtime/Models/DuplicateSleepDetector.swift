//
//  DuplicateSleepDetector.swift
//  Bedtime
//
//  Detects the "double sync" bug some sources (notably Oura) exhibit: syncing a night, then
//  syncing again later re-writes the same stretch of samples a second time. The result is two
//  overlapping sets of same-source samples for one night that differ only in when HealthKit
//  received them ("Date Added" — see `HealthKitCreationDateReader`).
//

import Foundation
import HealthKit

/// A single HealthKit sleep sample retained with its stable identity and best-effort "date
/// added" timestamp, purely for duplicate detection & cleanup. `SleepSession` intentionally
/// drops both — nothing else in the app needs them.
struct DuplicateCandidateSample: Identifiable, Equatable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    let sleepType: HKCategoryValueSleepAnalysis
    /// `nil` when HealthKit's internal timestamp couldn't be read (see
    /// `HealthKitCreationDateReader`). Samples with an unknown creation date are never
    /// auto-selected for deletion.
    let creationDate: Date?
    /// The app/device that wrote this sample. HealthKit only allows an app to delete objects
    /// *it* saved (`HKHealthStore.deleteObjects` is explicitly scoped to "objects saved by this
    /// application" — no amount of write authorization lets an app delete another source's
    /// data; only the Health app itself, or the original writer, can). Carried per-sample
    /// (denormalized from the group) so `HealthKitManager.deleteDuplicateSamples` can check
    /// this before attempting a delete that would otherwise silently match nothing.
    let sourceBundleID: String
    let sourceName: String

    var duration: TimeInterval { endDate.timeIntervalSince(startDate) }
}

extension DuplicateCandidateSample {
    init?(sample: HKCategorySample) {
        guard let sleepType = HKCategoryValueSleepAnalysis(rawValue: sample.value),
              HKCategoryValueSleepAnalysis.allAsleepValues.contains(sleepType) else { return nil }
        self.id = sample.uuid
        self.startDate = sample.startDate
        self.endDate = sample.endDate
        self.sleepType = sleepType
        self.creationDate = HealthKitCreationDateReader.creationDate(for: sample)
        self.sourceBundleID = sample.sourceRevision.source.bundleIdentifier
        self.sourceName = sample.sourceRevision.source.name
    }
}

/// One night's worth of same-source samples that overlap in time — the signature of a
/// duplicate re-sync — along with enough "date added" data to suggest where to split them.
struct DuplicateSleepGroup: Identifiable, Equatable {
    let night: Date
    let sourceBundleID: String
    let sourceName: String
    /// Sorted by `startDate`.
    let samples: [DuplicateCandidateSample]

    var id: String { "\(night.timeIntervalSinceReferenceDate)-\(sourceBundleID)" }

    /// Distinct known creation timestamps, sorted ascending.
    var distinctCreationDates: [Date] {
        Array(Set(samples.compactMap(\.creationDate))).sorted()
    }

    /// Whether "date added" data is rich enough to place a meaningful divider: at least two
    /// distinct sync times, covering at least half of the samples in this group.
    var hasUsableCreationData: Bool {
        let knownCount = samples.filter { $0.creationDate != nil }.count
        return distinctCreationDates.count >= 2 && knownCount * 2 >= samples.count
    }

    /// True when at least two samples from this source overlap in time — back-to-back sleep
    /// stages from a single sync never do, so this is specific to duplicate re-syncs.
    var hasOverlap: Bool {
        let sorted = samples.sorted { $0.startDate < $1.startDate }
        guard sorted.count > 1 else { return false }
        var runningEnd = sorted[0].endDate
        for sample in sorted.dropFirst() {
            if sample.startDate < runningEnd { return true }
            runningEnd = max(runningEnd, sample.endDate)
        }
        return false
    }

    /// Whether this group is both overlapping and has enough "date added" signal to offer a
    /// cleanup UI for.
    var isCleanable: Bool { hasOverlap && hasUsableCreationData }

    /// The midpoint of the largest gap between consecutive creation timestamps — i.e. the
    /// boundary between two sync batches — used as the default divider position.
    var suggestedCutoff: Date? {
        guard hasUsableCreationData else { return nil }
        let sorted = distinctCreationDates
        guard sorted.count > 1 else { return nil }

        var bestGapIndex = 0
        var bestGap: TimeInterval = -1
        for index in 1..<sorted.count {
            let gap = sorted[index].timeIntervalSince(sorted[index - 1])
            if gap > bestGap {
                bestGap = gap
                bestGapIndex = index - 1
            }
        }
        return sorted[bestGapIndex].addingTimeInterval(bestGap / 2)
    }

    /// The full span of known creation timestamps, for laying out the histogram/divider.
    var creationDateRange: ClosedRange<Date>? {
        let known = samples.compactMap(\.creationDate)
        guard let lower = known.min(), let upper = known.max(), lower < upper else { return nil }
        return lower...upper
    }

    var timeRange: (start: Date, end: Date)? {
        guard let start = samples.map(\.startDate).min(),
              let end = samples.map(\.endDate).max() else { return nil }
        return (start, end)
    }
}

/// How a `DuplicateSleepGroup` resolves at a given divider position.
struct DuplicateResolution {
    let toKeep: [DuplicateCandidateSample]
    let toDelete: [DuplicateCandidateSample]

    var deletedDuration: TimeInterval { toDelete.reduce(0) { $0 + $1.duration } }
    var keptDuration: TimeInterval { toKeep.reduce(0) { $0 + $1.duration } }
}

/// Thrown by `HealthKitManager.deleteDuplicateSamples` when asked to delete samples that
/// weren't written by this app — HealthKit's delete APIs are unconditionally scoped to "objects
/// saved by this application" (see `HKHealthStore.deleteObjects(of:predicate:)`), so no amount
/// of write authorization lets Bedger remove another source's (e.g. Oura's) samples. Attempting
/// it anyway wouldn't throw — it would just silently match nothing, look like it worked, and
/// leave the duplicates in place. Only the Health app itself (or the original writer) can
/// delete that data, so this case needs a distinct, actionable error rather than a generic one.
struct ForeignSourceDeletionError: LocalizedError {
    let sourceName: String

    var errorDescription: String? {
        "Bedger can't delete \(sourceName)'s entries directly — Apple only allows an app to remove data it wrote itself."
    }

    var recoverySuggestion: String? {
        "Open the Health app, go to Browse → Sleep, select this night, tap \"Show All Data,\" and delete the older \(sourceName) entries there."
    }
}

enum DuplicateSleepDetector {
    /// Scans every fetched sample and returns one group per (night, source) pair that shows
    /// signs of a duplicate re-sync and has enough "date added" data to clean up.
    static func detectCleanableGroups(in samples: [HKCategorySample]) -> [DuplicateSleepGroup] {
        struct Key: Hashable {
            let night: Date
            let bundleID: String
        }

        var samplesByKey: [Key: [DuplicateCandidateSample]] = [:]
        var sourceNamesByBundleID: [String: String] = [:]

        for sample in samples {
            guard let candidate = DuplicateCandidateSample(sample: sample) else { continue }
            sourceNamesByBundleID[candidate.sourceBundleID] = candidate.sourceName
            let night = SleepSession.dateForGrouping(startDate: candidate.startDate, duration: candidate.duration)
            samplesByKey[Key(night: night, bundleID: candidate.sourceBundleID), default: []].append(candidate)
        }

        return samplesByKey.compactMap { key, candidates in
            let group = DuplicateSleepGroup(
                night: key.night,
                sourceBundleID: key.bundleID,
                sourceName: sourceNamesByBundleID[key.bundleID] ?? key.bundleID,
                samples: candidates.sorted { $0.startDate < $1.startDate }
            )
            return group.isCleanable ? group : nil
        }
    }

    /// Splits a group's samples by a divider time: samples added before `cutoff` are proposed
    /// for deletion (the older, superseded sync), samples added at or after it are kept.
    /// Samples with no known creation date are always kept — we never guess on those.
    static func resolution(for group: DuplicateSleepGroup, cutoff: Date) -> DuplicateResolution {
        var toKeep: [DuplicateCandidateSample] = []
        var toDelete: [DuplicateCandidateSample] = []

        for sample in group.samples {
            guard let creationDate = sample.creationDate, creationDate < cutoff else {
                toKeep.append(sample)
                continue
            }
            toDelete.append(sample)
        }

        return DuplicateResolution(toKeep: toKeep, toDelete: toDelete)
    }
}
