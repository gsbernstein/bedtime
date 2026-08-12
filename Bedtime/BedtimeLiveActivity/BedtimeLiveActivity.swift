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
                phase: BedtimePhase(context)
            )
            .padding()
            .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(
                        context.attributes.title,
                        systemImage: BedtimePhase(context).symbol
                    )
                    .font(.headline)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    BedtimeSummaryView(
                        state: context.state,
                        phase: BedtimePhase(context)
                    )
                }
            } compactLeading: {
                let phase = BedtimePhase(context)
                HStack(spacing: 3) {
                    Image(systemName: phase.symbol)
                    Text(phase.compactLabel)
                }
                .foregroundStyle(.indigo)
                .lineLimit(1)
            } compactTrailing: {
                CountdownText(
                    state: context.state,
                    phase: BedtimePhase(context),
                    style: .compact
                )
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                // Without a cap the compact region grows to fit its text and
                // stretches the whole pill.
                .frame(maxWidth: 56)
            } minimal: {
                Image(systemName: BedtimePhase(context).symbol)
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

    init(_ context: ActivityViewContext<BedtimeActivityAttributes>) {
        // Either the activity began after bedtime, or it has since gone stale at
        // bedtime and the system re-rendered it.
        self = context.state.isSleeping || context.isStale ? .sleeping : .windDown
    }

    var symbol: String {
        switch self {
        case .windDown: "bed.double.fill"
        case .sleeping: "moon.zzz.fill"
        }
    }

    /// `DateReference` supplies its own "in …", so this is only the subject.
    var countdownLabel: String {
        switch self {
        case .windDown: "Bedtime"
        case .sleeping: "Wake"
        }
    }

    /// Names what the compact pill is counting down to, since its trailing text
    /// is only a bare duration.
    var compactLabel: String {
        switch self {
        case .windDown: "Sleep"
        case .sleeping: "Wake"
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
///
/// Limiting the fields to hours and minutes keeps the phrasing at "in 8 hours" /
/// "in 20 minutes" rather than reaching for "tomorrow", and the hour threshold means
/// only a gap wider than a day would fall back to an absolute date.
private struct CountdownText: View {
    enum Style {
        /// "in 2 hours", which reads as a sentence next to its subject.
        case phrase
        /// "2 hours", dropping the preposition where width is scarce.
        case compact
    }

    let state: BedtimeActivityAttributes.ContentState
    let phase: BedtimePhase
    var style: Style = .phrase

    var body: some View {
        switch style {
        case .phrase:
            Text(
                .currentDate,
                format: .reference(
                    to: phase.target(in: state),
                    allowedFields: [.hour, .minute],
                    thresholdField: .hour
                )
            )
        case .compact:
            Text(
                .currentDate,
                format: .offset(
                    to: phase.target(in: state),
                    allowedFields: [.hour, .minute],
                    maxFieldCount: 1,
                    sign: .never
                )
            )
        }
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
            HStack(spacing: 4) {
                Image(systemName: phase.symbol)
                    .foregroundStyle(.indigo)
                    .padding(.trailing, 2)

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
