//
//  BedtimeActivityIntents.swift
//  Bedtime
//

import AppIntents

/// Starts tonight's countdown without bringing the app forward.
///
/// `LiveActivityIntent` is the sanctioned way to begin a Live Activity from the
/// background, which is what a time-based automation needs: iOS won't wake the app
/// on its own schedule, so the trigger has to come from the system.
struct StartBedtimeCountdownIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Start Bedtime Countdown"
    static let description = IntentDescription(
        "Shows tonight's bedtime countdown on the Lock Screen and in the Dynamic Island."
    )

    func perform() async throws -> some IntentResult {
        await LiveActivityManager.shared.startFromSavedPlan()
        return .result()
    }
}

struct EndBedtimeCountdownIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "End Bedtime Countdown"
    static let description = IntentDescription("Removes tonight's bedtime countdown.")

    func perform() async throws -> some IntentResult {
        await LiveActivityManager.shared.end()
        return .result()
    }
}

/// Surfaces both actions to Shortcuts and Siri so they can be attached to a
/// personal automation that runs at a fixed time each evening.
struct BedgerShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartBedtimeCountdownIntent(),
            phrases: ["Start my \(.applicationName) countdown"],
            shortTitle: "Start Bedtime Countdown",
            systemImageName: "bed.double.fill"
        )
        AppShortcut(
            intent: EndBedtimeCountdownIntent(),
            phrases: ["End my \(.applicationName) countdown"],
            shortTitle: "End Bedtime Countdown",
            systemImageName: "moon.zzz.fill"
        )
    }
}
