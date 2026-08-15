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
                let phase = BedtimePhase(context)
                if phase == .awake {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.indigo)
                } else {
                    VStack(spacing: 2) {
                        CountdownText(state: context.state, phase: phase)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)

                        PhaseProgressBar(state: context.state, phase: phase)
                            .frame(height: 2)
                    }
                    // Text doesn't hug so without a cap the region
                    // grows to fill the whole side of the status bar.
                    .frame(maxWidth: 56)
                }
            } minimal: {
                let phase = BedtimePhase(context)
                if phase == .awake {
                    Image(systemName: phase.symbol)
                        .foregroundStyle(.indigo)
                } else {
                    ProgressView(
                        timerInterval: context.state.progressRange(for: phase),
                        countsDown: phase == .windDown
                    ) {
                        EmptyView()
                    } currentValueLabel: {
                        Image(systemName: phase.symbol)
                            .padding(2)
                    }
                    .progressViewStyle(.circular)
                    .tint(.indigo)
                }
            }
            .keylineTint(.indigo)
        }
    }
}

/// The activity covers three stretches: wind-down, sleeping, and — once
/// `LiveActivityManager.markAwakeIfNeeded()` flips `isAwake` — done. The first
/// transition happens locally when `staleDate` (set to bedtime) passes; the
/// second can't, since `staleDate` only lapses once, so it needs the app to
/// actually run and push that update.
private enum BedtimePhase {
    case windDown
    case sleeping
    case awake

    init(_ context: ActivityViewContext<BedtimeActivityAttributes>) {
        if context.state.isAwake {
            self = .awake
        } else {
            // Either the activity began after bedtime, or it has since gone
            // stale at bedtime and the system re-rendered it.
            self = context.state.isSleeping || context.isStale ? .sleeping : .windDown
        }
    }

    var symbol: String {
        switch self {
        case .windDown: "bed.double.fill"
        case .sleeping: "moon.zzz.fill"
        case .awake: "sun.max.fill"
        }
    }

    /// `DateReference` supplies its own "in …", so this is only the subject.
    var countdownLabel: String {
        switch self {
        case .windDown: "Bedtime"
        case .sleeping: "Wake"
        case .awake: "Awake"
        }
    }

    /// Names what the compact pill is counting down to, since its trailing text
    /// is only a bare duration.
    var compactLabel: String {
        switch self {
        case .windDown: "Sleep"
        case .sleeping: "Wake"
        case .awake: "Awake"
        }
    }
}

private extension BedtimeActivityAttributes.ContentState {

    func start(for phase: BedtimePhase) -> Date {
        switch phase {
        case .windDown: activityStart
        case .sleeping, .awake: bedtime
        }
    }

    func target(for phase: BedtimePhase) -> Date {
        switch phase {
        case .windDown: bedtime
        case .sleeping, .awake: wakeTime
        }
    }

    func progressRange(for phase: BedtimePhase) -> ClosedRange<Date> {
        let start = start(for: phase)
        let end = target(for: phase)
        return min(start, end)...max(start, end)
    }
}

/// How insistently the card nudges toward reopening the app, based on how many
/// nights into a locally pre-scheduled queue this one is (see the app's
/// `LiveActivityManager.scheduleUpcomingNights`). Night 0 is a real,
/// HealthKit-backed recommendation; every night after that just repeats the
/// same clock times, so the nudge gets louder the further out it is.
private enum ReminderLevel: Equatable {
    case gentle
    case final

    init?(nightsSinceLastSync: Int) {
        switch nightsSinceLastSync {
        case ..<2: return nil
        case 2..<(BedtimeActivityAttributes.maxConcurrentActivities - 1): self = .gentle
        default: self = .final
        }
    }

    var message: String {
        switch self {
        case .gentle: "Open the app for an accurate recommendation"
        case .final: "Open the app now to keep your countdown going"
        }
    }
}

/// Only the system format styles keep counting while the app is suspended, so the
/// remaining time is rendered by the system rather than formatted by the app.
///
/// Limiting the fields to hours and minutes keeps the phrasing at "in 8 hours" /
/// "in 20 minutes" rather than reaching for "tomorrow", and the hour threshold means
/// only a gap wider than a day would fall back to an absolute date.
private struct CountdownText: View {
    let state: BedtimeActivityAttributes.ContentState
    let phase: BedtimePhase

    var body: some View {
        Text(
            .currentDate,
            format: .reference(
                to: state.target(for: phase),
                allowedFields: [.hour, .minute],
                thresholdField: .hour
            )
        )
    }
}

/// The bar always anchors its fill to the leading edge, so when it counts down
/// the emptiness grows from the trailing side — backwards next to the schedule
/// row below it. Inverting the inherited layout direction makes it drain from
/// the leading side instead; while sleeping the bar counts up and its
/// leading-to-trailing fill toward Wake already reads correctly, so it keeps
/// the inherited direction.
private struct PhaseProgressBar: View {
    let state: BedtimeActivityAttributes.ContentState
    let phase: BedtimePhase

