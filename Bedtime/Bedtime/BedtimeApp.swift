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
            if let storeURL = modelConfiguration.url as URL? {
                let fileManager = FileManager.default
                for suffix in ["", "-shm", "-wal"] {
                    let url = URL(fileURLWithPath: storeURL.path + suffix)
                    try? fileManager.removeItem(at: url)
                }
            }

            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer after resetting the store: \(error)")
            }
        }
    }()

    init() {
        Self.seedDefaultPreferencesIfNeeded(in: sharedModelContainer)
    }

    /// Creates the single `UserPreferences` record when the store is empty.
    ///
    /// SwiftData persists the schema but never creates instances, so a fresh install —
    /// or a launch right after the store reset above — starts with nothing to read.
    /// Seeding here, before the view tree exists, keeps the insert out of `ContentView`'s
    /// body evaluation: SwiftUI reads a view's properties an unspecified number of times
    /// per update, so inserting from there can write several default records and mutates
    /// persistent state in the middle of a render.
    @MainActor
    private static func seedDefaultPreferencesIfNeeded(in container: ModelContainer) {
        let context = container.mainContext

        var descriptor = FetchDescriptor<UserPreferences>()
        descriptor.fetchLimit = 1

        // A failed fetch is not a reason to insert; ContentView still seeds defensively.
        guard let existing = try? context.fetch(descriptor), existing.isEmpty else { return }

        context.insert(UserPreferences())
        try? context.save()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
