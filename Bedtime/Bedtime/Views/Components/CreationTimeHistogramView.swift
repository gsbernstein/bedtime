//
//  CreationTimeHistogramView.swift
//  Bedtime
//
//  A histogram of when a duplicate group's samples were added to HealthKit, with a
//  draggable divider that chooses the cutoff between the older (deleted) and newer
//  (kept) sync batch.
//

import SwiftUI
import HealthKit

struct CreationTimeHistogramView: View {
    let samples: [DuplicateCandidateSample]
    let range: ClosedRange<Date>
    @Binding var cutoff: Date

    private let bucketCount = 28
    private let handleAreaHeight: CGFloat = 28

    private var rangeDuration: TimeInterval {
        max(range.upperBound.timeIntervalSince(range.lowerBound), 1)
    }

    private var buckets: [Int] {
        var counts = [Int](repeating: 0, count: bucketCount)
        for sample in samples {
            guard let creationDate = sample.creationDate else { continue }
            let fraction = creationDate.timeIntervalSince(range.lowerBound) / rangeDuration
            let index = min(bucketCount - 1, max(0, Int(fraction * Double(bucketCount))))
            counts[index] += 1
        }
        return counts
    }

    private var maxCount: Int { max(buckets.max() ?? 1, 1) }

    private func fraction(for date: Date) -> CGFloat {
        CGFloat(min(max(date.timeIntervalSince(range.lowerBound) / rangeDuration, 0), 1))
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let totalHeight = proxy.size.height
            let barAreaHeight = max(totalHeight - handleAreaHeight, 1)
            let x = fraction(for: cutoff) * width

            ZStack(alignment: .topLeading) {
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(Array(buckets.enumerated()), id: \.offset) { _, count in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.accentColor.opacity(0.45))
                            .frame(maxWidth: .infinity)
                            .frame(height: count > 0 ? max(barAreaHeight * CGFloat(count) / CGFloat(maxCount), 3) : 0)
                    }
                }
                .frame(width: width, height: barAreaHeight, alignment: .bottom)
                .offset(y: handleAreaHeight)

                Rectangle()
                    .fill(Color.orange)
                    .frame(width: 2, height: totalHeight)
                    .position(x: x, y: totalHeight / 2)
                    .allowsHitTesting(false)

                dividerHandle
                    .position(x: x, y: handleAreaHeight / 2)
                    .allowsHitTesting(false)

                Color.clear
                    .frame(width: width, height: totalHeight)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let newFraction = min(max(value.location.x / width, 0), 1)
                                cutoff = range.lowerBound.addingTimeInterval(rangeDuration * Double(newFraction))
                            }
                    )
            }
        }
    }

    private var dividerHandle: some View {
        ZStack {
            Circle()
                .fill(Color.orange)
            Image(systemName: "arrow.left.and.right")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
        }
        .frame(width: 22, height: 22)
        .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    struct PreviewHost: View {
        let range: ClosedRange<Date>
        let samples: [DuplicateCandidateSample]
        @State private var cutoff: Date

        init() {
            let now = Date()
            let olderBatch = now.addingTimeInterval(-3600)
            let newerBatch = now
            range = olderBatch.addingTimeInterval(-600)...newerBatch.addingTimeInterval(600)
            samples = (0..<8).map { index in
                DuplicateCandidateSample(
                    id: UUID(),
                    startDate: now,
                    endDate: now.addingTimeInterval(1800),
                    sleepType: .asleepCore,
                    creationDate: index < 4 ? olderBatch.addingTimeInterval(Double(index) * 30) : newerBatch.addingTimeInterval(Double(index) * 30)
                )
            }
            _cutoff = State(initialValue: olderBatch.addingTimeInterval(1800))
        }

        var body: some View {
            CreationTimeHistogramView(samples: samples, range: range, cutoff: $cutoff)
                .frame(height: 120)
                .padding()
        }
    }
    return PreviewHost()
}
