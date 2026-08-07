//
//  ShareSheet.swift
//  Bedtime
//

import UIKit

/// Presents the system share sheet from the topmost view controller.
///
/// Avoids nesting a SwiftUI `.sheet` inside the Settings sheet, which causes
/// UIActivityViewController to dismiss immediately along with Settings.
enum SharePresenter {
    static func present(items: [Any]) {
        guard let presenter = topViewController() else { return }

        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )

        if let popover = controller.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(
                x: presenter.view.bounds.midX,
                y: presenter.view.bounds.midY,
                width: 1,
                height: 1
            )
            popover.permittedArrowDirections = []
        }

        presenter.present(controller, animated: true)
    }

    private static func topViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
            let root = scene.windows.first(where: \.isKeyWindow)?.rootViewController
        else {
            return nil
        }

        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}
