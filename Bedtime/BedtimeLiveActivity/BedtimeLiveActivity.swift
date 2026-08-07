import ActivityKit
import Foundation
import SwiftUI
import WidgetKit

@main
struct BedtimeLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        BedtimeLiveActivity()
    }
}

struct BedtimeLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BedtimeActivityAttributes.self) { context in
            BedtimeLockScreenView(state: context.state)
                .activityBackgroundTint(Color.indigo.opacity(0.16))
                .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("Bedger", systemImage: "bed.double.fill")
                        .font(.headline)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    bedtimeCountdown(for: context.state)
                        .font(.headline.monospacedDigit())
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        HStack {
                            Label {
                                Text(context.state.bedtime, style: .time)
                            } icon: {
                                Image(systemName: "moon.fill")
                            }

                            Spacer()

                            Label {
                                Text(context.state.wakeTime, style: .time)
                            } icon: {
                                Image(systemName: "sun.max.fill")
                            }
                        }

                        ProgressView(
                            timerInterval: context.state.bedtime...context.state.wakeTime,
                            countsDown: false
                        )
                        .tint(.indigo)
                    }
                    .font(.subheadline)
                }
            } compactLeading: {
                Image(systemName: "bed.double.fill")
                    .foregroundStyle(.indigo)
            } compactTrailing: {
                bedtimeCountdown(for: context.state)
                    .font(.caption2.monospacedDigit())
                    .frame(maxWidth: 48)
            } minimal: {
                Image(systemName: "bed.double.fill")
                    .foregroundStyle(.indigo)
            }
            .keylineTint(.indigo)
        }
    }

    private func bedtimeCountdown(
        for state: BedtimeActivityAttributes.ContentState
    ) -> Text {
        Text(
            timerInterval: state.activityStart...state.bedtime,
            countsDown: true
        )
    }
}

private struct BedtimeLockScreenView: View {
    let state: BedtimeActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Tonight’s sleep plan", systemImage: "bed.double.fill")
                    .font(.headline)
                    .foregroundStyle(.indigo)

                Spacer()

                Text(
                    timerInterval: state.activityStart...state.bedtime,
                    countsDown: true
                )
                .font(.headline.monospacedDigit())
            }

            HStack {
                scheduleTime(
                    label: "Bedtime",
                    date: state.bedtime,
                    symbol: "moon.fill"
                )

                Spacer()

                Text(
                    "\(state.targetSleepHours.formatted(.number.precision(.fractionLength(1))))h target"
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                Spacer()

                scheduleTime(
                    label: "Wake time",
                    date: state.wakeTime,
                    symbol: "sun.max.fill"
                )
            }

            ProgressView(
                timerInterval: state.bedtime...state.wakeTime,
                countsDown: false
            )
            .tint(.indigo)
        }
        .padding()
    }

    private func scheduleTime(
        label: String,
        date: Date,
        symbol: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(label, systemImage: symbol)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(date, style: .time)
                .font(.title3.bold())
        }
    }
}
