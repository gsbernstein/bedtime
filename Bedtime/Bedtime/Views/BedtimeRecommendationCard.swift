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
    
    private var timeStatusMessage: String {
        let now = Date()
        let timeUntilBedtime = recommendation.goToBedTime.timeIntervalSince(now)
        
        if timeUntilBedtime <= 0 {
            return "Go to bed ASAP!"
        } else if timeUntilBedtime <= 30 * 60 { // 30 minutes
            return "Bedtime in \(Int(timeUntilBedtime / 60)) minutes"
        } else if timeUntilBedtime <= 60 * 60 { // 1 hour
            return "Bedtime in \(Int(timeUntilBedtime / 60)) minutes"
        } else if timeUntilBedtime <= 2 * 60 * 60 { // 2 hours
            return "Bedtime in \(String(format: "%.1f", timeUntilBedtime / 3600)) hours"
        } else {
            return "Based on your sleep bank"
        }
    }
    
    private var timeStatusColor: Color {
        let now = Date()
        let timeUntilBedtime = recommendation.goToBedTime.timeIntervalSince(now)
        
        if timeUntilBedtime <= 0 {
            return .red
        } else if timeUntilBedtime <= 30 * 60 { // 30 minutes
            return .orange
        } else {
            return .secondary
        }
    }
    
    var body: some View {
        CardComponent {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "bed.double.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                        .frame(width: Constants.iconWidth)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tonight")
                            .font(.headline)
                        
                        Text(timeStatusMessage)
                            .font(.subheadline)
                            .foregroundColor(timeStatusColor)
                    }
                    
                    Spacer()
                }
                
                // Recommendation details
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Go to Bed By")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(timeFormatter.string(from: recommendation.goToBedTime))
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
                    
                    // Fall asleep time
                    HStack {
                        Text("Fall asleep by:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(timeFormatter.string(from: recommendation.recommendedBedtime))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                    
                    // Reason text
                    Text(recommendation.reason)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .padding(.top, 4)
                }
            }
        }
    }
}

#Preview {
    BedtimeRecommendationCard(
        recommendation: BedtimeRecommendation(
            recommendedBedtime: Date(),
            goToBedTime: Date().addingTimeInterval(-3600),
            wakeTime: Date(),
            targetSleepDuration: 8,
            timeInBedBuffer: 0.5,
            reason: "Yo"
        )
    )
}
