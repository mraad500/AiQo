import Foundation
import SwiftUI
import Combine

/// Manages user consent for sharing personal data with third-party AI services.
/// Apple Review Guidelines 5.1.1(i) & 5.1.2(i) require explicit consent before
/// transmitting personal data to external AI services.
final class AIDataConsentManager: ObservableObject {
    static let shared = AIDataConsentManager()

    private enum Keys {
        static let hasConsented = "aiqo.ai_data_consent.granted"
        static let consentDate = "aiqo.ai_data_consent.date"
    }

    @Published private(set) var hasUserConsented: Bool

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.hasUserConsented = defaults.bool(forKey: Keys.hasConsented)
    }

    func grantConsent() {
        defaults.set(true, forKey: Keys.hasConsented)
        defaults.set(Date().timeIntervalSince1970, forKey: Keys.consentDate)
        hasUserConsented = true
    }

    func revokeConsent() {
        defaults.set(false, forKey: Keys.hasConsented)
        defaults.removeObject(forKey: Keys.consentDate)
        hasUserConsented = false
    }
}

/// A sheet presented before any AI interaction to obtain explicit user consent
/// for sharing data with third-party AI services.
struct AIDataConsentView: View {
    @ObservedObject var consentManager = AIDataConsentManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    Image(systemName: "brain.head.profile.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Color(hex: "C6EFDB"))
                        .padding(.top, 24)

                    Text(NSLocalizedString(
                        "ai.consent.title",
                        value: "مشاركة البيانات مع خدمة الذكاء الاصطناعي",
                        comment: "AI consent title"
                    ))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)

                    VStack(alignment: .leading, spacing: 14) {
                        consentDetailRow(
                            icon: "doc.text.fill",
                            title: NSLocalizedString(
                                "ai.consent.what.title",
                                value: "ما البيانات المُرسلة؟",
                                comment: ""
                            ),
                            detail: NSLocalizedString(
                                "ai.consent.what.detail",
                                value: "رسائلك في المحادثة، ملخص بياناتك الصحية اليومية (الخطوات، السعرات، النوم، النبض)، وتفضيلاتك الشخصية.",
                                comment: ""
                            )
                        )

                        consentDetailRow(
                            icon: "server.rack",
                            title: NSLocalizedString(
                                "ai.consent.who.title",
                                value: "إلى من تُرسل؟",
                                comment: ""
                            ),
                            detail: NSLocalizedString(
                                "ai.consent.who.detail",
                                value: "Google Gemini AI لمعالجة اللغة وتقديم النصائح الصحية المخصصة. ElevenLabs لتحويل النص إلى صوت عند تفعيل صوت الكابتن.",
                                comment: ""
                            )
                        )

                        consentDetailRow(
                            icon: "lock.shield.fill",
                            title: NSLocalizedString(
                                "ai.consent.why.title",
                                value: "لماذا؟",
                                comment: ""
                            ),
                            detail: NSLocalizedString(
                                "ai.consent.why.detail",
                                value: "لتوفير ردود مخصصة ونصائح صحية تناسب حالتك. البيانات الصحية تُلخَّص وتُموَّه قبل الإرسال. لا يتم تخزين بياناتك الشخصية لدى مزودي الخدمة.",
                                comment: ""
                            )
                        )
                    }
                    .padding(.horizontal, 4)

                    Text(NSLocalizedString(
                        "ai.consent.revoke",
                        value: "يمكنك إلغاء هذه الموافقة في أي وقت من إعدادات التطبيق.",
                        comment: ""
                    ))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                }
                .padding(24)
            }

            VStack(spacing: 12) {
                Button {
                    consentManager.grantConsent()
                    dismiss()
                } label: {
                    Text(NSLocalizedString(
                        "ai.consent.agree",
                        value: "موافق على المشاركة",
                        comment: ""
                    ))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(hex: "C6EFDB"))
                    )
                }
                .buttonStyle(.plain)

                Button {
                    dismiss()
                } label: {
                    Text(NSLocalizedString(
                        "ai.consent.decline",
                        value: "لا، شكرًا",
                        comment: ""
                    ))
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .environment(\.layoutDirection, AppSettingsStore.shared.appLanguage == .arabic ? .rightToLeft : .leftToRight)
    }

    private func consentDetailRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color(hex: "C6EFDB"))
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Text(detail)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
            }
        }
    }
}
