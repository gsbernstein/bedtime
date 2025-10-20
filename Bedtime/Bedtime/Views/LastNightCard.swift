//
//  LastNightCard.swift
//  Bedtime
//
//  Created by Greg on 10/17/25.
//

import SwiftUI

struct LastNightCard: View {
    let daySleepData: DaySleepData?
    let goal: TimeInterval
    
    var durationInHours: TimeInterval? {
        daySleepData?.totalNightSleepHours
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        CardComponent {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "calendar")
                        .font(.title2)
                        .foregroundColor(.blue)
                        .frame(width: Constants.iconWidth)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Last Night")
                            .font(.headline)
                    }
                    Spacer()
                }
                
                if let daySleepData, !daySleepData.nightSleep.isEmpty {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("In bed at")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(timeFormatter.string(from: daySleepData.nightSleep.last!.startDate))
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        Spacer()
                        VStack {
                            Text("Woke up at")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(timeFormatter.string(from: daySleepData.nightSleep.first!.endDate))
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("Sleep duration")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            HStack(alignment: .lastTextBaseline) {
                                Text(String(format: "%.1f", durationInHours!))
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(durationInHours! > goal ? .green : .red)
                                Text("hours")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Progress bar
                    ProgressBar(value: durationInHours!, total: goal)
                        .tint(durationInHours! > goal ? .green : .red)
                    
                    // Show naps if any
                    if !daySleepData.naps.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Naps: \(String(format: "%.1f", daySleepData.totalNapHours)) hours")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                } else {
                    Text("No sleep data available")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding()
                }
                
            }
        }
    }
}

import HealthKit

#Preview {
    LastNightCard(
        daySleepData: DaySleepData(
            date: Date(),
            allSessions: [SleepSession(
                startDate: DateComponents(calendar: .autoupdatingCurrent, day: 1, hour: 23, minute: 10).date!,
                endDate: DateComponents(calendar: .autoupdatingCurrent, day: 2, hour: 6, minute: 35).date!,
                sleepType: .asleepUnspecified,
                source: .init(source: .default(), version: nil)
            )]
        ),
        goal: 8
    )
    LastNightCard(
        daySleepData: nil,
        goal: 8
    )
}
