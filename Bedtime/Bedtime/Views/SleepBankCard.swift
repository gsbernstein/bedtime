//
//  SleepBankCard.swift
//  Bedtime
//
//  Created by Greg on 10/4/25.
//

import SwiftUI

struct SleepBankCard: View {
    let sleepBank: SleepBank
    
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
                
                // Progress bar
                ProgressBar(value: sleepBank.bankBalance,
                             total: sleepBank.goalHours)
                    .tint(sleepBank.isInDebt ? .red : .green)
                    .rotationEffect(sleepBank.isInDebt ? .degrees(180) : .degrees(0))
            }
        }
    }
}

#Preview {
    SleepBankCard(sleepBank: SleepBank(currentBalance: -0.8, goalHours: 8, averageHours: 7.5))
    SleepBankCard(sleepBank: SleepBank(currentBalance: 0.8, goalHours: 8, averageHours: 8.5))
    SleepBankCard(sleepBank: SleepBank(currentBalance: 0, goalHours: 8, averageHours: nil))
}
