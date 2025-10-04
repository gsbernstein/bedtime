//
//  BedtimeRecommendationCard.swift
//  Bedtime
//
//  Created by Greg on 10/4/25.
//

import SwiftUI

struct BedtimeRecommendationCard: View {
    let recommendation: BedtimeRecommendation
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "bed.double.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tonight's Recommendation")
                        .font(.headline)
                    
                    Text("Based on your sleep bank")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Recommendation details
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Recommended Bedtime")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(timeFormatter.string(from: recommendation.recommendedBedtime))
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Wake Time")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(timeFormatter.string(from: recommendation.wakeTime))
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                }
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Target Sleep Duration")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(String(format: "%.1f hours", recommendation.targetSleepDuration))
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                }
                
                // Reason text
                Text(recommendation.reason)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}
