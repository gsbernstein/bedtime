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
    var rowStride: CGFloat = 64

    @GestureState private var dragTranslation: CGFloat = 0

    private var displayedDays: Int {
        clamped(days + dayDelta(for: dragTranslation))
    }

    var body: some View {
        ZStack(alignment: .leading) {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.accentColor)
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
            }
            .frame(width: 3)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.accentColor.opacity(0.45))
                    .frame(height: 2)

                HStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor)
                        Image(systemName: "arrow.up.and.down")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 28, height: 28)
                    .offset(x: -12)
                    .shadow(color: .black.opacity(0.12), radius: 2, y: 1)

                    Text("\(displayedDays) days included")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.cardBackground)
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color.accentColor.opacity(0.35), lineWidth: 1)
                        )
                        .offset(x: -12)
                }
            }
            // The boundary follows the finger without changing `days` (which
            // would relocate and destroy this gesture) until the drag ends.
            .offset(y: dragTranslation)
        }
        .frame(height: 32)
        .contentShape(Rectangle())
        .highPriorityGesture(dragGesture)
        .accessibilityElement()
        .accessibilityLabel("Days included in sleep balance")
        .accessibilityValue("\(displayedDays) days")
        .accessibilityHint("Drag up or down to change how many recent nights are included")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                days = clamped(days + 1)
            case .decrement:
                days = clamped(days - 1)
            @unknown default:
                break
            }
        }
        .sensoryFeedback(.selection, trigger: displayedDays)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .updating($dragTranslation) { value, state, _ in
                state = value.translation.height
            }
            .onEnded { value in
                // List is newest-first: dragging down includes older nights.
                days = clamped(days + dayDelta(for: value.translation.height))
            }
    }

    private func dayDelta(for translation: CGFloat) -> Int {
        Int((translation / max(rowStride, 1)).rounded())
    }

    private func clamped(_ value: Int) -> Int {
        min(range.upperBound, max(range.lowerBound, value))
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
