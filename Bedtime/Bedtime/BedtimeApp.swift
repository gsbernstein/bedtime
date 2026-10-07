//
//  BedtimeApp.swift
//  Bedtime
//
//  Created by Greg on 10/4/25.
//

import SwiftUI
import SwiftData
import HealthKit
import UIKit

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
            // → earliestReasonableBedtime refactor), or corrupted due to an unexpected
            // power loss. Rather than crash, attempt recovery.

            // Log the error for diagnostics
            print("[Bedtime] SwiftData store error, attempting recovery: \(error)")

            if let storeURL = modelConfiguration.url as URL? {
                let fileManager = FileManager.default
                for suffix in ["", "-shm", "-wal"] {
                    let url = URL(fileURLWithPath: storeURL.path + suffix)
                    try? fileManager.removeItem(at: url)
                }
                print("[Bedtime] Cleared corrupted store at: \(storeURL.path)")
            }

            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer after resetting the store: \(error)")
            }
        }
    }()

    init() {
        // Must happen synchronously before the app finishes launching, per
        // BGTaskScheduler's requirements.
        LiveActivityManager.registerBackgroundTask()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onReceive(
                    NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification),
                    perform: { _ in
                        // Explicitly save data when app is about to terminate
                        try? sharedModelContainer.mainContext.save()
                    }
                )
                .onReceive(
                    NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification),
                    perform: { _ in
                        // Also save when entering background to protect against unexpected power loss
                        try? sharedModelContainer.mainContext.save()
                    }
                )
        }
        .modelContainer(sharedModelContainer)
    }
}
