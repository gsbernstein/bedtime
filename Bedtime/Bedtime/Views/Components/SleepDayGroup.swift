//
//  SleepDayGroup.swift
//  Bedtime
//
//  Created by Greg on 10/4/25.
//

import SwiftUI

struct SleepDayGroup: View {
    let date: Date
    let sessions: [SleepSession]
    let isExpanded: Bool
    let onToggle: () -> Void
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Day header (always visible)
            Button(action: onToggle) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(dateFormatter.string(from: date))
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("\(timeFormatter.string(from: sessions.last?.startDate ?? Date())) - \(timeFormatter.string(from: sessions.first?.endDate ?? Date()))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(TimeFormatter.formatDuration(sessions.reduce(0) { $0 + $1.duration }))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text("total")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Session details (expandable)
            if isExpanded {
                VStack(spacing: 4) {
                    ForEach(Array(sessions.enumerated()), id: \.offset) { index, session in
                        SleepSessionRow(session: session)
                        
                        if index < sessions.count - 1 {
                            Divider()
                        }
                    }
                }
                .padding(.leading, 16)
                .padding(.bottom, 8)
            }
        }
    }
}
