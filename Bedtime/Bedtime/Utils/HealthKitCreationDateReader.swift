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
        guard let raw = KVCSafeAccessor.safeValue(key, for: sample) else { return nil }

        // On every OS version observed so far this KVC read returns a boxed `NSNumber`, not
        // an `NSDate` — internally it's a raw `_creationTimestamp` double, sitting right
        // alongside `_startTimestamp`/`_endTimestamp` on `HKObject`. Still, handle a future
        // `NSDate`-boxed representation too, since nothing here is documented.
        if let date = raw as? Date {
            return date
        }
        guard let interval = (raw as? NSNumber)?.doubleValue else { return nil }

        // That raw double sits in the same units as `_startTimestamp`/`_endTimestamp` — i.e.
        // seconds since Foundation's reference date (2001-01-01), not the Unix epoch. Confirm
        // via a plausibility check (should land near "now") rather than assuming, in case a
        // future OS version switches conventions.
        let now = Date()
        let plausibleWindow = now.addingTimeInterval(-86400 * 400)...now.addingTimeInterval(86400)
        let referenceDateCandidate = Date(timeIntervalSinceReferenceDate: interval)
        if plausibleWindow.contains(referenceDateCandidate) {
            return referenceDateCandidate
        }
        let unixEpochCandidate = Date(timeIntervalSince1970: interval)
        if plausibleWindow.contains(unixEpochCandidate) {
            return unixEpochCandidate
        }
        return nil
    }
}
