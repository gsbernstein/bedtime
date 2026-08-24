//
//  HealthKitCreationDateReader.swift
//  Bedtime
//
//  Reads a HealthKit sample's "Date Added" timestamp — the value shown in the iOS Health app's
//  sample detail screen, but never exposed by any public `HKSample` API (`startDate`/`endDate`
//  describe when the *event* happened, not when HealthKit received it).
//

import Foundation
import HealthKit

/// HealthKit stores "Date Added" internally as `creationTimestamp`, readable only via
/// undocumented Key-Value Coding. This is exactly what duplicate-sync detection needs: when a
/// source (e.g. Oura) re-syncs a night it already wrote, the resulting samples have identical
/// start/end times but a distinct, later creation timestamp — the only signal that tells the two
/// syncs apart.
///
/// This is unsupported API: Apple could rename or remove the underlying property in a future OS
/// release. `KVCSafeAccessor` guards the read with an Objective-C `@try`/`@catch` so an
/// unexpected undefined-key exception degrades to `nil` (the cleanup feature simply becomes
/// unavailable for that sample) instead of crashing the app.
enum HealthKitCreationDateReader {
    private static let key = "creationTimestamp"

    static func creationDate(for sample: HKSample) -> Date? {
        KVCSafeAccessor.safeValue(key, for: sample) as? Date
    }
}
