//
//  SleepGoalEditor.swift
//  Bedtime
//
//  Wheel picker for the nightly sleep goal, shown in a popover so the goal can
//  be changed without opening Settings.
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
        VStack(spacing: 4) {
            Text("Sleep Goal")
                .font(.headline)

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
            .labelsHidden()
        }
        .padding()
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
