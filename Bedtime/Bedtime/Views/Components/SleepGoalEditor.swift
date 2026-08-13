//
//  SleepGoalEditor.swift
//  Bedtime
//
//  Wheel picker for the nightly sleep goal, expanded inline within
//  SleepBankCard so the goal can be changed without opening Settings.
//

import SwiftUI

struct SleepGoalEditor: View {
    @Binding var goalHours: Double
    @Environment(\.durationDisplayStyle) private var durationStyle

    private var stepIndex: Binding<Int> {
        Binding(
            get: { Constants.sleepGoalStepIndex(forHours: goalHours) },
            set: { goalHours = Constants.sleepGoalHours(atStepIndex: $0) }
        )
    }

    var body: some View {
        Picker("Sleep Goal", selection: stepIndex) {
            ForEach(Constants.sleepGoalStepIndices, id: \.self) { index in
                Text(TimeFormatter.formatHours(
                    Constants.sleepGoalHours(atStepIndex: index),
                    style: durationStyle,
                    maxFractionDigits: 2
                ))
                .tag(index)
            }
        }
        .pickerStyle(.wheel)
        .padding(.vertical, -12)
        .frame(maxHeight: 120)
    }
}

#Preview {
    struct PreviewHost: View {
        @State private var goalHours = 8.0

        var body: some View {
            VStack {
                Text(TimeFormatter.formatHours(goalHours, style: .hoursAndMinutes, maxFractionDigits: 2))
                SleepGoalEditor(goalHours: $goalHours)
            }
        }
    }
    return PreviewHost()
}
