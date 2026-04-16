import Combine
import Foundation
import SwiftUI
import UIKit

enum AIDataConsentError: LocalizedError {
    case consentRequired

    var errorDescription: String? {
        NSLocalizedString("ai.consent.blocked.message", comment: "")
    }
}

/// Manages user consent for sharing personal data with third-party AI services.
@MainActor
final class AIDataConsentManager: ObservableObject {
    static let shared = AIDataConsentManager()

    private enum Keys {
        static let accepted = "aiqo.aiDataConsent.accepted"
        static let acceptedAt = "aiqo.aiDataConsent.acceptedAt"
        static let legacyAccepted = "aiqo.ai_data_consent.granted"
        static let legacyAcceptedAt = "aiqo.ai_data_consent.date"
    }

    @Published private(set) var hasUserConsented: Bool
    @Published private(set) var acceptedAt: Date?
    @Published var isPresentingConsentSheet = false

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        Self.migrateLegacyKeysIfNeeded(defaults: defaults)

        self.hasUserConsented = defaults.bool(forKey: Keys.accepted)
        if let timestamp = defaults.object(forKey: Keys.acceptedAt) as? TimeInterval {
            self.acceptedAt = Date(timeIntervalSince1970: timestamp)
        } else {
            self.acceptedAt = nil
        }
    }

    func ensureConsent(presentIfPossible: Bool = true) -> Bool {
        guard !hasUserConsented else { return true }

        if presentIfPossible, UIApplication.shared.applicationState == .active {
            isPresentingConsentSheet = true
        }

        return false
    }

    func presentDisclosure() {
        isPresentingConsentSheet = true
    }

    func grantConsent() {
        let now = Date()
        defaults.set(true, forKey: Keys.accepted)
        defaults.set(now.timeIntervalSince1970, forKey: Keys.acceptedAt)
        hasUserConsented = true
        acceptedAt = now
        isPresentingConsentSheet = false
    }

    func dismissDisclosure() {
        isPresentingConsentSheet = false
    }

    func revokeConsent() {
        defaults.set(false, forKey: Keys.accepted)
        defaults.removeObject(forKey: Keys.acceptedAt)
        hasUserConsented = false
        acceptedAt = nil
        isPresentingConsentSheet = false
    }

    private static func migrateLegacyKeysIfNeeded(defaults: UserDefaults) {
        guard defaults.object(forKey: Keys.accepted) == nil else { return }

        let legacyAccepted = defaults.bool(forKey: Keys.legacyAccepted)
        defaults.set(legacyAccepted, forKey: Keys.accepted)

        if let legacyTimestamp = defaults.object(forKey: Keys.legacyAcceptedAt) as? TimeInterval {
            defaults.set(legacyTimestamp, forKey: Keys.acceptedAt)
        }
    }
}

struct AIDataConsentView: View {
    @ObservedObject var consentManager = AIDataConsentManager.shared
    @State private var showPrivacyPolicy = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(NSLocalizedString("ai.consent.title", comment: ""))
                                .font(.system(size: 24, weight: .bold, design: .rounded))

                            Text(NSLocalizedString("ai.consent.subtitle", comment: ""))
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        AIDataUseDisclosureView()

                        Button {
                            showPrivacyPolicy = true
                        } label: {
                            Text(NSLocalizedString("ai.consent.privacyPolicy", comment: ""))
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.accentColor)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(20)
                }

                VStack(spacing: 12) {
                    Button {
                        consentManager.grantConsent()
                    } label: {
                        Text(NSLocalizedString("ai.consent.agree", comment: ""))
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.accentColor)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("ai-consent-agree")

                    Button {
                        consentManager.dismissDisclosure()
                    } label: {
                        Text(NSLocalizedString("ai.consent.notNow", comment: ""))
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("ai-consent-not-now")
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 20)
                .background(
                    Color(.systemBackground)
                        .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: -6)
                )
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        consentManager.dismissDisclosure()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            LegalView(type: .privacyPolicy)
        }
        .environment(\.layoutDirection, AppSettingsStore.shared.appLanguage == .arabic ? .rightToLeft : .leftToRight)
    }
}
