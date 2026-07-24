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
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            DiagnosticLogger.log("ModelContainer opened successfully")
            return container
        } catch {
            DiagnosticLogger.log("ModelContainer failed: \(error.localizedDescription) — resetting store")
            let storeURL = modelConfiguration.url
            let fileManager = FileManager.default
            for suffix in ["", "-shm", "-wal"] {
                let url = URL(fileURLWithPath: storeURL.path + suffix)
                try? fileManager.removeItem(at: url)
            }

            do {
                let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
                DiagnosticLogger.log("ModelContainer opened after store reset")
                return container
            } catch {
                DiagnosticLogger.log("ModelContainer failed after store reset: \(error.localizedDescription)")
                fatalError("Could not create ModelContainer after resetting the store: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    DiagnosticLogger.log("App window appeared")
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
