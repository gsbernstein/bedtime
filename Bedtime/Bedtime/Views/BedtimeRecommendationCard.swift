//
//  BedtimeRecommendationCard.swift
//  Bedtime
//
//  Created by Greg on 10/4/25.
//

import SwiftUI

struct BedtimeRecommendationCard: View {
    let recommendation: BedtimeRecommendation
    @ObservedObject var liveActivityManager: LiveActivityManager
    
    var body: some View {
        CardComponent {
            VStack(spacing: 16) {
                CardHeader(
                    icon: "bed.double.fill",
                    iconColor: .blue,
                    title: "Tonight's Recommendation"
                ) {
                    Text("Based on your sleep bank")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Recommendation details
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Recommended Bedtime")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(TimeFormatter.formatTimeOfDay(recommendation.recommendedBedtime))
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Wake Time")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(TimeFormatter.formatTimeOfDay(recommendation.wakeTime))
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                    }
                    
                    // Reason text (omitted when the sleep insight card covers it)
                    if let reason = recommendation.reason {
                        Text(reason)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                            .padding(.top, 4)
                    }

                    Divider()

                    liveActivityControls
                }
            }
        }
    }

    @ViewBuilder
    private var liveActivityControls: some View {
        if liveActivityManager.areActivitiesEnabled {
            HStack(spacing: 12) {
                Button {
                    Task {
                        await liveActivityManager.startOrUpdate(with: recommendation)
                    }
                } label: {
                    Label(
                        liveActivityManager.isActivityActive
                            ? "Update Live Activity"
                            : "Start Live Activity",
                        systemImage: "wave.3.right.circle.fill"
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(liveActivityManager.isWorking)

                if liveActivityManager.isActivityActive {
                    Button("End", role: .destructive) {
                        Task {
                            await liveActivityManager.end()
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(liveActivityManager.isWorking)
                }

                if liveActivityManager.isWorking {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Label(
                "Enable Live Activities for Bedger in system settings.",
                systemImage: "exclamationmark.circle"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        if let errorMessage = liveActivityManager.lastErrorMessage {
            Text(errorMessage)
                .font(.caption)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    BedtimeRecommendationCard(
        recommendation: BedtimeRecommendation(
            recommendedBedtime: Date(),
            wakeTime: Date(),
            targetSleepDuration: 8,
            reason: "You’re on track for a full night of sleep."
        ),
        liveActivityManager: LiveActivityManager()
    )
}
