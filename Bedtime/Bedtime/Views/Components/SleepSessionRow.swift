//
//  SleepSessionRow.swift
//  Bedtime
//
//  Created by Greg on 10/4/25.
//

import SwiftUI

struct SleepSessionRow: View {
    let session: SleepSession
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: session.sleepType.icon)
                    .font(.caption)
                    .foregroundColor(Color(session.sleepType.color))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(timeFormatter.string(from: session.startDate)) - \(timeFormatter.string(from: session.endDate))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(session.sleepType.displayName)
                        .font(.caption2)
                        .foregroundColor(Color(session.sleepType.color))
                }
            }
            
            Spacer()
            
            Text(TimeFormatter.formatDuration(session.duration))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 2)
    }
}
