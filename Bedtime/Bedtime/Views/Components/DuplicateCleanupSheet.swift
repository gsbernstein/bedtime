//
//  DuplicateCleanupSheet.swift
//  Bedtime
//
//  Lets the user resolve a detected duplicate sync: shows the overlapping entries on a
//  timeline, a histogram of when they were added to HealthKit with a draggable divider
//  suggesting where the old sync ends and the new one begins, and deletes the older batch
//  on confirmation.
//

import SwiftUI
import HealthKit

struct DuplicateCleanupSheet: View {
    let group: DuplicateSleepGroup
    /// Deletes the given samples from HealthKit. Thrown errors are shown inline; the sheet
    /// dismisses itself on success.
    let onDelete: ([DuplicateCandidateSample]) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.durationDisplayStyle) private var durationStyle
    @State private var cutoff: Date
    @State private var isDeleting = false
    @State private var errorMessage: String?

    init(group: DuplicateSleepGroup, onDelete: @escaping ([DuplicateCandidateSample]) async throws -> Void) {
        self.group = group
        self.onDelete = onDelete
        _cutoff = State(initialValue: group.suggestedCutoff ?? group.distinctCreationDates.last ?? Date())
    }

    private var resolution: DuplicateResolution {
        DuplicateSleepDetector.resolution(for: group, cutoff: cutoff)
    }

    private var creationRange: ClosedRange<Date> {
        guard let range = group.creationDateRange else {
            let now = Date()
            return now...now.addingTimeInterval(1)
        }
        // Pad a little so the divider isn't glued to the histogram's edges.
        let padding = max(range.upperBound.timeIntervalSince(range.lowerBound) * 0.08, 60)
        return range.lowerBound.addingTimeInterval(-padding)...range.upperBound.addingTimeInterval(padding)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Bedger found \(group.samples.count) overlapping \(group.sourceName) entries for the night of \(Self.dateFormatter.string(from: group.night)) — likely from a duplicate sync. Choose which sync to keep.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Overlapping entries")
                            .font(.headline)

                        DuplicateOverlapTimelineView(group: group, cutoff: cutoff)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("When entries were added")
                            .font(.headline)
                        Text("Drag the divider to choose the cutoff. Entries added before it are deleted; the rest are kept.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        CreationTimeHistogramView(samples: group.samples, range: creationRange, cutoff: $cutoff)
                            .frame(height: 120)

                        Text("Cutoff: \(Self.dateFormatter.string(from: cutoff)) at \(Self.timeFormatter.string(from: cutoff))")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }

                    summary

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    submitButton
                }
                .padding()
            }
            .navigationTitle("Clean Up Duplicates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isDeleting)
                }
            }
        }
        .interactiveDismissDisabled(isDeleting)
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 10) {
            summaryRow(
                color: .red,
                text: "\(resolution.toDelete.count) entries will be deleted",
                duration: resolution.deletedDuration
            )
            summaryRow(
                color: .green,
                text: "\(resolution.toKeep.count) entries will be kept",
                duration: resolution.keptDuration
            )
        }
        .padding()
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
    }

    private func summaryRow(color: Color, text: String, duration: TimeInterval) -> some View {
        HStack {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text)
                .font(.subheadline)
            Spacer()
            Text(TimeFormatter.formatDuration(duration, style: durationStyle))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private var submitButton: some View {
        Button(role: .destructive) {
            delete()
        } label: {
            Group {
                if isDeleting {
                    ProgressView()
                } else {
                    Text("Delete \(resolution.toDelete.count) Duplicate \(resolution.toDelete.count == 1 ? "Entry" : "Entries")")
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)
        .disabled(resolution.toDelete.isEmpty || isDeleting)
    }

    private func delete() {
        isDeleting = true
        errorMessage = nil
        let samplesToDelete = resolution.toDelete
        Task {
            do {
                try await onDelete(samplesToDelete)
                isDeleting = false
                dismiss()
            } catch {
                isDeleting = false
                errorMessage = "Couldn't delete duplicates: \(error.localizedDescription)"
            }
        }
    }
}

#Preview {
    let now = Date()
    let olderBatch = now.addingTimeInterval(-3600)
    let newerBatch = now.addingTimeInterval(-120)
    let group = DuplicateSleepGroup(
        night: Calendar.current.startOfDay(for: now),
        sourceBundleID: "com.ouraring.oura",
        sourceName: "Oura",
        samples: [
            DuplicateCandidateSample(id: UUID(), startDate: now.addingTimeInterval(-28800), endDate: now.addingTimeInterval(-25200), sleepType: .asleepCore, creationDate: olderBatch),
            DuplicateCandidateSample(id: UUID(), startDate: now.addingTimeInterval(-25200), endDate: now.addingTimeInterval(-21600), sleepType: .asleepDeep, creationDate: olderBatch.addingTimeInterval(30)),
            DuplicateCandidateSample(id: UUID(), startDate: now.addingTimeInterval(-21600), endDate: now.addingTimeInterval(-18000), sleepType: .asleepREM, creationDate: olderBatch.addingTimeInterval(60)),
            DuplicateCandidateSample(id: UUID(), startDate: now.addingTimeInterval(-28800), endDate: now.addingTimeInterval(-25200), sleepType: .asleepCore, creationDate: newerBatch),
            DuplicateCandidateSample(id: UUID(), startDate: now.addingTimeInterval(-25200), endDate: now.addingTimeInterval(-21600), sleepType: .asleepDeep, creationDate: newerBatch.addingTimeInterval(30)),
            DuplicateCandidateSample(id: UUID(), startDate: now.addingTimeInterval(-21600), endDate: now.addingTimeInterval(-18000), sleepType: .asleepREM, creationDate: newerBatch.addingTimeInterval(60)),
        ]
    )
    DuplicateCleanupSheet(group: group, onDelete: { _ in })
}
