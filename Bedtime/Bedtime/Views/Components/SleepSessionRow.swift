//
//  SleepSessionRow.swift
//  Bedtime
//
//  Created by Greg on 10/4/25.
//

import SwiftUI
import HealthKit

struct SleepSessionRow: View {
    let session: SleepSession
    @Environment(\.durationDisplayStyle) private var durationStyle
    @Environment(\.appTheme) private var theme

    private var colors: any ThemeColorPalette { theme.colors }
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: session.sleepType.icon)
                .font(.caption)
                .foregroundColor(session.sleepType.color(in: colors))
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(TimeFormatter.formatTimeOfDay(session.startDate)) - \(TimeFormatter.formatTimeOfDay(session.endDate))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(session.sleepType.displayName)
                    .font(.caption2)
                    .foregroundColor(session.sleepType.color(in: colors))
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(TimeFormatter.formatDuration(session.duration, style: durationStyle))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(session.source.source.name)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    SleepSessionRow(session: SleepSession(startDate: Date(), endDate: Date(), sleepType: .asleepDeep, source: .init(source: .default(), version: "1")))
}
