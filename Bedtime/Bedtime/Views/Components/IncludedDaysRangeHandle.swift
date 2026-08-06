//
//  IncludedDaysRangeHandle.swift
//  Bedtime
//
//  Draggable boundary between nights included in the sleep-bank lookback
//  and nights that are history-only.
//

import SwiftUI

struct IncludedDaysRangeHandle: View {
    @Binding var days: Int
    var range: ClosedRange<Int> = Constants.sleepBankDaysRange
    /// Vertical distance that maps to one day while dragging.
    var rowStride: CGFloat = 56

    @State private var dragOriginDays: Int?

    var body: some View {
        HStack(spacing: 10) {
            Capsule()
                .fill(Color.accentColor.opacity(0.45))
                .frame(height: 3)

            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal")
                    .font(.caption.weight(.semibold))
                Text("\(days) days included")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.accentColor.opacity(0.12))
            )
            .overlay(
                Capsule()
                    .stroke(Color.accentColor.opacity(0.35), lineWidth: 1)
            )

            Capsule()
                .fill(Color.accentColor.opacity(0.45))
                .frame(height: 3)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .highPriorityGesture(dragGesture)
        .accessibilityElement()
        .accessibilityLabel("Days included in sleep balance")
        .accessibilityValue("\(days) days")
        .accessibilityHint("Drag up or down to change how many recent nights are included")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                days = min(range.upperBound, days + 1)
            case .decrement:
                days = max(range.lowerBound, days - 1)
            @unknown default:
                break
            }
        }
        .sensoryFeedback(.selection, trigger: days)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if dragOriginDays == nil {
                    dragOriginDays = days
                }
                guard let origin = dragOriginDays else { return }
                // List is newest-first: dragging down includes older nights.
                let delta = Int((value.translation.height / max(rowStride, 1)).rounded())
                let next = min(range.upperBound, max(range.lowerBound, origin + delta))
                if next != days {
                    days = next
                }
            }
            .onEnded { _ in
                dragOriginDays = nil
            }
    }
}

#Preview {
    struct PreviewHost: View {
        @State private var days = 7
        var body: some View {
            VStack {
                Text("Night A")
                IncludedDaysRangeHandle(days: $days)
                Text("Night B").opacity(0.45)
            }
            .padding()
        }
    }
    return PreviewHost()
}
