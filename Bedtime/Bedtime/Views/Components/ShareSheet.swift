//
//  ShareSheet.swift
//  Bedtime
//

import SwiftUI
import UIKit

/// Presents the system share sheet so the user can copy, email, or message content.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
