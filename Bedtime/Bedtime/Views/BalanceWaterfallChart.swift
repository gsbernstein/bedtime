//
//  BalanceWaterfallChart.swift
//  Bedtime
//

import SwiftUI

/// Cumulative sleep-balance waterfall across the whole lookback window.
///
/// The chart always draws every night the range start can be moved to, so it keeps a
/// fixed width while the selected range changes. Tapping a column starts the range on
/// that night. A static line marks the balance carried out of the most recent night, and
/// the gap between it and the balance carried into the selected range is the balance the
/// card reports.
///
/// Because every column is a step in one running total, any ending balance above the
/// range's starting balance produces a positive range and any ending balance below it
/// produces a negative one — that is what the green and red background bands mark out.
/// The bands are anchored to the range's starting balance, so they move as the selected
/// range changes.
struct BalanceWaterfallChart: View {
    /// Cap on the rounding of a step's unanchored corners, so wide or tall columns stay
    /// recognizably rectangular.
    private static let maxStepCornerRadius: CGFloat = 3

    /// Every night in the window, oldest first.
    let nights: [NightSummary]
    /// Per-night balance steps, cumulative over the whole window. Nights without sleep
    /// data have no step and keep their column empty.
    let impacts: [BalanceDayImpact]
    let domain: ClosedRange<Double>
    @Binding var selectedDays: Int
    var daysRange: ClosedRange<Int> = Constants.sleepBankDaysRange
    @Environment(\.appTheme) private var theme

    private var colors: any ThemeColorPalette { theme.colors }

    private var impactByDate: [Date: BalanceDayImpact] {
        Dictionary(uniqueKeysWithValues: impacts.map { ($0.date, $0) })
    }

    /// Balance carried into each column, plus a trailing entry for the end of the window.
    private var carriedBalances: [Double] {
        var running = 0.0
        var balances: [Double] = []
        for night in nights {
            balances.append(running)
            running += impactByDate[night.date]?.impact ?? 0
        }
        balances.append(running)
        return balances
    }

    private var endingBalance: Double {
        carriedBalances.last ?? 0
    }

    private var clampedSelectedDays: Int {
        min(daysRange.upperBound, max(daysRange.lowerBound, selectedDays))
    }

    /// First column included in the selected range.
    private var selectionStartIndex: Int {
        max(0, nights.count - clampedSelectedDays)
    }

    private var baselineBalance: Double {
        let balances = carriedBalances
        return balances[min(selectionStartIndex, balances.count - 1)]
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                aboveBelowBands(size: proxy.size)
                columns(size: proxy.size)
                endingBalanceLine(size: proxy.size)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sleep balance by night")
        .accessibilityValue("Range starts \(clampedSelectedDays) days ago")
        .accessibilityHint("Tap a night to start the range there")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                select(days: clampedSelectedDays + 1)
            case .decrement:
                select(days: clampedSelectedDays - 1)
            @unknown default:
                break
            }
        }
        .sensoryFeedback(.selection, trigger: clampedSelectedDays)
    }

    /// Light bands split at the baseline balance carried into the selected range: if the
    /// most recent night ends up in the green band above, the range gained ground; if it
    /// ends up in the red band below, the range lost ground. Because the split is anchored
    /// to the range's starting balance, it shifts whenever the selected range changes.
    private func aboveBelowBands(size: CGSize) -> some View {
        let dividerY = min(max(yPosition(for: baselineBalance, in: size.height), 0), size.height)
        return VStack(spacing: 0) {
            Rectangle()
                .fill(colors.positive.opacity(0.1))
                .frame(height: dividerY)
            Rectangle()
                .fill(colors.negative.opacity(0.1))
        }
    }

    private func columns(size: CGSize) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(nights.enumerated()), id: \.element.id) { pair in
                column(at: pair.offset, night: pair.element, size: size)
            }
        }
    }

    private func column(at index: Int, night: NightSummary, size: CGSize) -> some View {
        let step = impactByDate[night.date]
        let isIncluded = index >= selectionStartIndex

        return ZStack(alignment: .top) {
            if let step {
                let priorY = yPosition(for: step.priorBalance, in: size.height)
                let newY = yPosition(for: step.newBalance, in: size.height)
                let stepHeight = abs(newY - priorY)
                stepShape(isGain: step.isGain, stepHeight: stepHeight, chartWidth: size.width)
                    .fill(step.isGain ? colors.positive : colors.negative)
                    .opacity(isIncluded ? 1 : 0.3)
                    .frame(height: max(stepHeight, 1))
                    .offset(y: min(priorY, newY))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .contentShape(Rectangle())
        .onTapGesture { select(days: nights.count - index) }
    }

    /// The running balance enters a step at the prior balance and leaves at the new one, so a
    /// gain is anchored bottom-leading to top-trailing and a loss top-leading to
    /// bottom-trailing. Only the other two corners round off, which keeps the anchored corners
    /// flush with the neighboring steps they connect to.
    ///
    /// The rounded corners are diagonally opposite, so they never share an edge and can each
    /// take up the step's full height and width rather than half of it.
    ///
    /// `stepHeight` is the balance change before it is floored to a visible minimum, so a night
    /// that lands on the goal keeps the square ends its flat connector wants.
    private func stepShape(isGain: Bool, stepHeight: CGFloat, chartWidth: CGFloat) -> UnevenRoundedRectangle {
        let columnWidth = nights.isEmpty ? chartWidth : chartWidth / CGFloat(nights.count)
        let radius = min(Self.maxStepCornerRadius, columnWidth, stepHeight)
        return UnevenRoundedRectangle(
            topLeadingRadius: isGain ? radius : 0,
            bottomLeadingRadius: isGain ? 0 : radius,
            bottomTrailingRadius: isGain ? radius : 0,
            topTrailingRadius: isGain ? 0 : radius,
            style: .continuous
        )
    }

    /// A single static line at the balance carried out of the most recent night, unaffected
    /// by the selected range.
    private func endingBalanceLine(size: CGSize) -> some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.6))
            .frame(width: size.width, height: 1)
            .offset(y: yPosition(for: endingBalance, in: size.height))
    }

    private func yPosition(for value: Double, in height: CGFloat) -> CGFloat {
        let span = domain.upperBound - domain.lowerBound
        guard span > 0 else { return height / 2 }
        let normalized = (value - domain.lowerBound) / span
        return height * (1 - CGFloat(normalized))
    }

    private func select(days: Int) {
        let clamped = min(daysRange.upperBound, max(daysRange.lowerBound, days))
        guard clamped != selectedDays else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedDays = clamped
        }
    }
}

