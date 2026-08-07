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
    
    var durationInHours: TimeInterval? {
        sleepSessions?.map(\.durationInHours).reduce(0, +)
    }

    private var durationColor: Color {
        guard let durationInHours else { return .secondary }
        return Constants.sleepDurationColor(
            hours: durationInHours,
            goal: goal,
            graceColor: .primary
        )
    }
    
    var body: some View {
        CardComponent {
            VStack(spacing: 16) {
                CardHeader(
                    icon: "calendar",
                    iconColor: .blue,
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

#Preview {
    LastNightCard(
        sleepSessions: [SleepSession(
            startDate: DateComponents(calendar: .autoupdatingCurrent, day: 1, hour: 23, minute: 10).date!,
            endDate: DateComponents(calendar: .autoupdatingCurrent, day: 2, hour: 6, minute: 35).date!,
            sleepType: .asleepUnspecified,
            source: .init(source: .default(), version: nil)
        )],
        goal: 8,
        sourceAppLinks: []
    )
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
}
