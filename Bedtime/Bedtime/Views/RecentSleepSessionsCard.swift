//
//  RecentSleepSessionsCard.swift
//  Bedtime
//
//  Created by Greg on 10/4/25.
//

import SwiftUI

struct RecentSleepSessionsCard: View {
    let sessions: [SleepSession]
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.title2)
                    .foregroundColor(.purple)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recent Sleep")
                        .font(.headline)
                    
                    Text("Last \(sessions.count) nights")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Sleep sessions list
            VStack(spacing: 8) {
                ForEach(Array(sessions.enumerated()), id: \.offset) { index, session in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(dateFormatter.string(from: session.startDate))
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("\(timeFormatter.string(from: session.startDate)) - \(timeFormatter.string(from: session.endDate))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(String(format: "%.1f", session.durationInHours))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Text("hours")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    if index < sessions.count - 1 {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}
