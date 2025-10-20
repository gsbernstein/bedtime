//
//  SleepProjectionCard.swift
//  Bedtime
//
//  Created by Greg on 10/4/25.
//

import SwiftUI

struct SleepProjectionCard: View {
    let sleepBank: SleepBank
    let goalHours: Double
    @State private var selectedHours: Double = 8.0
    
    private var projection: SleepProjection {
        SleepProjection.calculate(
            currentBalance: sleepBank.currentBalance,
            goalHours: goalHours,
            tonightHours: selectedHours
        )
    }
    
    var body: some View {
        CardComponent {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.title2)
                        .foregroundColor(.purple)
                        .frame(width: Constants.iconWidth)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sleep Projection")
                            .font(.headline)
                        
                        Text("How many days to catch up?")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                // Hours selector
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("If you get \(String(format: "%.1f", selectedHours)) hours tonight")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    
                    Slider(value: $selectedHours, in: 4...12, step: 0.5) {
                        EmptyView()
                    }
                    .accentColor(.purple)
                    
                    HStack {
                        Text("4h")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("12h")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Projection results
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Days to catch up")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("\(projection.daysToCatchUp)")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(projection.daysToCatchUp <= 3 ? .green : .orange)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Final balance")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(String(format: "%.1fh", projection.finalBalance))
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(projection.finalBalance >= 0 ? .green : .red)
                        }
                    }
                    
                    // Explanation
                    Text(projection.explanation)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
            }
        }
    }
}

struct SleepProjection {
    let daysToCatchUp: Int
    let finalBalance: Double
    let explanation: String
    
    static func calculate(currentBalance: Double, goalHours: Double, tonightHours: Double) -> SleepProjection {
        let tonightDeficit = goalHours - tonightHours
        let newBalance = currentBalance - tonightDeficit
        
        if newBalance >= 0 {
            return SleepProjection(
                daysToCatchUp: 0,
                finalBalance: newBalance,
                explanation: "You'll be caught up after tonight!"
            )
        }
        
        // Calculate how many days to catch up
        let dailyDeficit = goalHours - goalHours // This should be the average deficit per day
        let daysToCatchUp = Int(ceil(abs(newBalance) / goalHours))
        
        let explanation: String
        if daysToCatchUp <= 1 {
            explanation = "You'll be very close to caught up after tonight."
        } else if daysToCatchUp <= 3 {
            explanation = "You can catch up in \(daysToCatchUp) days with consistent sleep."
        } else {
            explanation = "It will take \(daysToCatchUp) days to fully catch up. Consider getting more sleep tonight."
        }
        
        return SleepProjection(
            daysToCatchUp: daysToCatchUp,
            finalBalance: newBalance,
            explanation: explanation
        )
    }
}

#Preview {
    SleepProjectionCard(
        sleepBank: SleepBank(
            currentBalance: -4.0,
            goalHours: 8.0,
            averageHours: 7.5
        ),
        goalHours: 8.0
    )
}
