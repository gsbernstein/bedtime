//
//  DuplicateCleanupRow.swift
//  Bedtime
//
//  A small, always-visible warning row for each detected duplicate-sync group on a night.
//  Deliberately independent of `SleepSourceComparisonView` (which only renders when there's
//  more than one source to compare) so it still shows up on nights with just a single source
//  — exactly the case a duplicate re-sync usually produces.
//

import SwiftUI

struct DuplicateCleanupRow: View {
    let groups: [DuplicateSleepGroup]
    let onReview: (DuplicateSleepGroup) -> Void

    var body: some View {
        if !groups.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(groups) { group in
                    Button {
                        onReview(group)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundStyle(.orange)

                            Text("Possible duplicate \(group.sourceName) data")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                                .lineLimit(1)

                            Spacer(minLength: 4)

                            Text("Review")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.orange)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Possible duplicate \(group.sourceName) data")
                    .accessibilityHint("Review and remove duplicate entries")
                }
            }
            .padding(.bottom, 6)
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    let now = Date()
    DuplicateCleanupRow(
        groups: [
            DuplicateSleepGroup(
                night: Calendar.current.startOfDay(for: now),
                sourceBundleID: "com.ouraring.oura",
                sourceName: "Oura",
                samples: []
            )
        ],
        onReview: { _ in }
    )
    .padding()
}
