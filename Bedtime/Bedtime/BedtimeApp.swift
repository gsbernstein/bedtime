//
//  BedtimeApp.swift
//  Bedtime
//
//  Created by Greg on 10/4/25.
//

import SwiftUI
import SwiftData
import HealthKit

@main
struct BedtimeApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            UserPreferences.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // The store on disk can be incompatible with the current schema after a
            // model change that SwiftData can't lightweight-migrate (e.g. the max-hours
            // → earliestReasonableBedtime refactor). Rather than crash on open for
            // anyone upgrading, discard the stale store and rebuild it. UserPreferences
            // only holds user settings, which fall back to sensible defaults.
            let storeURL = modelConfiguration.url
            let fileManager = FileManager.default
            for suffix in ["", "-shm", "-wal"] {
                let url = URL(fileURLWithPath: storeURL.path + suffix)
                try? fileManager.removeItem(at: url)
            }

            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer after resetting the store: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
