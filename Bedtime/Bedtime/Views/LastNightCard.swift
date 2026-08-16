//
//  LastNightCard.swift
//  Bedtime
//
//  Created by Greg on 10/17/25.
//

import SwiftUI

struct LastNightCard: View {
    let sleepSessions: [SleepSession]?
    let goal: TimeInterval
    let sourceAppLinks: [SleepSourceAppLink]
    @Environment(\.durationDisplayStyle) private var durationStyle
    @Environment(\.appTheme) private var theme

    private var colors: any ThemeColorPalette { theme.colors }
    
    var durationInHours: TimeInterval? {
        sleepSessions?.map(\.durationInHours).reduce(0, +)
    }

    private var durationColor: Color {
        guard let durationInHours else { return .secondary }
        let keypath = Constants.sleepDurationColor(
            hours: durationInHours,
            goal: goal
        ) ?? \.primary
        return colors[keyPath: keypath]
    }
    
    var body: some View {
        CardComponent {
            VStack(spacing: 16) {
                CardHeader(
                    icon: "calendar",
                    iconColor: colors.lastNight,
                    title: "Last Night"
                )
                
                if let sleepSessions {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("In bed at")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(TimeFormatter.formatTimeOfDay(sleepSessions.last!.startDate))
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        Spacer()
                        VStack {
                            Text("Woke up at")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(TimeFormatter.formatTimeOfDay(sleepSessions.first!.endDate))
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("Sleep duration")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(TimeFormatter.formatHours(durationInHours!, style: durationStyle))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(durationColor)
                        }
                    }
                    
                    // Progress bar
                    ProgressBar(value: durationInHours!, total: goal)
                        .tint(durationColor)
                    
                } else {
                    VStack(spacing: 12) {
                        Text("No sleep data available")
                            .font(.body)
                            .foregroundColor(.secondary)

                        if !sourceAppLinks.isEmpty {
                            Text("Open a recent source app to sync last night's sleep.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)

                            ForEach(sourceAppLinks) { sourceApp in
                                Link(destination: sourceApp.destination) {
                                    Label(
                                        "Open \(sourceApp.name)",
                                        systemImage: "arrow.up.forward.app"
                                    )
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                    .padding()
                }
                
            }
        }
    }
}

import HealthKit

#if DEBUG

/// A single overnight session ending at 6:35am, long enough back to give a plausible bedtime.
private func previewNight(hours: Double) -> SleepSession {
    let wakeTime = Calendar.current.date(bySettingHour: 6, minute: 35, second: 0, of: Date()) ?? Date()
    return SleepSession(
        startDate: wakeTime.addingTimeInterval(-hours * 3600),
        endDate: wakeTime,
        sleepType: .asleepUnspecified,
        source: .init(source: .default(), version: nil)
    )
}

#Preview("Met goal") {
    LastNightCard(sleepSessions: [previewNight(hours: 8.2)], goal: 8, sourceAppLinks: [])
        .padding()
        .background(AppTheme.cozy.colors.background)
}

#Preview("Short night") {
    LastNightCard(sleepSessions: [previewNight(hours: 5.75)], goal: 8, sourceAppLinks: [])
        .padding()
        .background(AppTheme.cozy.colors.background)
}

#Preview("No data") {
    LastNightCard(sleepSessions: nil, goal: 8, sourceAppLinks: [])
        .padding()
        .background(AppTheme.cozy.colors.background)
}

#Preview("No data, with source apps") {
    LastNightCard(
        sleepSessions: nil,
        goal: 8,
        sourceAppLinks: [
            SleepSourceAppLink(
                id: "com.ouraring.oura",
                name: "Oura",
                destination: URL(string: "https://cloud.ouraring.com/app/v1/home")!,
                lastDataDate: .now
            )
        ]
    )
    .padding()
    .background(AppTheme.cozy.colors.background)
}

#endif
