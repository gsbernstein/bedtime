//
//  BedtimeRecommendationCard.swift
//  Bedtime
//
//  Created by Greg on 10/4/25.
//

import SwiftUI

struct BedtimeRecommendationCard: View {
    let recommendation: BedtimeRecommendation
    /// When provided, the wake time is tappable and edits this value directly.
    var wakeTime: Binding<Date>? = nil

    @State private var isEditingWakeTime = false

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
                        
                        if let wakeTime {
                            editableWakeTime(wakeTime)
                        } else {
                            wakeTimeLabel(showsEditAffordance: false)
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
                }
            }
        }
    }

    private func editableWakeTime(_ wakeTime: Binding<Date>) -> some View {
        Button {
            isEditingWakeTime = true
        } label: {
            wakeTimeLabel(showsEditAffordance: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Wake time")
        .accessibilityValue(TimeFormatter.formatTimeOfDay(recommendation.wakeTime))
        .accessibilityHint("Adjusts the wake time used for your recommendation")
        .popover(isPresented: $isEditingWakeTime) {
            WakeTimeEditor(wakeTime: wakeTime)
                .presentationCompactAdaptation(.popover)
        }
    }

    private func wakeTimeLabel(showsEditAffordance: Bool) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("Wake Time")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 4) {
                Text(TimeFormatter.formatTimeOfDay(recommendation.wakeTime))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                if showsEditAffordance {
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
            }
        }
        .contentShape(Rectangle())
    }
}

/// Wheel picker shown in the popover so the wake time can be changed without
/// opening Settings. It writes straight through to the stored preference.
private struct WakeTimeEditor: View {
    @Binding var wakeTime: Date

    var body: some View {
        VStack(spacing: 4) {
            Text("Wake Time")
                .font(.headline)

            DatePicker(
                "Wake Time",
                selection: $wakeTime,
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
        }
        .padding()
        // Force 12-hour clock labels to match app-wide time formatting.
        .environment(\.locale, Locale(identifier: "en_US"))
    }
}

#Preview {
    struct PreviewHost: View {
        @State private var wakeTime = Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? Date()

        var body: some View {
            BedtimeRecommendationCard(
                recommendation: BedtimeRecommendation(
                    recommendedBedtime: Calendar.current.date(byAdding: .hour, value: -8, to: wakeTime) ?? wakeTime,
                    wakeTime: wakeTime,
                    targetSleepDuration: 8,
                    reason: "You're ahead of the game! Aim for at least 8h tonight."
                ),
                wakeTime: $wakeTime
            )
            .padding()
            .background(Color.backgroundBehindCards)
        }
    }
    return PreviewHost()
}
