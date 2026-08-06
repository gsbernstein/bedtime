//
//  BalanceWaterfallChart.swift
//  Bedtime
//

import SwiftUI

struct BalanceWaterfallChart: View {
    let nights: [NightSummary]
    let impacts: [BalanceDayImpact]
    let domain: ClosedRange<Double>
    
    private var impactByDate: [Date: BalanceDayImpact] {
        Dictionary(uniqueKeysWithValues: impacts.map { ($0.date, $0) })
    }
    
    var body: some View {
        Canvas { context, size in
            guard !nights.isEmpty else { return }
            
            let slotWidth = size.width / CGFloat(nights.count)
            let span = domain.upperBound - domain.lowerBound
            guard span > 0 else { return }
            
            func yPosition(for value: Double) -> CGFloat {
                let normalized = (value - domain.lowerBound) / span
                return size.height * (1 - CGFloat(normalized))
            }
            
            var zeroLine = Path()
            let zeroY = yPosition(for: 0)
            zeroLine.move(to: CGPoint(x: 0, y: zeroY))
            zeroLine.addLine(to: CGPoint(x: size.width, y: zeroY))
            context.stroke(
                zeroLine,
                with: .color(.secondary.opacity(0.6)),
                style: StrokeStyle(lineWidth: 1)
            )
            
            for (index, night) in nights.enumerated() {
                guard let day = impactByDate[night.date] else { continue }
                
                let boxX = CGFloat(index) * slotWidth
                let priorY = yPosition(for: day.priorBalance)
                let newY = yPosition(for: day.newBalance)
                let rect = CGRect(
                    x: boxX,
                    y: min(priorY, newY),
                    width: slotWidth,
                    height: abs(newY - priorY)
                )
                
                context.fill(
                    Path(rect),
                    with: .color(day.isGain ? .green : .red)
                )
            }
        }
        .accessibilityLabel("Daily sleep balance changes over \(impacts.count) nights")
    }
}

#Preview {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    func night(_ daysAgo: Int, _ hours: Double) -> NightSummary {
        NightSummary(
            date: calendar.date(byAdding: .day, value: -daysAgo, to: today) ?? today,
            totalHours: hours,
            hasData: true
        )
    }
    let nights = [
        night(6, 6.5), night(5, 7.0), night(4, 8.0), night(3, 6.75),
        night(2, 7.5), night(1, 8.5), night(0, 7.25)
    ]
    let goal = 7.0
    var running = 0.0
    let impacts: [BalanceDayImpact] = nights.map { night in
        let prior = running
        let impact = night.totalHours - goal
        running += impact
        return BalanceDayImpact(date: night.date, priorBalance: prior, impact: impact)
    }
    let values = impacts.flatMap { [$0.priorBalance, $0.newBalance] }
    let magnitude = max(values.map(abs).max() ?? 0, 0.5)
    let domain = (-magnitude - 0.25)...(magnitude + 0.25)
    
    return BalanceWaterfallChart(nights: nights, impacts: impacts, domain: domain)
        .frame(height: 64)
        .padding()
}
