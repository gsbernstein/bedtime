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
        VStack(spacing: 16) {
            HStack {
                Image(systemName: sleepBank.isInDebt ? "moon.zzz.fill" : "moon.stars.fill")
                    .font(.title2)
                    .foregroundColor(sleepBank.averageHours == nil ? .secondary : sleepBank.isInDebt ? .red : .green)
                
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
                        }
                        
                        Text("hours")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
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
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    if (sleepBank.averageHours != nil) {
                        Rectangle()
                            .fill(sleepBank.isInDebt ? .red : .green)
                            .frame(
                                width: geometry.size.width * min(sleepBank.bankBalance / sleepBank.goalHours, 1),
                                height: 8
                            )
                            .cornerRadius(4)
                    }
                }
            }
            .frame(height: 8)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

#Preview {
    SleepBankCard(sleepBank: SleepBank(currentBalance: -0.8, goalHours: 8, averageHours: 7.5))
    SleepBankCard(sleepBank: SleepBank(currentBalance: 0.8, goalHours: 8, averageHours: 8.5))
    SleepBankCard(sleepBank: SleepBank(currentBalance: 0, goalHours: 8, averageHours: nil))
}
