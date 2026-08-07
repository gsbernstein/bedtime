//
//  DiagnosticLogger.swift
//  Bedtime
//

import Combine
import Foundation
import UIKit

/// In-memory diagnostic log for TestFlight troubleshooting. Entries can be
/// shared from Settings via the system share sheet (Messages, Mail, copy, etc.).
final class DiagnosticLogger: ObservableObject {
    static let shared = DiagnosticLogger()

    @Published private(set) var entries: [String] = []

    private let maxEntries = 500
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()

    private init() {}

    /// Safe to call from any isolation context (including static initializers).
    nonisolated static func log(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let filename = (file as NSString).lastPathComponent
        Task { @MainActor in
            shared.record(message, filename: filename, line: line)
        }
    }

    @MainActor
    func exportText() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"

        var text = """
        Bedger Diagnostic Log
        Generated: \(dateFormatter.string(from: Date()))
        Bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")
        Version: \(version) (\(build))
        iOS: \(UIDevice.current.systemVersion)
        Device: \(UIDevice.current.model)

        --- Events ---

        """
        text += entries.joined(separator: "\n")
        return text
    }

    @MainActor
    func clear() {
        entries.removeAll()
        Self.log("Log cleared")
    }

    @MainActor
    private func record(_ message: String, filename: String, line: Int) {
        let entry = "[\(dateFormatter.string(from: Date()))] \(filename):\(line) — \(message)"
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
        print(entry)
    }
}
