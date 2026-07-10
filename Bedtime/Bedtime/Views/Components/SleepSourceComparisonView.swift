//
//  SleepSourceComparisonView.swift
//  Bedtime
//

import SwiftUI
import HealthKit

/// Aligned per-source sleep stage timelines for quick cross-source comparison.
struct SleepSourceComparisonView: View {
    let sessions: [SleepSession]
    let excludedSourceIDs: Set<String>
    
    private struct SourceTrack: Identifiable {
        let id: String
        let name: String
        let sessions: [SleepSession]
        let isEnabled: Bool
    }
    
    private var sourceTracks: [SourceTrack] {
        let grouped = Dictionary(grouping: sessions) { $0.source.source.bundleIdentifier }
        return grouped
            .map { bundleID, sessions in
                SourceTrack(
                    id: bundleID,
                    name: sessions.first?.source.source.name ?? bundleID,
                    sessions: sessions.sorted { $0.startDate < $1.startDate },
                    isEnabled: !excludedSourceIDs.contains(bundleID)
                )
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    private var timeRange: (start: Date, end: Date)? {
        guard let start = sessions.map(\.startDate).min(),
              let end = sessions.map(\.endDate).max(),
              end > start else { return nil }
        return (start, end)
    }
    
    private var shouldShow: Bool {
        !sourceTracks.isEmpty && (
            sourceTracks.count > 1 ||
            sourceTracks.contains { !$0.isEnabled }
        )
    }
    
    var body: some View {
        if let timeRange, shouldShow {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(sourceTracks) { track in
                    HStack(spacing: 6) {
                        Text(track.name)
                            .font(.caption2)
                            .foregroundStyle(track.isEnabled ? .secondary : .tertiary)
                            .lineLimit(1)
                            .frame(width: 72, alignment: .leading)
                        
                        SleepStageTimelineBar(
                            sessions: track.sessions,
                            rangeStart: timeRange.start,
                            rangeEnd: timeRange.end,
                            isDimmed: !track.isEnabled
                        )
                    }
                }
            }
            .padding(.bottom, 6)
        }
    }
}

/// A single horizontal bar with color-coded sleep stage segments.
struct SleepStageTimelineBar: View {
    let sessions: [SleepSession]
    let rangeStart: Date
    let rangeEnd: Date
    var isDimmed: Bool = false
    
    private var rangeDuration: TimeInterval {
        max(rangeEnd.timeIntervalSince(rangeStart), 1)
    }
    
    var body: some View {
        Capsule()
            .fill(.foreground.quaternary)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    ForEach(Array(sessions.enumerated()), id: \.offset) { _, session in
                        let offset = session.startDate.timeIntervalSince(rangeStart) / rangeDuration
                        let width = session.duration / rangeDuration
                        
                        Capsule()
                            .fill(session.sleepType.color)
                            .opacity(isDimmed ? 0.35 : 1)
                            .frame(width: max(proxy.size.width * width, 1))
                            .offset(x: proxy.size.width * offset)
                    }
                }
            }
            .clipShape(Capsule())
            .frame(height: 6)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    let sourceA = HKSourceRevision(source: .default(), version: "1")
    let sourceB = HKSourceRevision(source: .default(), version: "2")
    let bedTime = Calendar.current.date(bySettingHour: 23, minute: 0, second: 0, of: Date())!
    
    SleepSourceComparisonView(
        sessions: [
            SleepSession(startDate: bedTime, endDate: bedTime.addingTimeInterval(3600), sleepType: .asleepCore, source: sourceA),
            SleepSession(startDate: bedTime.addingTimeInterval(3600), endDate: bedTime.addingTimeInterval(7200), sleepType: .asleepDeep, source: sourceA),
            SleepSession(startDate: bedTime.addingTimeInterval(300), endDate: bedTime.addingTimeInterval(5400), sleepType: .asleepCore, source: sourceB),
            SleepSession(startDate: bedTime.addingTimeInterval(5400), endDate: bedTime.addingTimeInterval(7800), sleepType: .asleepREM, source: sourceB),
        ],
        excludedSourceIDs: ["com.example.disabled"]
    )
    .padding()
}
