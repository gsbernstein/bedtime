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
            BedtimeSummaryView(
                state: context.state,
                phase: BedtimePhase(isStale: context.isStale)
            )
            .padding()
            .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(
                        context.attributes.title,
                        systemImage: BedtimePhase(isStale: context.isStale).symbol
                    )
                    .font(.headline)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    BedtimeSummaryView(
                        state: context.state,
                        phase: BedtimePhase(isStale: context.isStale)
                    )
                }
            } compactLeading: {
                Image(systemName: BedtimePhase(isStale: context.isStale).symbol)
                    .foregroundStyle(.indigo)
            } compactTrailing: {
                CountdownText(
                    state: context.state,
                    phase: BedtimePhase(isStale: context.isStale),
                    maxFieldCount: 1
                )
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            } minimal: {
                Image(systemName: BedtimePhase(isStale: context.isStale).symbol)
                    .foregroundStyle(.indigo)
            }
            .keylineTint(.indigo)
        }
    }
}

/// The activity covers two stretches of the night. `staleDate` is set to bedtime,
/// so the system re-renders into the sleeping phase without the app running.
private enum BedtimePhase {
    case windDown
    case sleeping

    init(isStale: Bool) {
        self = isStale ? .sleeping : .windDown
    }

    var symbol: String {
        switch self {
        case .windDown: "bed.double.fill"
        case .sleeping: "moon.zzz.fill"
        }
    }

    var countdownLabel: String {
        switch self {
        case .windDown: "Bedtime in"
        case .sleeping: "Wake in"
        }
    }

    func target(in state: BedtimeActivityAttributes.ContentState) -> Date {
        switch self {
        case .windDown: state.bedtime
        case .sleeping: state.wakeTime
        }
    }

    func progressRange(
        in state: BedtimeActivityAttributes.ContentState
    ) -> ClosedRange<Date> {
        let start = switch self {
        case .windDown: state.activityStart
        case .sleeping: state.bedtime
        }
        let end = target(in: state)
        return min(start, end)...max(start, end)
    }
}

/// Only the system format styles keep counting while the app is suspended, so the
/// remaining time is rendered by the system rather than formatted by the app.
private struct CountdownText: View {
    let state: BedtimeActivityAttributes.ContentState
    let phase: BedtimePhase
    var maxFieldCount: Int = 2

    var body: some View {
        Text(
            .currentDate,
            format: .offset(
                to: phase.target(in: state),
                allowedFields: [.hour, .minute],
                maxFieldCount: maxFieldCount,
                sign: .never
            )
        )
    }
}

private struct BedtimeSummaryView: View {
    let state: BedtimeActivityAttributes.ContentState
    let phase: BedtimePhase

    private var targetText: String {
        TimeFormatter.formatHours(
            state.targetSleepHours,
            style: state.durationStyle,
            maxFractionDigits: 2
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: phase.symbol)
                    .foregroundStyle(.indigo)

                Text(phase.countdownLabel)

                CountdownText(state: state, phase: phase)
                    .fontWeight(.semibold)

                Spacer(minLength: 0)
            }
            .font(.headline)
            .lineLimit(1)
            .minimumScaleFactor(0.7)

            ProgressView(timerInterval: phase.progressRange(in: state), countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .tint(.indigo)

            HStack(alignment: .firstTextBaseline) {
                scheduleTime(label: "Bedtime", date: state.bedtime, alignment: .leading)

                Spacer(minLength: 8)

                Text("\(targetText) target")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 8)

                scheduleTime(label: "Wake", date: state.wakeTime, alignment: .trailing)
            }
        }
    }

    private func scheduleTime(
        label: String,
        date: Date,
        alignment: HorizontalAlignment
    ) -> some View {
        VStack(alignment: alignment, spacing: 1) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(TimeFormatter.formatTimeOfDay(date))
                .font(.headline)
        }
    }
}
