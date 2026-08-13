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
                DynamicIslandExpandedRegion(.center) {
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
                )
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                // Hugging doesn't work, needs a cap or it fills all available space.
                .frame(maxWidth: 56)
            } minimal: {
                // A second app's activity forces both into this presentation,
                // which is too small for "in 2 hours". At narrow width the shared
                // style collapses to a single "10h" / "45m" field that fits.
                CountdownText(
                    state: context.state,
                    phase: BedtimePhase(context),
                    width: .narrow
                )
                .foregroundStyle(.indigo)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
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

    var countdownLabel: String {
        switch self {
        case .windDown: "Bedtime in"
        case .sleeping: "Wake in"
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

/// The remaining time has to come from a `DiscreteFormatStyle` so the system keeps
/// re-rendering it while the app is suspended. The system's `.offset` truncates
/// ("1 hour" at 1:59 remaining) while `.reference` rounds, so the two presentations
/// used to disagree by up to an hour; both now share one rounding style and prepositions
/// are handled externally.
private struct CountdownText: View {

    let state: BedtimeActivityAttributes.ContentState
    let phase: BedtimePhase
    var width: Duration.UnitsFormatStyle.UnitWidth = .wide

    var body: some View {
        Text(
            .currentDate,
            format: RoundedCountdownStyle(
                target: phase.target(in: state),
                width: width
            )
        )
    }
}

/// A countdown to `target` rounded to its largest field, so "2 hours" is shown from
/// 1:30 remaining rather than only above 2:00. `Duration.UnitsFormatStyle` does the
/// rounding and knows where its own output changes; this only maps dates into the
/// duration domain and back so the system can schedule re-renders at those boundaries.
private struct RoundedCountdownStyle: DiscreteFormatStyle, Codable, Hashable {
    var target: Date
    /// `.wide` reads as "8 hours"; `.narrow` compresses to "8h" for the minimal slot.
    var width: Duration.UnitsFormatStyle.UnitWidth = .wide

    /// A single hour-or-minute field keeps it to one number and one unit.
    private var units: Duration.UnitsFormatStyle {
        .units(allowed: [.hours, .minutes], width: width, maximumUnitCount: 1)
    }

    /// Clamped so a lapsed target holds at zero instead of counting back up.
    private func remaining(at date: Date) -> Duration {
        .seconds(max(0, target.timeIntervalSince(date)))
    }

    func format(_ value: Date) -> String {
        units.format(remaining(at: value))
    }

    // Remaining time shrinks as the input date grows, so date-domain boundaries
    // come from duration-domain boundaries in the opposite direction.
    func discreteInput(before input: Date) -> Date? {
        guard let boundary = units.discreteInput(after: remaining(at: input)) else {
            return nil
        }
        return target.addingTimeInterval(-boundary.timeInterval)
    }

    func discreteInput(after input: Date) -> Date? {
        // Once the target passes, the clamped output is frozen at zero.
        guard input < target,
              let boundary = units.discreteInput(before: remaining(at: input)) else {
            return nil
        }
        return target.addingTimeInterval(-boundary.timeInterval)
    }
}

extension Duration {
    fileprivate var timeInterval: TimeInterval {
        Double(components.seconds) + Double(components.attoseconds) * 1e-18
    }
}

private struct BedtimeSummaryView: View {
    let state: BedtimeActivityAttributes.ContentState
    let phase: BedtimePhase

    private var targetText: String {
        // The default single digit: this is a computed duration, not one of the
        // quarter-hour goals that need hundredths to read correctly.
        TimeFormatter.formatHours(state.targetSleepHours, style: state.durationStyle)
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

            ProgressView(timerInterval: phase.progressRange(in: state), countsDown: phase == .windDown) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .tint(.indigo)
            // The bar always anchors its fill to the leading edge, so when it
            // counts down the emptiness grows from the right — backwards next to
            // the schedule row below. Flipping the layout direction makes it
            // drain from the left; while sleeping the bar counts up instead and
            // its left-to-right fill toward Wake already reads correctly.
            .environment(\.layoutDirection, phase == .windDown ? .rightToLeft : .leftToRight)

            HStack(alignment: .firstTextBaseline) {
                scheduleTime(label: "Bedtime", date: state.bedtime, alignment: .leading)

                Spacer(minLength: 8)

                VStack {
                    Text("Target")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(targetText)
                        .font(.headline)
                }

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
extension BedtimeActivityAttributes.ContentState {
    /// Wind-down: bedtime is still ahead.
    fileprivate static var windDownSample: Self {
        let now = Date()
        return Self(
            activityStart: now.addingTimeInterval(-30 * 60),
            bedtime: now.addingTimeInterval(2 * 60 * 60),
            wakeTime: now.addingTimeInterval(10 * 60 * 60),
            targetSleepHours: 8,
            durationStyle: .hoursAndMinutes,
            isSleeping: false
        )
    }

    /// Sleeping: bedtime has passed, counting down to wake.
    fileprivate static var sleepingSample: Self {
        let now = Date()
        return Self(
            activityStart: now.addingTimeInterval(-3 * 60 * 60),
            bedtime: now.addingTimeInterval(-60 * 60),
            wakeTime: now.addingTimeInterval(7 * 60 * 60),
            targetSleepHours: 8,
            durationStyle: .hoursAndMinutes,
            isSleeping: true
        )
    }
}

#Preview("Lock Screen", as: .content, using: BedtimeActivityAttributes()) {
    BedtimeLiveActivity()
} contentStates: {
    BedtimeActivityAttributes.ContentState.windDownSample
    BedtimeActivityAttributes.ContentState.sleepingSample
}

#Preview("Island Expanded", as: .dynamicIsland(.expanded), using: BedtimeActivityAttributes()) {
    BedtimeLiveActivity()
} contentStates: {
    BedtimeActivityAttributes.ContentState.windDownSample
    BedtimeActivityAttributes.ContentState.sleepingSample
}

#Preview("Island Compact", as: .dynamicIsland(.compact), using: BedtimeActivityAttributes()) {
    BedtimeLiveActivity()
} contentStates: {
    BedtimeActivityAttributes.ContentState.windDownSample
    BedtimeActivityAttributes.ContentState.sleepingSample
}

#Preview("Island Minimal", as: .dynamicIsland(.minimal), using: BedtimeActivityAttributes()) {
    BedtimeLiveActivity()
} contentStates: {
    BedtimeActivityAttributes.ContentState.windDownSample
    BedtimeActivityAttributes.ContentState.sleepingSample
}

