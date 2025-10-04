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
                    .foregroundColor(sleepBank.isInDebt ? .red : .green)
                
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
                    
                    HStack(alignment: .bottom) {
                        Text(String(format: "%.1f", abs(sleepBank.averageHours)))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(sleepBank.isInDebt ? .red : .green)
                        
                        Text("hours")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .center, spacing: 8) {
                    Text("Status")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(alignment: .bottom) {
                        Text(String(format: "%.1f", abs(sleepBank.currentBalance)))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(sleepBank.isInDebt ? .red : .green)
                            
                        Text("hours \(sleepBank.isInDebt ? "behind" : "ahead")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 8) {
                    Text("Goal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(alignment: .bottom) {
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
                    
                    Rectangle()
                        .fill(sleepBank.isInDebt ? Color.red : Color.green)
                        .frame(
                            width: min(geometry.size.width, geometry.size.width * (sleepBank.bankBalance / sleepBank.goalHours)),
                            height: 8
                        )
                        .cornerRadius(4)
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
