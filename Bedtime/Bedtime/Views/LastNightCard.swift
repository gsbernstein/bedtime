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
    
    var durationInHours: TimeInterval? {
        sleepSessions?.map(\.durationInHours).reduce(0, +)
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
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
            
            if let sleepSessions {
                HStack {
                    VStack(alignment: .leading) {
                        Text("In bed at")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(timeFormatter.string(from: sleepSessions.first!.startDate))
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    Spacer()
                    VStack {
                        Text("Woke up at")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(timeFormatter.string(from: sleepSessions.last!.endDate))
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
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 8)
                            .cornerRadius(4)
                        
                        Rectangle()
                            .fill(durationInHours! > goal ? .green : .red)
                            .frame(
                                width: geometry.size.width * min(durationInHours! / goal, 1),
                                height: 8
                            )
                            .cornerRadius(4)
                    }
                }
                .frame(height: 8)
            } else {
                Text("No sleep data available")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding()
            }
            
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

import HealthKit

#Preview {
    LastNightCard(
        sleepSessions: [SleepSession(
            startDate: DateComponents(calendar: .autoupdatingCurrent, day: 1, hour: 23, minute: 10).date!,
            endDate: DateComponents(calendar: .autoupdatingCurrent, day: 2, hour: 6, minute: 35).date!,
            sleepType: .asleepUnspecified
        )],
        goal: 8
    )
    LastNightCard(
        sleepSessions: nil,
        goal: 8
    )
}