#if DEBUG

private struct BalanceWaterfallChartPreview: View {
    /// Hours slept per night, oldest first. `nil` is a night with no tracked sleep, which
    /// contributes no step and leaves its column empty.
    let hoursPerNight: [Double?]
    var goal = 7.0

    @State private var days = 7

    private var nights: [NightSummary] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return hoursPerNight.enumerated().map { offset, hours in
            NightSummary(
                date: calendar.date(byAdding: .day, value: offset - (hoursPerNight.count - 1), to: today) ?? today,
                totalHours: hours
            )
        }
    }

    private var impacts: [BalanceDayImpact] {
        var running = 0.0
        return nights.compactMap { night in
            guard let totalHours = night.totalHours else { return nil }
            let impact = totalHours - goal
            let prior = running
            running += impact
            return BalanceDayImpact(date: night.date, priorBalance: prior, impact: impact)
        }
    }

    var body: some View {
        let values = impacts.flatMap { [$0.priorBalance, $0.newBalance] }
        let magnitude = max(values.map(abs).max() ?? 0, 0.5)

        return VStack(spacing: 16) {
            BalanceWaterfallChart(
                nights: nights,
                impacts: impacts,
                domain: (-magnitude - 0.25)...(magnitude + 0.25),
                selectedDays: $days
            )
            .frame(height: 64)

            Text("\(days) days selected")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview("Gains and losses") {
    BalanceWaterfallChartPreview(hoursPerNight: [
        6.5, 7.0, 8.0, 6.75, 5.5, 6.25, 7.5,
        8.5, 7.25, 6.0, 7.75, 8.25, 7.0, 6.5
    ])
}

#Preview("Ahead every night") {
    BalanceWaterfallChartPreview(hoursPerNight: [
        7.4, 7.8, 7.25, 8.0, 7.5, 7.9, 8.2,
        7.6, 8.4, 7.3, 7.7, 8.1, 7.45, 7.95
    ])
}

#Preview("Behind every night") {
    BalanceWaterfallChartPreview(hoursPerNight: [
        6.6, 6.2, 6.75, 5.9, 6.4, 6.05, 6.5,
        6.3, 5.75, 6.6, 6.15, 6.45, 6.8, 6.1
    ])
}

#Preview("Missing nights") {
    BalanceWaterfallChartPreview(hoursPerNight: [
        6.5, nil, 8.0, nil, nil, 6.25, 7.5,
        8.5, nil, 6.0, 7.75, nil, 7.0, 6.5
    ])
}

#endif
