//
//  DuplicateOverlapTimelineView.swift
//  Bedtime
//
//  Two aligned timeline lanes showing exactly which of a duplicate group's samples would be
//  kept vs. deleted at the current divider position, so dragging the divider gives an
//  immediate preview of the result.
//

import SwiftUI
import HealthKit

struct DuplicateOverlapTimelineView: View {
    let group: DuplicateSleepGroup
    let cutoff: Date

    private var resolution: DuplicateResolution {
        DuplicateSleepDetector.resolution(for: group, cutoff: cutoff)
    }

    private var timeRange: (start: Date, end: Date) {
        group.timeRange ?? (Date(), Date().addingTimeInterval(1))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            lane(title: "Keep", samples: resolution.toKeep, color: .green)
            lane(title: "Delete", samples: resolution.toDelete, color: .red)
        }
    }

    private func lane(title: String, samples: [DuplicateCandidateSample], color: Color) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(color)
                .frame(width: 44, alignment: .leading)

            Capsule()
                .fill(.foreground.quaternary)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        let rangeDuration = max(timeRange.end.timeIntervalSince(timeRange.start), 1)
                        ForEach(samples) { sample in
                            let offset = sample.startDate.timeIntervalSince(timeRange.start) / rangeDuration
                            let width = sample.duration / rangeDuration
                            Rectangle()
                                .fill(color)
                                .frame(width: max(proxy.size.width * CGFloat(width), 1))
                                .offset(x: proxy.size.width * CGFloat(offset))
                        }
                    }
                }
                .clipShape(Capsule())
                .frame(height: 18)
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    let now = Date()
    let olderBatch = now.addingTimeInterval(-3600)
    let newerBatch = now.addingTimeInterval(-3550)
    let group = DuplicateSleepGroup(
        night: Calendar.current.startOfDay(for: now),
        sourceBundleID: "com.ouraring.oura",
        sourceName: "Oura",
        samples: [
            DuplicateCandidateSample(id: UUID(), startDate: now.addingTimeInterval(-28800), endDate: now.addingTimeInterval(-25200), sleepType: .asleepCore, creationDate: olderBatch),
            DuplicateCandidateSample(id: UUID(), startDate: now.addingTimeInterval(-25200), endDate: now.addingTimeInterval(-21600), sleepType: .asleepDeep, creationDate: olderBatch),
            DuplicateCandidateSample(id: UUID(), startDate: now.addingTimeInterval(-28800), endDate: now.addingTimeInterval(-25200), sleepType: .asleepCore, creationDate: newerBatch),
            DuplicateCandidateSample(id: UUID(), startDate: now.addingTimeInterval(-25200), endDate: now.addingTimeInterval(-21600), sleepType: .asleepDeep, creationDate: newerBatch),
        ]
    )
    DuplicateOverlapTimelineView(group: group, cutoff: newerBatch.addingTimeInterval(-30))
        .padding()
}
