//
//  HealthKitAuthorizationCard.swift
//  Bedtime
//
//  Created by Greg on 10/4/25.
//

import SwiftUI

struct HealthKitAuthorizationCard: View {
    @ObservedObject var healthKitManager: HealthKitManager
    
    var body: some View {
        CardComponent {
            VStack(spacing: 16) {
                CardHeader(
                    icon: "heart.text.square",
                    iconColor: .red,
                    title: "HealthKit Access Required"
                ) {
                    Text("We need access to your sleep data")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Text("To calculate your sleep bank and provide personalized bedtime recommendations, we need permission to read your sleep data from the Health app.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                
                if let errorMessage = healthKitManager.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.leading)
                }
                
                Button {
                    Task {
                        await healthKitManager.requestAccessFromUser()
                    }
                } label: {
                    if healthKitManager.isRequestingAccess {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Grant Access")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(healthKitManager.isRequestingAccess)
            }
        }
    }
}
