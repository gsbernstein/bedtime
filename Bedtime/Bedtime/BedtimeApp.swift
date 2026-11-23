//
//  BedtimeApp.swift
//  Bedtime
//
//  Created by Greg on 10/4/25.
//

import SwiftUI
import UIKit

@main
struct BedtimeApp: App {
    @StateObject private var userPreferences = UserPreferences()

    var body: some Scene {
        WindowGroup {
            ContentView(userPreferences: userPreferences)
                .onReceive(
                    NotificationCenter.default.publisher(for: UIApplication.protectedDataDidBecomeAvailableNotification)
                ) { _ in
                    userPreferences.reload()
                }
        }
    }
}
