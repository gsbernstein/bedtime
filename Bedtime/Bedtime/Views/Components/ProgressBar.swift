//
//  ProgressBar.swift
//  Bedtime
//
//  Created by Greg on 10/17/25.
//

import SwiftUI

struct ProgressBar: View {
    var value: Double
    var total: Double = 1

    var body: some View {
        Capsule()
            .fill(.foreground.quaternary)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                    .fill(.tint)
                    .frame(width: proxy.size.width * value / total)
                }
            }
            .clipShape(Capsule())
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    VStack {
        ProgressBar(value: 0.2)
            .tint(Gradient(colors: [AppColors.warning, AppColors.negative]))

        ProgressBar(value: 6, total: 8)
            .tint(Gradient(colors: [AppColors.recentSleep, AppColors.bedtime]))

        ProgressBar(value: 8, total: 10)
            .tint(LinearGradient(colors: [AppColors.positive, AppColors.accent], startPoint: .leading, endPoint: .trailing))
    }
    .frame(height: 64)
    .padding()
}