    @Environment(\.layoutDirection) private var layoutDirection

    private var flippedLayoutDirection: LayoutDirection {
        layoutDirection == .leftToRight ? .rightToLeft : .leftToRight
    }

    var body: some View {
        ProgressView(
            timerInterval: state.progressRange(for: phase),
            countsDown: phase == .windDown
        ) {
            EmptyView()
        } currentValueLabel: {
            EmptyView()
        }
        .tint(.indigo)
        .environment(\.layoutDirection, phase == .windDown ? flippedLayoutDirection : layoutDirection)
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
            if phase == .awake {
                awakeContent
            } else {
                countdownContent
            }
        }
    }

    private var awakeContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Good morning", systemImage: phase.symbol)
                .font(.headline)
                .foregroundStyle(.indigo)

            if let link = state.sourceAppLink {
                Link(destination: link.url) {
                    Label("Open \(link.name) to see your data", systemImage: "arrow.up.right")
                }
                .font(.subheadline)
            } else {
                Text("Open Bedger to see your sleep data")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var countdownContent: some View {
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

        PhaseProgressBar(state: state, phase: phase)

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

        if let reminder = ReminderLevel(nightsSinceLastSync: state.nightsSinceLastSync) {
            Label(reminder.message, systemImage: "arrow.triangle.2.circlepath")
                .font(.caption2)
                .foregroundStyle(reminder == .final ? .red : .secondary)
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
            activityStart: now.addingTimeInterval(.minutes(-30)),
            bedtime: now.addingTimeInterval(.hours(2)),
            wakeTime: now.addingTimeInterval(.hours(10)),
            targetSleepHours: 8,
            durationStyle: .hoursAndMinutes,
            isSleeping: false
        )
    }

    /// Sleeping: bedtime has passed, counting down to wake.
    fileprivate static var sleepingSample: Self {
        let now = Date()
        return Self(
            activityStart: now.addingTimeInterval(.hours(-3)),
            bedtime: now.addingTimeInterval(.hours(-1)),
            wakeTime: now.addingTimeInterval(.hours(7)),
            targetSleepHours: 8,
            durationStyle: .hoursAndMinutes,
            isSleeping: true
        )
    }

    /// Awake: wake time has passed and `markAwakeIfNeeded()` marked it done.
    fileprivate static var awakeSample: Self {
        let now = Date()
        return Self(
            activityStart: now.addingTimeInterval(.hours(-8)),
            bedtime: now.addingTimeInterval(.hours(-8)),
            wakeTime: now.addingTimeInterval(.minutes(-5)),
            targetSleepHours: 8,
            durationStyle: .hoursAndMinutes,
            isSleeping: true,
            sourceAppLink: BedtimeSourceAppLink(
                name: "Oura",
                url: URL(string: "https://cloud.ouraring.com/app/v1/home")!
            ),
            isAwake: true
        )
    }

    /// The last night of a pre-scheduled queue, several days without a fresh
    /// HealthKit-backed recommendation.
    fileprivate static var staleQueuedSample: Self {
        let now = Date()
        return Self(
            activityStart: now.addingTimeInterval(.minutes(-30)),
            bedtime: now.addingTimeInterval(.hours(2)),
            wakeTime: now.addingTimeInterval(.hours(10)),
            targetSleepHours: 8,
            durationStyle: .hoursAndMinutes,
            isSleeping: false,
            nightsSinceLastSync: BedtimeActivityAttributes.maxConcurrentActivities - 1
        )
    }
}

#Preview("Lock Screen", as: .content, using: BedtimeActivityAttributes()) {
    BedtimeLiveActivity()
} contentStates: {
    BedtimeActivityAttributes.ContentState.windDownSample
    BedtimeActivityAttributes.ContentState.sleepingSample
    BedtimeActivityAttributes.ContentState.awakeSample
    BedtimeActivityAttributes.ContentState.staleQueuedSample
}

#Preview("Island Expanded", as: .dynamicIsland(.expanded), using: BedtimeActivityAttributes()) {
    BedtimeLiveActivity()
} contentStates: {
    BedtimeActivityAttributes.ContentState.windDownSample
    BedtimeActivityAttributes.ContentState.sleepingSample
    BedtimeActivityAttributes.ContentState.awakeSample
}

#Preview("Island Compact", as: .dynamicIsland(.compact), using: BedtimeActivityAttributes()) {
    BedtimeLiveActivity()
} contentStates: {
    BedtimeActivityAttributes.ContentState.windDownSample
    BedtimeActivityAttributes.ContentState.sleepingSample
    BedtimeActivityAttributes.ContentState.awakeSample
}

#Preview("Island Minimal", as: .dynamicIsland(.minimal), using: BedtimeActivityAttributes()) {
    BedtimeLiveActivity()
} contentStates: {
    BedtimeActivityAttributes.ContentState.windDownSample
    BedtimeActivityAttributes.ContentState.sleepingSample
    BedtimeActivityAttributes.ContentState.awakeSample
}

