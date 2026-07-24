//
//  DiagnosticLogger.swift
//  Bedtime
//

import Foundation
import UIKit

/// In-memory diagnostic log for TestFlight troubleshooting. Entries can be
/// shared from Settings via the system share sheet (Messages, Mail, copy, etc.).
@MainActor
final class DiagnosticLogger: ObservableObject {
    static let shared = DiagnosticLogger()

    @Published private(set) var entries: [String] = []

    private let maxEntries = 500
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()

    private init() {
        log("Diagnostic logger started")
        log(deviceContext())
    }

    static func log(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        Task { @MainActor in
            shared.append(message, file: file, function: function, line: line)
        }
    }

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

    func clear() {
        entries.removeAll()
        log("Log cleared")
    }

    private func append(_ message: String, file: String, function: String, line: Int) {
        let filename = (file as NSString).lastPathComponent
        let entry = "[\(dateFormatter.string(from: Date()))] \(filename):\(line) — \(message)"
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
        print(entry)
    }

    private func deviceContext() -> String {
        "Device context — iOS \(UIDevice.current.systemVersion), model \(UIDevice.current.model)"
    }
}
