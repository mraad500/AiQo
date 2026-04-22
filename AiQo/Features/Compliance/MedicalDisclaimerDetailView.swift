import SwiftUI

/// Full medical disclaimer screen presented as a first-run gate on `.main`
/// and as a settings-triggered reference sheet/push.
///
/// This is the v1.1 Apple 1.4.1 compliance surface. Content language follows
/// the app's selected language (`AppSettingsStore.shared.appLanguage`) so the
/// screen never mixes Arabic and English. The short banner label lives in
/// `CaptainSafetyBanner`; the existing `MedicalDisclaimerView` (in Shared/)
/// remains the inline strip used by `HealthComplianceCard`.
struct MedicalDisclaimerDetailView: View {
    enum Mode { case firstRun, settings }

    let mode: Mode
    var onAcknowledge: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @AppStorage("aiqo.medicalDisclaimer.acknowledgedV1") private var acknowledged = false

    private let mint = Color(red: 0.718, green: 0.898, blue: 0.824)
    private let ink  = Color(red: 0.059, green: 0.090, blue: 0.129)
    private let bg   = Color(red: 0.980, green: 0.980, blue: 0.969)

    private var isArabic: Bool {
        AppSettingsStore.shared.appLanguage == .arabic
    }

    private var layoutDirection: LayoutDirection {
        isArabic ? .rightToLeft : .leftToRight
    }

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    heroHeader
                    primaryDisclaimerCard
                    hydrationDisclaimerCard
                    if mode == .firstRun {
                        acknowledgeButton
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
        }
        .environment(\.layoutDirection, layoutDirection)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .interactiveDismissDisabled(mode == .firstRun)
        .navigationTitle(mode == .settings ? (isArabic ? "الإخلاء الطبي" : "Medical disclaimer") : "")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var heroHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(mint)
                .padding(.bottom, 4)
                .accessibilityHidden(true)

            Text(isArabic ? "تنبيه صحي مهم" : "Important health notice")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var primaryDisclaimerCard: some View {
        let title: String
        let body: String
        if isArabic {
            title = "AiQo ليس جهازاً طبياً"
            body = """
            AiQo هو رفيق للعافية ونمط الحياة، ولا يُعتبر جهازاً طبياً. لا يقدم التطبيق تشخيصاً طبياً ولا علاجاً ولا استشارة مهنية.

            استشر طبيباً مختصاً قبل:
            •  اتخاذ أي قرار صحي
            •  بدء أي برنامج تمرين
            •  تغيير نظامك الغذائي
            •  تعديل أي أدوية

            في الحالات الطارئة، اتصل فوراً بخدمات الطوارئ المحلية.
            """
        } else {
            title = "AiQo is not a medical device"
            body = """
            AiQo is a wellness and lifestyle companion. It does not provide medical diagnosis, treatment, or professional advice.

            Consult a qualified physician before:
            •  Making any health decision
            •  Starting an exercise program
            •  Changing your diet
            •  Adjusting any medication

            In an emergency, call your local emergency services immediately.
            """
        }
        return disclaimerCard(title: title, body: body)
    }

    /// Hydration-specific clause — clarifies that Smart Water Tracking reminders
    /// are lifestyle support, not medical advice. Kept in a separate card so the
    /// primary "not a medical device" message stays front and center.
    private var hydrationDisclaimerCard: some View {
        let title: String
        let body: String
        if isArabic {
            title = "تذكيرات شرب الماء"
            body = "قد يقدم AiQo تذكيرات عامة بشرب الماء لتحسين نمط الحياة، لكن هذه التوصيات لا تُعتبر نصيحة طبية. احتياجات الجسم من الماء تختلف حسب العمر، الوزن، النشاط، والظروف الصحية."
        } else {
            title = "Hydration reminders"
            body = "AiQo may provide general hydration reminders to support a healthy lifestyle. These are not medical recommendations. Hydration needs vary depending on age, weight, activity level, and medical conditions."
        }
        return disclaimerCard(title: title, body: body)
    }

    private var acknowledgeButton: some View {
        Button(action: acknowledge) {
            Text(isArabic ? "فهمت وأوافق" : "I understand and agree")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(ink)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(mint))
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
        .accessibilityLabel(isArabic
                            ? "فهمت وأوافق على الإخلاء الطبي"
                            : "I understand and agree to the medical disclaimer")
    }

    private func acknowledge() {
        acknowledged = true
        UserDefaults.standard.set(true, forKey: "didAcknowledgeMedicalDisclaimer")
        onAcknowledge()
        dismiss()
    }

    @ViewBuilder
    private func disclaimerCard(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(ink)
            Text(body)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(ink.opacity(0.78))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.ultraThinMaterial))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.black.opacity(0.04), lineWidth: 1)
        )
    }
}
