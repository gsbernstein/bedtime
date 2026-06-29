//
//  SleepBankCard.swift
//  Bedtime
//
//  Created by Greg on 10/4/25.
//

import SwiftUI
import Charts

struct SleepBankCard: View {
    let sleepBank: SleepBank
    
    private var chartBalanceBounds: ClosedRange<Double> {
        let values = sleepBank.balanceCandles.flatMap { [$0.openingBalance, $0.closingBalance] }
        let magnitude = max(values.map(abs).max() ?? 0, 0.5)
        return (-magnitude - 0.25)...(magnitude + 0.25)
    }
    
    var body: some View {
        CardComponent {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: sleepBank.isInDebt ? "moon.zzz.fill" : "moon.stars.fill")
                        .font(.title2)
                        .foregroundColor(sleepBank.averageHours == nil ? .secondary : sleepBank.isInDebt ? .red : .green)
                        .frame(width: Constants.iconWidth)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sleep Balance")
                            .font(.headline)
                        
                        Text(sleepBank.statusDescription)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                // Balance visualization
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Average")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let averageHours = sleepBank.averageHours {
                            
                            HStack(alignment: .lastTextBaseline) {
                                Text(String(format: "%.1f", averageHours))
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(sleepBank.isInDebt ? .red : .green)
                                Text("hours")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                        } else {
                            Text("no recent data")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .center, spacing: 8) {
                        Text("Status")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if sleepBank.averageHours != nil {
                            HStack(alignment: .lastTextBaseline) {
                                Text(String(format: "%.1f", abs(sleepBank.currentBalance)))
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(sleepBank.isInDebt ? .red : .green)
                                
                                Text("hours \(sleepBank.isInDebt ? "behind" : "ahead")")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Text("unknown")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 8) {
                        Text("Goal")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack(alignment: .lastTextBaseline) {
                            Text(String(format: "%.1f", sleepBank.goalHours))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Text("hours")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if !sleepBank.balanceCandles.isEmpty {
                    balanceChart
                }
            }
        }
    }
}

private extension SleepBankCard {
    var balanceChart: some View {
        Chart {
            ForEach(sleepBank.balanceCandles) { candle in
                RectangleMark(
                    x: .value("Night", candle.date, unit: .day),
                    yStart: .value("Open", candle.openingBalance),
                    yEnd: .value("Close", candle.closingBalance),
                    width: .ratio(0.65)
                )
                .foregroundStyle(candle.isGain ? Color.green : Color.red)
                .cornerRadius(2)
            }
            
            RuleMark(y: .value("Even", 0))
                .foregroundStyle(.secondary.opacity(0.6))
                .lineStyle(StrokeStyle(lineWidth: 1))
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: chartBalanceBounds)
        .frame(height: 64)
        .accessibilityLabel("Daily sleep balance changes over the last \(sleepBank.balanceCandles.count) nights")
    }
}

#Preview {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    func night(_ daysAgo: Int, _ hours: Double, hasData: Bool = true) -> NightSummary {
        NightSummary(
            date: calendar.date(byAdding: .day, value: -daysAgo, to: today) ?? today,
            totalHours: hasData ? hours : 0,
            hasData: hasData
        )
    }
    let inDebtNights: [NightSummary] = [
        night(6, 6.5), night(5, 7.2), night(4, 0, hasData: false), night(3, 7.8),
        night(2, 6.8), night(1, 7.4), night(0, 7.0)
    ]
    let aheadNights: [NightSummary] = [
        night(6, 8.5), night(5, 8.2), night(4, 9.0), night(3, 7.5),
        night(2, 8.7), night(1, 8.8), night(0, 8.3)
    ]
    let emptyNights: [NightSummary] = (0..<7).reversed().map { night($0, 0, hasData: false) }
    
    return ScrollView {
        VStack {
            SleepBankCard(sleepBank: SleepBank(currentBalance: -0.8, goalHours: 8, averageHours: 7.5, recentNights: inDebtNights))
            SleepBankCard(sleepBank: SleepBank(currentBalance: 0.8, goalHours: 8, averageHours: 8.5, recentNights: aheadNights))
            SleepBankCard(sleepBank: SleepBank(currentBalance: 0, goalHours: 8, averageHours: nil, recentNights: emptyNights))
        }
        .padding()
    }
}
