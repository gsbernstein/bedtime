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
                HStack {
                    Image(systemName: "heart.text.square")
                        .font(.title2)
                        .foregroundColor(.red)
                        .frame(width: Constants.iconWidth)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("HealthKit Access Required")
                            .font(.headline)
                        
                        Text("We need access to your sleep data")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
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
                
                Button("Grant Access") {
                    Task {
                        try await healthKitManager.requestAuthorization()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }
}
