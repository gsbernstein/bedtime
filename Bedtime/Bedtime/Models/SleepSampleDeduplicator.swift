//
//  SleepSampleDeduplicator.swift
//  Bedtime
//
//  Some sources (notably Oura) have a "double sync" bug: syncing a night, then falling back
//  asleep and syncing again, re-writes the same stretch of stage samples a second time instead
//  of only writing the newly-recorded tail. Left alone, that inflates every duration total this
//  app computes (Sleep Bank balance, per-night totals, source comparisons) by roughly 2x for
//  the affected night.
//
//  HealthKit can only ever delete samples an app wrote itself, and these duplicates always come
//  from the other source (Oura), never Bedger -- so there's no way to actually remove them from
//  HealthKit. Instead, this filters the older, superseded sync out of Bedger's own calculations,
//  using the same signal a person would use if they went looking in the Health app: "Date
//  Added." See `HealthKitCreationDateReader`.
//

import Foundation
import HealthKit

enum SleepSampleDeduplicator {
    /// Removes the "old", superseded sync from any same-source, same-night duplicate re-sync in
    /// `samples`, so summed durations aren't inflated by data a source wrote twice. Preserves
    /// `samples`' original relative order — callers fetch (and downstream code like
    /// `SleepDayGroup`/`LastNightCard` reads `.first`/`.last` off) samples sorted newest-first,
    /// so this only ever removes elements, never reorders them.
    static func deduplicate(_ samples: [HKCategorySample]) -> [HKCategorySample] {
        struct Key: Hashable {
            let night: Date
            let bundleID: String
        }

        let grouped = Dictionary(grouping: samples) { sample in
            Key(
                night: SleepSession.dateForGrouping(startDate: sample.startDate, duration: sample.endDate.timeIntervalSince(sample.startDate)),
                bundleID: sample.sourceRevision.source.bundleIdentifier
            )
        }

        let toDropIDs = Set(grouped.values.flatMap(samplesToDrop).map(\.uuid))
        guard !toDropIDs.isEmpty else { return samples }
        return samples.filter { !toDropIDs.contains($0.uuid) }
    }

    /// Resolves one (night, source) group and returns just the samples that should be
    /// discarded. Only touches groups that show the structural signature of a duplicate
    /// re-sync -- same-source samples overlapping in time, which never happens within a single
    /// healthy sync since stage segments are sequential -- and only when "Date Added" data is
    /// rich enough to place a meaningful split. Otherwise drops nothing: we never guess at
    /// removing data without a real signal to justify it.
    private static func samplesToDrop(_ samples: [HKCategorySample]) -> [HKCategorySample] {
        guard samples.count > 1, hasOverlap(samples) else { return [] }

        let creationDatesByID = Dictionary(uniqueKeysWithValues: samples.map {
            ($0.uuid, HealthKitCreationDateReader.creationDate(for: $0))
        })
        let knownCreationDates = creationDatesByID.values.compactMap { $0 }
        let distinctCreationDates = Array(Set(knownCreationDates)).sorted()

        // Need at least two distinct sync times, known for at least half the group, to place a
        // meaningful divider between "old sync" and "new sync."
        guard distinctCreationDates.count >= 2, knownCreationDates.count * 2 >= samples.count else { return [] }

        guard let cutoff = suggestedCutoff(distinctCreationDates) else { return [] }

        // Samples with no readable creation date are always kept -- only ever drop what we can
        // positively identify as belonging to the older sync.
        return samples.filter { sample in
            // Dictionary lookup returns `Date??`: the outer optional is always populated here
            // (every sample was inserted above), the inner one is `nil` when the creation date
            // itself couldn't be read.
            guard case .some(.some(let creationDate)) = creationDatesByID[sample.uuid] else { return false }
            return creationDate < cutoff
        }
    }

    /// True when at least two samples from this source overlap in time -- back-to-back sleep
    /// stages from a single sync never do, so this is specific to duplicate re-syncs.
    private static func hasOverlap(_ samples: [HKCategorySample]) -> Bool {
        let sorted = samples.sorted { $0.startDate < $1.startDate }
        guard sorted.count > 1 else { return false }
        var runningEnd = sorted[0].endDate
        for sample in sorted.dropFirst() {
            if sample.startDate < runningEnd { return true }
            runningEnd = max(runningEnd, sample.endDate)
        }
        return false
    }

    /// The midpoint of the largest gap between consecutive distinct creation timestamps -- i.e.
    /// the boundary between two sync batches. `distinctCreationDates` must already be sorted
    /// ascending and have at least two entries.
    private static func suggestedCutoff(_ distinctCreationDates: [Date]) -> Date? {
        guard distinctCreationDates.count > 1 else { return nil }

        var bestGapIndex = 0
        var bestGap: TimeInterval = -1
        for index in 1..<distinctCreationDates.count {
            let gap = distinctCreationDates[index].timeIntervalSince(distinctCreationDates[index - 1])
            if gap > bestGap {
                bestGap = gap
                bestGapIndex = index - 1
            }
        }
        return distinctCreationDates[bestGapIndex].addingTimeInterval(bestGap / 2)
    }
}
