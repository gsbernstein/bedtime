//
//  CardComponent.swift
//  Bedtime
//
//  Created by Greg on 10/17/25.
//

import SwiftUI

struct CardComponent<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.cardBackground)
                    .shadow(
                        color: Color.black.opacity(0.1),
                        radius: 2,
                        x: 0,
                        y: 1
                    )
                    .shadow(
                        color: Color.black.opacity(0.05),
                        radius: 1,
                        x: 0,
                        y: 0.5
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        Color.primary.opacity(0.1),
                        lineWidth: 0.5
                    )
            }
    }
}

#Preview {
    VStack(spacing: 16) {
        CardComponent {
            VStack(alignment: .leading, spacing: 8) {
                Text("Sample Card")
                    .font(.headline)
                Text("This is a sample card with better dark mode elevation handling.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        
        CardComponent {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                Text("Another Card")
                    .font(.headline)
                Spacer()
            }
        }
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
