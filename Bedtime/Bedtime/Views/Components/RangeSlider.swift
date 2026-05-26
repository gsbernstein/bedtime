//
//  RangeSlider.swift
//  Bedtime
//
//  Created by Greg on 5/25/26.
//

import SwiftUI

/// A two-thumb slider for picking a closed sub-range from a larger domain.
///
/// The thumbs are constrained so that `lowerValue` cannot exceed `upperValue - minimumDistance`
/// and `upperValue` cannot fall below `lowerValue + minimumDistance`. Values snap to the
/// nearest multiple of `step` within `bounds`.
struct RangeSlider<Value: BinaryFloatingPoint>: View where Value.Stride: BinaryFloatingPoint {
    @Binding var lowerValue: Value
    @Binding var upperValue: Value
    let bounds: ClosedRange<Value>
    var step: Value = 1
    /// Minimum gap (in domain units) enforced between the two thumbs. Defaults to `step`.
    var minimumDistance: Value? = nil

    private let thumbSize: CGFloat = 28
    private let trackHeight: CGFloat = 4

    @State private var activeThumb: Thumb?

    private enum Thumb { case lower, upper }

    private var enforcedMinimumDistance: Value {
        minimumDistance ?? step
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let usableWidth = max(width - thumbSize, 0)
            let lowerX = position(for: lowerValue, in: usableWidth)
            let upperX = position(for: upperValue, in: usableWidth)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.25))
                    .frame(height: trackHeight)
                    .padding(.horizontal, thumbSize / 2)

                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: max(upperX - lowerX, 0), height: trackHeight)
                    .offset(x: lowerX + thumbSize / 2)

                thumb(at: lowerX, isActive: activeThumb == .lower)
                    .gesture(dragGesture(for: .lower, usableWidth: usableWidth))
                    .accessibilityLabel("Lower value")
                    .accessibilityValue(Text("\(Double(lowerValue), specifier: "%.0f")"))
                    .accessibilityAdjustableAction { direction in
                        adjust(.lower, direction: direction)
                    }

                thumb(at: upperX, isActive: activeThumb == .upper)
                    .gesture(dragGesture(for: .upper, usableWidth: usableWidth))
                    .accessibilityLabel("Upper value")
                    .accessibilityValue(Text("\(Double(upperValue), specifier: "%.0f")"))
                    .accessibilityAdjustableAction { direction in
                        adjust(.upper, direction: direction)
                    }
            }
            .frame(height: thumbSize)
        }
        .frame(height: thumbSize)
    }

    private func thumb(at x: CGFloat, isActive: Bool) -> some View {
        Circle()
            .fill(Color.white)
            .overlay(
                Circle().stroke(Color.black.opacity(0.05), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.18), radius: isActive ? 4 : 2, x: 0, y: 1)
            .frame(width: thumbSize, height: thumbSize)
            .scaleEffect(isActive ? 1.08 : 1)
            .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.8), value: isActive)
            .offset(x: x)
            .contentShape(Rectangle().inset(by: -8))
    }

    private func dragGesture(for thumb: Thumb, usableWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                activeThumb = thumb
                let xWithinTrack = gesture.location.x - thumbSize / 2
                let raw = value(at: xWithinTrack, usableWidth: usableWidth)
                let snapped = snap(raw)
                switch thumb {
                case .lower:
                    let maxAllowed = upperValue - enforcedMinimumDistance
                    lowerValue = min(max(snapped, bounds.lowerBound), maxAllowed)
                case .upper:
                    let minAllowed = lowerValue + enforcedMinimumDistance
                    upperValue = max(min(snapped, bounds.upperBound), minAllowed)
                }
            }
            .onEnded { _ in
                activeThumb = nil
            }
    }

    private func adjust(_ thumb: Thumb, direction: AccessibilityAdjustmentDirection) {
        let delta: Value = direction == .increment ? step : -step
        switch thumb {
        case .lower:
            let next = lowerValue + delta
            let maxAllowed = upperValue - enforcedMinimumDistance
            lowerValue = min(max(next, bounds.lowerBound), maxAllowed)
        case .upper:
            let next = upperValue + delta
            let minAllowed = lowerValue + enforcedMinimumDistance
            upperValue = max(min(next, bounds.upperBound), minAllowed)
        }
    }

    private func position(for value: Value, in usableWidth: CGFloat) -> CGFloat {
        let span = bounds.upperBound - bounds.lowerBound
        guard span > 0 else { return 0 }
        let ratio = CGFloat((value - bounds.lowerBound) / span)
        return ratio * usableWidth
    }

    private func value(at x: CGFloat, usableWidth: CGFloat) -> Value {
        guard usableWidth > 0 else { return bounds.lowerBound }
        let clampedX = min(max(x, 0), usableWidth)
        let ratio = Value(clampedX / usableWidth)
        return bounds.lowerBound + ratio * (bounds.upperBound - bounds.lowerBound)
    }

    private func snap(_ value: Value) -> Value {
        guard step > 0 else { return value }
        let offset = value - bounds.lowerBound
        let steps = (offset / step).rounded()
        return bounds.lowerBound + steps * step
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    struct PreviewHost: View {
        @State private var lower: Double = 5
        @State private var upper: Double = 10

        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Min: \(Int(lower))h")
                    Spacer()
                    Text("Max: \(Int(upper))h")
                }
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)

                RangeSlider(
                    lowerValue: $lower,
                    upperValue: $upper,
                    bounds: 2...16,
                    step: 1
                )
            }
            .padding()
        }
    }

    return PreviewHost()
}
