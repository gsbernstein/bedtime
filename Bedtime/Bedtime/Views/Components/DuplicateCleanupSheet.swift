//
//  DuplicateCleanupSheet.swift
//  Bedtime
//
//  Lets the user resolve a detected duplicate sync: shows the overlapping entries on a
//  timeline, a histogram of when they were added to HealthKit with a draggable divider
//  suggesting where the old sync ends and the new one begins, and either deletes the older
//  batch directly (only possible when Bedger itself wrote the samples) or, for real
//  duplicates from another source, tells the user exactly what to remove and hands off to
//  the Health app to finish it — see `canDeleteDirectly`.
//

import SwiftUI
import HealthKit
import UIKit

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

    /// HealthKit only lets an app delete objects it wrote itself (see
    /// `ForeignSourceDeletionError`), so a real Delete button only makes sense when Bedger
    /// itself is the source of these samples — which, for actual duplicate-sync bugs like
    /// Oura's, it never is. This drives whether we show the delete button or manual
    /// instructions for the Health app instead.
    private var canDeleteDirectly: Bool {
        group.sourceBundleID == Bundle.main.bundleIdentifier
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

                    if !canDeleteDirectly {
                        manualDeletionNotice
                    }

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

                    if canDeleteDirectly {
                        submitButton
                    } else {
                        openHealthAppButton
                    }
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

    private var manualDeletionNotice: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.blue)
                Text("Bedger can't delete this directly")
                    .font(.subheadline.weight(.semibold))
            }
            Text("Apple only lets an app delete HealthKit entries it wrote itself, so Bedger can't remove \(group.sourceName)'s entries — only the Health app can. Use the divider below to see exactly which entries to remove, then delete them from Health → Browse → Sleep → this night → \"Show All Data.\"")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    private var openHealthAppButton: some View {
        Button {
            if let url = URL(string: "x-apple-health://"), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        } label: {
            Text("Open Health App")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
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
            DuplicateCandidateSample(id: UUID(), startDate: now.addingTimeInterval(-28800), endDate: now.addingTimeInterval(-25200), sleepType: .asleepCore, creationDate: olderBatch, sourceBundleID: "com.ouraring.oura", sourceName: "Oura"),
            DuplicateCandidateSample(id: UUID(), startDate: now.addingTimeInterval(-25200), endDate: now.addingTimeInterval(-21600), sleepType: .asleepDeep, creationDate: olderBatch.addingTimeInterval(30), sourceBundleID: "com.ouraring.oura", sourceName: "Oura"),
            DuplicateCandidateSample(id: UUID(), startDate: now.addingTimeInterval(-21600), endDate: now.addingTimeInterval(-18000), sleepType: .asleepREM, creationDate: olderBatch.addingTimeInterval(60), sourceBundleID: "com.ouraring.oura", sourceName: "Oura"),
            DuplicateCandidateSample(id: UUID(), startDate: now.addingTimeInterval(-28800), endDate: now.addingTimeInterval(-25200), sleepType: .asleepCore, creationDate: newerBatch, sourceBundleID: "com.ouraring.oura", sourceName: "Oura"),
            DuplicateCandidateSample(id: UUID(), startDate: now.addingTimeInterval(-25200), endDate: now.addingTimeInterval(-21600), sleepType: .asleepDeep, creationDate: newerBatch.addingTimeInterval(30), sourceBundleID: "com.ouraring.oura", sourceName: "Oura"),
            DuplicateCandidateSample(id: UUID(), startDate: now.addingTimeInterval(-21600), endDate: now.addingTimeInterval(-18000), sleepType: .asleepREM, creationDate: newerBatch.addingTimeInterval(60), sourceBundleID: "com.ouraring.oura", sourceName: "Oura"),
        ]
    )
    DuplicateCleanupSheet(group: group, onDelete: { _ in })
}
