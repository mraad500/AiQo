import Foundation
import SwiftUI
import Combine

/// يدير الروابط العميقة والتنقل — يدعم Universal Links و URL Schemes
/// Scheme: aiqo://
/// Universal Link: https://aiqo.app/
final class DeepLinkRouter: ObservableObject {
    static let shared = DeepLinkRouter()

    enum DeepLink: Equatable {
        case home
        case captain
        case gym
        case tribe(inviteCode: String?)
        case kitchen
        case settings
        case referral(code: String)
        case premium
    }

    @Published var pendingDeepLink: DeepLink?

    private init() {}

    /// يحلل الـ URL ويوجّه للشاشة المطلوبة
    @MainActor
    func handle(url: URL) -> Bool {
        guard let deepLink = parse(url: url) else { return false }

        AnalyticsService.shared.track(AnalyticsEvent("deep_link_opened", properties: [
            "url": url.absoluteString,
            "destination": String(describing: deepLink)
        ]))

        route(to: deepLink)
        return true
    }

    /// يوجّه لشاشة معينة
    @MainActor
    func route(to deepLink: DeepLink) {
        switch deepLink {
        case .home:
            MainTabRouter.shared.navigate(to: .home)
        case .captain:
            AppRootManager.shared.openCaptainChat()
        case .gym:
            MainTabRouter.shared.navigate(to: .gym)
        case .tribe(let inviteCode):
            MainTabRouter.shared.navigate(to: .tribe)
            if let code = inviteCode {
                pendingDeepLink = .tribe(inviteCode: code)
            }
        case .kitchen:
            MainTabRouter.shared.navigate(to: .kitchen)
        case .settings:
            MainTabRouter.shared.navigate(to: .home)
        case .referral(let code):
            ReferralManager.shared.applyReferralCode(code)
        case .premium:
            pendingDeepLink = .premium
        }
    }

    // MARK: - URL Parsing

    private func parse(url: URL) -> DeepLink? {
        // URL Scheme: aiqo://captain, aiqo://tribe?invite=ABC123
        if url.scheme == "aiqo" {
            return parseSchemeURL(url)
        }

        // Universal Links: https://aiqo.app/tribe/join/ABC123
        if url.host == "aiqo.app" || url.host == "www.aiqo.app" {
            return parseUniversalLink(url)
        }

        return nil
    }

    private func parseSchemeURL(_ url: URL) -> DeepLink? {
        let host = url.host ?? ""
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []

        switch host {
        case "home": return .home
        case "captain", "chat": return .captain
        case "gym", "workout": return .gym
        case "tribe":
            let inviteCode = queryItems.first(where: { $0.name == "invite" })?.value
            return .tribe(inviteCode: inviteCode)
        case "kitchen": return .kitchen
        case "settings": return .settings
        case "referral":
            if let code = queryItems.first(where: { $0.name == "code" })?.value {
                return .referral(code: code)
            }
            return nil
        case "premium": return .premium
        default: return nil
        }
    }

    private func parseUniversalLink(_ url: URL) -> DeepLink? {
        let pathComponents = url.pathComponents.filter { $0 != "/" }

        guard let first = pathComponents.first else { return .home }

        switch first {
        case "captain", "chat": return .captain
        case "gym": return .gym
        case "tribe":
            if pathComponents.count >= 3, pathComponents[1] == "join" {
                return .tribe(inviteCode: pathComponents[2])
            }
            return .tribe(inviteCode: nil)
        case "kitchen": return .kitchen
        case "settings": return .settings
        case "refer", "referral":
            if pathComponents.count >= 2 {
                return .referral(code: pathComponents[1])
            }
            return nil
        case "premium": return .premium
        default: return nil
        }
    }
}
