//
//  BedtimeApp.swift
//  Bedtime
//
//  Created by Greg on 10/4/25.
//

import OSLog
import SwiftData
import SwiftUI
import UIKit

@main
struct BedtimeApp: App {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.burnsides.bedtime",
        category: "SwiftData"
    )

    @State private var modelContainer: ModelContainer?
    @State private var loadFailed = false

    var body: some Scene {
        WindowGroup {
            Group {
                if let modelContainer {
                    ContentView()
                        .modelContainer(modelContainer)
                } else if loadFailed {
                    ContentUnavailableView {
                        Label("Unable to Load Settings", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text("Bedger couldn't open its settings store.")
                    } actions: {
                        Button("Retry") {
                            loadModelContainerIfNeeded()
                        }
                    }
                } else {
                    ProgressView()
                }
            }
            .onAppear {
                loadModelContainerIfNeeded()
            }
            .task {
                // If launched before first unlock, wait until protected data becomes available.
                guard modelContainer == nil else { return }
                let iterator = NotificationCenter.default
                    .notifications(named: UIApplication.protectedDataDidBecomeAvailableNotification)
                    .makeAsyncIterator()
                loadModelContainerIfNeeded()
                while modelContainer == nil, await iterator.next() != nil {
                    loadModelContainerIfNeeded()
                }
            }
        }
    }

    private func loadModelContainerIfNeeded() {
        guard modelContainer == nil,
              UIApplication.shared.isProtectedDataAvailable else {
            return
        }

        if let container = Self.makePersistentContainer() {
            modelContainer = container
            loadFailed = false
        } else {
            loadFailed = true
        }
    }

    private static func makePersistentContainer() -> ModelContainer? {
        let schema = Schema([
            UserPreferences.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            seedPreferencesIfNeeded(in: container)
            return container
        } catch {
            let storeURL = modelConfiguration.url
            // Never delete the store when protected data is unavailable or any store file
            // can't be opened for reading (e.g. file protection / permission errors).
            guard UIApplication.shared.isProtectedDataAvailable,
                  canOpenStoreFilesForReading(at: storeURL) else {
                logger.error("Persistent SwiftData store unavailable; preserving files on disk: \(error, privacy: .public)")
                return nil
            }

            // The store is readable on disk, so the failure is an incompatible schema
            // (e.g. a model change SwiftData can't lightweight-migrate) or corruption.
            // Discard the stale store and rebuild it rather than crashing on open.
            logger.warning("Resetting incompatible SwiftData store after error: \(error, privacy: .public)")
            let fileManager = FileManager.default
            for suffix in ["", "-shm", "-wal"] {
                let url = URL(fileURLWithPath: storeURL.path + suffix)
                try? fileManager.removeItem(at: url)
            }

            do {
                let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
                seedPreferencesIfNeeded(in: container)
                return container
            } catch {
                logger.error("Could not recreate persistent SwiftData store: \(error, privacy: .public)")
                return nil
            }
        }
    }

    /// Returns `true` only if `storeURL` exists and every existing SQLite file
    /// (`default.store`, `-shm`, `-wal`) can be opened for reading.
    private static func canOpenStoreFilesForReading(at storeURL: URL) -> Bool {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: storeURL.path) else {
            return false
        }
        for suffix in ["", "-shm", "-wal"] {
            let url = URL(fileURLWithPath: storeURL.path + suffix)
            guard fileManager.fileExists(atPath: url.path) else { continue }
            guard let handle = try? FileHandle(forReadingFrom: url) else {
                return false
            }
            try? handle.close()
        }
        return true
    }

    private static func seedPreferencesIfNeeded(in container: ModelContainer) {
        let context = container.mainContext
        guard let count = try? context.fetchCount(FetchDescriptor<UserPreferences>()),
              count == 0 else {
            return
        }
        context.insert(UserPreferences())
        try? context.save()
    }
}
