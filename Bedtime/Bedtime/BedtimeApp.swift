//
//  BedtimeApp.swift
//  Bedtime
//
//  Created by Greg on 10/4/25.
//

import Observation
import OSLog
import SwiftData
import SwiftUI
import UIKit

@main
struct BedtimeApp: App {
    @State private var store = ModelContainerStore()

    init() {
        // Must happen synchronously before the app finishes launching, per
        // BGTaskScheduler's requirements.
        LiveActivityManager.registerBackgroundTask()
    }

    var body: some Scene {
        WindowGroup {
            RootView(store: store)
        }
    }
}

@MainActor
private struct RootView: View {
    let store: ModelContainerStore
    @State private var showingResetConfirmation = false

    init(store: ModelContainerStore) {
        self.store = store
        // Load synchronously on scene attach so normal unlocked launches render
        // ContentView on the first frame without flashing a ProgressView.
        store.loadIfNeeded()
    }

    private var isWaitingForProtectedData: Bool {
        store.modelContainer == nil && !store.loadFailed
    }

    var body: some View {
        Group {
            if let modelContainer = store.modelContainer {
                ContentView()
                    .modelContainer(modelContainer)
            } else if store.loadFailed {
                ContentUnavailableView {
                    Label("Unable to Load Settings", systemImage: "exclamationmark.triangle")
                } description: {
                    Text("Bedger couldn't open its settings store.")
                } actions: {
                    Button("Retry") {
                        store.retry()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Reset Settings", role: .destructive) {
                        showingResetConfirmation = true
                    }
                }
                .confirmationDialog(
                    "Reset Settings?",
                    isPresented: $showingResetConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Reset Settings", role: .destructive) {
                        store.resetStoreAndReload()
                    }
                } message: {
                    Text("This clears your saved sleep goal, wake time, and display preferences and recreates the settings store.")
                }
            } else {
                ProgressView()
            }
        }
        .task(id: isWaitingForProtectedData) {
            // If launched before first unlock (or locked mid-load), wait until
            // protected data becomes available before retrying automatically.
            guard isWaitingForProtectedData else { return }
            let iterator = NotificationCenter.default
                .notifications(named: UIApplication.protectedDataDidBecomeAvailableNotification)
                .makeAsyncIterator()
            store.loadIfNeeded()
            while isWaitingForProtectedData, await iterator.next() != nil {
                store.loadIfNeeded()
            }
        }
    }
}

@MainActor
@Observable
private final class ModelContainerStore {
    nonisolated init() {}
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.burnsides.bedtime",
        category: "SwiftData"
    )

    private(set) var modelContainer: ModelContainer?
    private(set) var loadFailed = false

    func loadIfNeeded() {
        guard modelContainer == nil,
              !loadFailed,
              UIApplication.shared.isProtectedDataAvailable else {
            return
        }

        if let container = Self.makePersistentContainer() {
            modelContainer = container
        } else if UIApplication.shared.isProtectedDataAvailable {
            loadFailed = true
        }
    }

    func retry() {
        loadFailed = false
        loadIfNeeded()
    }

    func resetStoreAndReload() {
        guard UIApplication.shared.isProtectedDataAvailable else {
            loadFailed = false
            return
        }
        let configuration = Self.makeConfiguration()
        Self.logger.warning("User requested SwiftData store reset at: \(configuration.url.path, privacy: .public)")
        Self.removeStoreFiles(at: configuration.url)
        loadFailed = false
        loadIfNeeded()
    }

    private static let schema = Schema([
        UserPreferences.self,
    ])

    private static func makeConfiguration() -> ModelConfiguration {
        ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
    }

    private static func makePersistentContainer() -> ModelContainer? {
        let modelConfiguration = makeConfiguration()

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            seedPreferencesIfNeeded(in: container)
            return container
        } catch {
            // Only discard the store automatically for explicitly identified schema
            // incompatibilities while unlocked. For all other errors (including opaque
            // loadIssueModelContainer failures that may be transient locks or file
            // protection), preserve the files on disk for retry or explicit user reset.
            guard UIApplication.shared.isProtectedDataAvailable,
                  isSchemaIncompatibilityError(error) else {
                logger.error("Persistent SwiftData store unavailable; preserving files on disk: \(error, privacy: .public)")
                return nil
            }

            logger.warning("Resetting incompatible SwiftData store after schema error: \(error, privacy: .public)")
            removeStoreFiles(at: modelConfiguration.url)

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

    private static func isSchemaIncompatibilityError(_ error: Error) -> Bool {
        if #available(iOS 18.0, *),
           SwiftDataError.backwardMigration ~= error || SwiftDataError.unknownSchema ~= error {
            return true
        }
        if #available(iOS 27.0, *), SwiftDataError.unknownDataStoreSchema ~= error {
            return true
        }
        return false
    }

    private static func removeStoreFiles(at storeURL: URL) {
        let fileManager = FileManager.default
        for suffix in ["", "-shm", "-wal"] {
            let url = URL(fileURLWithPath: storeURL.path + suffix)
            try? fileManager.removeItem(at: url)
        }
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
