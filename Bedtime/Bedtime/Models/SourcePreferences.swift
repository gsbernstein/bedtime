//
//  SourcePreferences.swift
//  Bedtime
//
//  Created by Greg on 10/17/25.
//

import Foundation
import SwiftUI
import Combine
import HealthKit

/// Manages user preferences for which HealthKit sources to include in sleep data
class SourcePreferences: ObservableObject {
    private static let excludedSourcesKey = "excludedSleepSourceBundleIdentifiers"
    
    // Store as comma-separated string in UserDefaults, convert to Set for use
    @AppStorage(excludedSourcesKey) private var excludedSourcesString: String = "" {
        willSet {
            objectWillChange.send()
        }
    }
    
    /// Set of excluded source bundle identifiers. Empty set means all sources are included (default).
    var excludedBundleIdentifiers: Set<String> {
        get {
            let identifiers = excludedSourcesString.split(separator: ",").map { String($0) }
            return Set(identifiers)
        }
        set {
            excludedSourcesString = newValue.joined(separator: ",")
        }
    }
    
    /// Check if a source is selected. Returns true if the source is NOT in the excluded set.
    func isSourceSelected(_ bundleIdentifier: String) -> Bool {
        return !excludedBundleIdentifiers.contains(bundleIdentifier)
    }
    
    /// Toggle selection state of a source
    func toggleSource(_ bundleIdentifier: String) {
        if excludedBundleIdentifiers.contains(bundleIdentifier) {
            includeSource(bundleIdentifier)
        } else {
            excludeSource(bundleIdentifier)
        }
    }
    
    /// Include a source (remove from excluded list)
    func includeSource(_ bundleIdentifier: String) {
        var excluded = excludedBundleIdentifiers
        excluded.remove(bundleIdentifier)
        excludedBundleIdentifiers = excluded
    }
    
    /// Exclude a source (add to excluded list)
    func excludeSource(_ bundleIdentifier: String) {
        var excluded = excludedBundleIdentifiers
        excluded.insert(bundleIdentifier)
        excludedBundleIdentifiers = excluded
    }
    
    /// Reset to default state (all sources included, no exclusions)
    func resetToDefault() {
        excludedBundleIdentifiers = []
    }
}

