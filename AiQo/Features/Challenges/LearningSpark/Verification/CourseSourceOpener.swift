import SwiftUI
import SafariServices
import UIKit

/// In-app `SFSafariViewController` wrapper used when opening external course URLs
/// (Edraak, Coursera, …). Inherits Safari cookies so already-logged-in users don't
/// re-authenticate. Configured to match the AiQo visual system (sand bar tint,
/// black controls, no reader mode, collapsing bar).
///
/// Apple's sanctioned pattern for external web content — removes Guideline 4.2
/// / 3.1.1 risk vs a custom WKWebView shell.
struct CourseSourceOpener: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        config.barCollapsingEnabled = true

        let controller = SFSafariViewController(url: url, configuration: config)
        // `preferredBarTintColor` / `preferredControlTintColor` were deprecated in iOS
        // 26 — the system's own background effects handle bar tinting now. Only apply
        // them on older OSes so we don't fight the system on iOS 26+.
        if #unavailable(iOS 26.0) {
            controller.preferredBarTintColor = UIColor(red: 0.922, green: 0.812, blue: 0.592, alpha: 1.0) // AiQo sand #EBCF97
            controller.preferredControlTintColor = UIColor(red: 0.102, green: 0.102, blue: 0.102, alpha: 1.0) // AiQo black #1A1A1A
        }
        controller.dismissButtonStyle = .close
        return controller
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
        // SFSafariViewController is effectively immutable once presented.
    }
}
