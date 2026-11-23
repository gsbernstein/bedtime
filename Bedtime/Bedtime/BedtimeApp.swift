//
//  BedtimeApp.swift
//  Bedtime
//
//  Created by Greg on 10/4/25.
//

import SwiftUI
import SwiftData
import UIKit

@main
struct BedtimeApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var modelContainer: ModelContainer
    @State private var isUsingInMemoryStore: Bool

    init() {
        if UIApplication.shared.isProtectedDataAvailable,
           let persistentContainer = Self.makePersistentContainer() {
            _modelContainer = State(initialValue: persistentContainer)
            _isUsingInMemoryStore = State(initialValue: false)
        } else {
            _modelContainer = State(initialValue: Self.makeInMemoryContainer())
            _isUsingInMemoryStore = State(initialValue: true)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .id(isUsingInMemoryStore)
                .onReceive(
                    NotificationCenter.default.publisher(for: UIApplication.protectedDataDidBecomeAvailableNotification)
                ) { _ in
                    switchToPersistentContainerIfAvailable()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        switchToPersistentContainerIfAvailable()
                    }
                }
        }
        .modelContainer(modelContainer)
    }

    private func switchToPersistentContainerIfAvailable() {
        guard isUsingInMemoryStore,
              UIApplication.shared.isProtectedDataAvailable,
              let persistentContainer = Self.makePersistentContainer() else {
            return
        }
        modelContainer = persistentContainer
        isUsingInMemoryStore = false
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
            // While locked before first unlock (e.g. background launch after a reboot),
            // opening the on-disk store fails with a file-protection/permission error.
            // Never delete the store or fatalError in that case; fall back to an in-memory
            // container until protected data becomes available.
            guard UIApplication.shared.isProtectedDataAvailable,
                  !isFileAccessError(error) else {
                print("[Bedtime] Persistent SwiftData store unavailable while protected, deferring load: \(error)")
                return nil
            }

            // The store on disk can be incompatible with the current schema after a
            // model change that SwiftData can't lightweight-migrate (e.g. the max-hours
            // → earliestReasonableBedtime refactor). Only when unlocked and not a file-access
            // error, discard the stale store and rebuild it.
            print("[Bedtime] Resetting incompatible SwiftData store after error: \(error)")
            let storeURL = modelConfiguration.url
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
                print("[Bedtime] Could not recreate persistent SwiftData store, falling back to in-memory: \(error)")
                return nil
            }
        }
    }

    private static func makeInMemoryContainer() -> ModelContainer {
        let schema = Schema([
            UserPreferences.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create in-memory ModelContainer: \(error)")
        }
    }

    @MainActor
    private static func seedPreferencesIfNeeded(in container: ModelContainer) {
        let context = container.mainContext
        guard let count = try? context.fetchCount(FetchDescriptor<UserPreferences>()),
              count == 0 else {
            return
        }
        context.insert(UserPreferences())
        try? context.save()
    }

    private static func isFileAccessError(_ error: Error) -> Bool {
        var queue: [NSError] = [error as NSError]
        var visited = Set<ObjectIdentifier>()

        while let current = queue.popLast() {
            let identifier = ObjectIdentifier(current)
            guard visited.insert(identifier).inserted else { continue }

            switch current.domain {
            case NSCocoaErrorDomain:
                if current.code == NSFileReadNoPermissionError
                    || current.code == NSFileWriteNoPermissionError
                    || current.code == NSFileLockingError {
                    return true
                }
            case NSPOSIXErrorDomain:
                if current.code == Int(POSIXError.EPERM.rawValue)
                    || current.code == Int(POSIXError.EACCES.rawValue) {
                    return true
                }
            case "NSSQLiteErrorDomain":
                // SQLITE_PERM (3), SQLITE_CANTOPEN (14), SQLITE_AUTH (23)
                if current.code == 3 || current.code == 14 || current.code == 23 {
                    return true
                }
            default:
                break
            }

            if let underlying = current.userInfo[NSUnderlyingErrorKey] as? NSError {
                queue.append(underlying)
            }
            queue.append(contentsOf: current.underlyingErrors.map { $0 as NSError })
        }

        return false
    }
}
