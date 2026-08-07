import ActivityKit
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
                    Label("Bedger", systemImage: phase(for: context.state).symbol)
                        .font(.headline)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    phaseTimer(for: context.state)
                        .font(.headline.monospacedDigit())
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        HStack {
                            Text(phase(for: context.state).message)
                            Spacer()
                            Text(context.state.wakeTime, style: .time)
                                .foregroundStyle(.secondary)
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
                Image(systemName: phase(for: context.state).symbol)
                    .foregroundStyle(.indigo)
            } compactTrailing: {
                phaseTimer(for: context.state)
                    .font(.caption2.monospacedDigit())
                    .frame(maxWidth: 48)
            } minimal: {
                Image(systemName: phase(for: context.state).symbol)
                    .foregroundStyle(.indigo)
            }
            .keylineTint(.indigo)
        }
    }

    private func phase(for state: BedtimeActivityAttributes.ContentState) -> BedtimePhase {
        if Date() < state.bedtime {
            return .windingDown
        }
        if Date() < state.wakeTime {
            return .sleeping
        }
        return .complete
    }

    @ViewBuilder
    private func phaseTimer(for state: BedtimeActivityAttributes.ContentState) -> some View {
        if Date() < state.bedtime {
            Text(timerInterval: Date()...state.bedtime, countsDown: true)
        } else if Date() < state.wakeTime {
            Text(timerInterval: Date()...state.wakeTime, countsDown: true)
        } else {
            Text("Done")
        }
    }
}

private struct BedtimeLockScreenView: View {
    let state: BedtimeActivityAttributes.ContentState

    private var phase: BedtimePhase {
        if Date() < state.bedtime {
            return .windingDown
        }
        if Date() < state.wakeTime {
            return .sleeping
        }
        return .complete
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Bedger", systemImage: phase.symbol)
                    .font(.headline)
                    .foregroundStyle(.indigo)

                Spacer()

                Text(phase.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(phase == .windingDown ? "Bedtime" : "Wake time")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(phase == .windingDown ? state.bedtime : state.wakeTime, style: .time)
                        .font(.title2.bold())
                }

                Spacer()

                countdown
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(.indigo)
            }

            ProgressView(
                timerInterval: state.bedtime...state.wakeTime,
                countsDown: false
            )
            .tint(.indigo)
        }
        .padding()
    }

    @ViewBuilder
    private var countdown: some View {
        if Date() < state.bedtime {
            Text(timerInterval: Date()...state.bedtime, countsDown: true)
        } else if Date() < state.wakeTime {
            Text(timerInterval: Date()...state.wakeTime, countsDown: true)
        } else {
            Text("Good morning")
        }
    }
}

private enum BedtimePhase: Equatable {
    case windingDown
    case sleeping
    case complete

    var symbol: String {
        switch self {
        case .windingDown: "bed.double.fill"
        case .sleeping: "moon.zzz.fill"
        case .complete: "sun.max.fill"
        }
    }

    var message: String {
        switch self {
        case .windingDown: "Wind-down countdown"
        case .sleeping: "Sleep window"
        case .complete: "Good morning"
        }
    }
}
