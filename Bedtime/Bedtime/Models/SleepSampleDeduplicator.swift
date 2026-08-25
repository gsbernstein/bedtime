//
//  SleepSampleDeduplicator.swift
//  Bedtime
//
//  Some sources (notably Oura) have a "double sync" bug: syncing a night, then falling back
//  asleep and syncing again, re-writes the same stretch of stage samples a second time instead
//  of only writing the newly-recorded tail. Left alone, that inflates every duration total this
//  app computes (Sleep Bank balance, per-night totals, source comparisons) by roughly 2x for
//  the affected night. There's no public, reliable way to tell *when* HealthKit received a
//  sample (only when the sleep it describes happened), so this can't distinguish "old sync" from
//  "new sync" directly — instead it relies on a structural fact: a single sync's stage samples
//  never overlap each other (core/deep/REM segments are sequential), so any same-source,
//  same-night overlap is necessarily two syncs' worth of data for the same stretch of time.
//

import Foundation
import HealthKit

enum SleepSampleDeduplicator {
    /// A lightweight stand-in for identity: `SleepSession` has no sample UUID to key off of, so
    /// this keys on its visible fields instead. Collisions (two sessions
    /// with identical start, end, type, and source) are harmless here — they'd be genuine
    /// duplicates anyway, and treating them as the same identity just means they're dropped or
    /// kept together, which is the correct outcome either way.
    private struct Identity: Hashable {
        let startDate: Date
        let endDate: Date
        let sleepTypeRawValue: Int
        let sourceBundleID: String

        init(_ session: SleepSession) {
            startDate = session.startDate
            endDate = session.endDate
            sleepTypeRawValue = session.sleepType.rawValue
            sourceBundleID = session.source.source.bundleIdentifier
        }
    }

    /// Removes the "old", superseded half of any same-source, same-night duplicate re-sync from
    /// `sessions`, so summed durations aren't inflated by data a source wrote twice. Sessions
    /// that never overlap anything (the common case, and also a re-sync's non-overlapping new
    /// tail) pass through untouched. Preserves `sessions`' original relative order — callers
    /// (e.g. `SleepDayGroup`, which reads `.first`/`.last` as wake/bed times) rely on it staying
    /// reverse-chronological.
    static func deduplicate(_ sessions: [SleepSession]) -> [SleepSession] {
        struct Key: Hashable {
            let night: Date
            let bundleID: String
        }

        let grouped = Dictionary(grouping: sessions) {
            Key(night: $0.dateForGrouping, bundleID: $0.source.source.bundleIdentifier)
        }

        let toDrop = Set(grouped.values.flatMap(sessionsToDrop).map(Identity.init))
        guard !toDrop.isEmpty else { return sessions }
        return sessions.filter { !toDrop.contains(Identity($0)) }
    }

    /// Resolves one (night, source) group and returns just the sessions that should be
    /// discarded — the superseded generation(s) of any overlapping span.
    private static func sessionsToDrop(_ sessions: [SleepSession]) -> [SleepSession] {
        guard sessions.count > 1 else { return [] }
        let sortedByStart = sessions.sorted { $0.startDate < $1.startDate }
        return overlapComponents(sortedByStart).flatMap(droppedFromComponent)
    }

    /// Merges sessions into components under the "reachable via a chain of pairwise time
    /// overlaps" relation — the standard sweep used to merge overlapping intervals. A duplicate
    /// re-sync's shared span becomes one component; anything that never overlaps anything else
    /// — including a re-sync's non-overlapping "new" tail, which should always survive — ends up
    /// in its own singleton component.
    private static func overlapComponents(_ sortedByStart: [SleepSession]) -> [[SleepSession]] {
        guard let first = sortedByStart.first else { return [] }

        var components: [[SleepSession]] = []
        var current: [SleepSession] = [first]
        var currentEnd = first.endDate

        for session in sortedByStart.dropFirst() {
            if session.startDate < currentEnd {
                current.append(session)
                currentEnd = max(currentEnd, session.endDate)
            } else {
                components.append(current)
                current = [session]
                currentEnd = session.endDate
            }
        }
        components.append(current)
        return components
    }

    /// If a component is internally overlapping, it's the contested span written by two (or
    /// more) syncs. Splits it into the minimum number of mutually non-overlapping "generations"
    /// and drops every generation except the one that covers the most total sleep — in
    /// practice always the latest sync, since falling back asleep and re-syncing can only add
    /// data for that span, never remove it. A non-overlapping component is real, unduplicated
    /// data, so nothing is dropped from it.
    private static func droppedFromComponent(_ component: [SleepSession]) -> [SleepSession] {
        guard component.count > 1 else { return [] }
        let generations = nonOverlappingGenerations(component)
        guard generations.count > 1 else { return [] }
        guard let bestIndex = generations.indices.max(by: { totalDuration(generations[$0]) < totalDuration(generations[$1]) }) else {
            return []
        }
        return generations.enumerated().filter { $0.offset != bestIndex }.flatMap(\.element)
    }

    /// Greedy interval partitioning: walks sessions in start-time order, placing each into the
    /// still-open generation whose most recent session ends soonest (while still being at or
    /// before this session's start) — the standard minimum-generations strategy — opening a new
    /// generation only when no existing one qualifies. Because `component` came from
    /// `overlapComponents`, every session here participates in the same contested span, so this
    /// only ever separates that span's own duplicate generations from each other.
    private static func nonOverlappingGenerations(_ component: [SleepSession]) -> [[SleepSession]] {
        let sortedByStart = component.sorted { $0.startDate < $1.startDate }
        var generations: [[SleepSession]] = []

        for session in sortedByStart {
            let eligibleIndices = generations.indices.filter { generations[$0].last!.endDate <= session.startDate }
            if let bestIndex = eligibleIndices.max(by: { generations[$0].last!.endDate < generations[$1].last!.endDate }) {
                generations[bestIndex].append(session)
            } else {
                generations.append([session])
            }
        }
        return generations
    }

    private static func totalDuration(_ sessions: [SleepSession]) -> TimeInterval {
        sessions.reduce(0) { $0 + $1.duration }
    }
}
