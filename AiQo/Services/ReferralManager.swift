import Foundation
import Combine

/// يدير نظام الإحالة — دعوة أصدقاء مقابل أيام مجانية
final class ReferralManager: ObservableObject {
    static let shared = ReferralManager()

    @Published private(set) var referralCode: String
    @Published private(set) var referralCount: Int
    @Published private(set) var bonusDaysEarned: Int

    /// كل إحالة = 3 أيام مجانية إضافية
    static let bonusDaysPerReferral = 3
    static let maxBonusDays = 30

    private let defaults: UserDefaults

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        // Generate or load referral code
        if let savedCode = defaults.string(forKey: Keys.referralCode) {
            self.referralCode = savedCode
        } else {
            let code = Self.generateCode()
            defaults.set(code, forKey: Keys.referralCode)
            self.referralCode = code
        }

        self.referralCount = defaults.integer(forKey: Keys.referralCount)
        self.bonusDaysEarned = defaults.integer(forKey: Keys.bonusDaysEarned)
    }

    // MARK: - Public

    /// لينك المشاركة
    var shareURL: URL? {
        URL(string: "https://aiqo.app/refer/\(referralCode)")
    }

    /// نص المشاركة
    var shareText: String {
        String(format: "referral.shareText".localized, shareURL?.absoluteString ?? "https://aiqo.app")
    }

    /// يطبّق كود إحالة (المستخدم الجديد اللي استلم الدعوة)
    func applyReferralCode(_ code: String) {
        guard !hasAppliedReferral else { return }
        guard code != referralCode else { return } // ما يقدر يستخدم كوده

        defaults.set(code, forKey: Keys.appliedReferralCode)
        defaults.set(true, forKey: Keys.hasAppliedReferral)

        // يعطي المستخدم الجديد 3 أيام إضافية
        addBonusDays(Self.bonusDaysPerReferral)

        Task { @MainActor in
            AnalyticsService.shared.track(AnalyticsEvent("referral_code_applied", properties: [
                "code": code
            ]))
        }
    }

    /// يسجّل إحالة ناجحة (المستخدم اللي دعا شخص)
    func recordSuccessfulReferral() {
        guard bonusDaysEarned < Self.maxBonusDays else { return }

        referralCount += 1
        defaults.set(referralCount, forKey: Keys.referralCount)
        addBonusDays(Self.bonusDaysPerReferral)

        Task { @MainActor in
            AnalyticsService.shared.track(AnalyticsEvent("referral_successful", properties: [
                "total_referrals": self.referralCount,
                "bonus_days": self.bonusDaysEarned
            ]))
        }
    }

    /// هل المستخدم استخدم كود إحالة قبل؟
    var hasAppliedReferral: Bool {
        defaults.bool(forKey: Keys.hasAppliedReferral)
    }

    // MARK: - Private

    private func addBonusDays(_ days: Int) {
        let newTotal = min(bonusDaysEarned + days, Self.maxBonusDays)
        bonusDaysEarned = newTotal
        defaults.set(newTotal, forKey: Keys.bonusDaysEarned)

        // يمدد التجربة المجانية
        extendTrialIfActive(by: days)
    }

    private func extendTrialIfActive(by days: Int) {
        let trialKey = "aiqo.freeTrial.startDate"
        guard let startDate = defaults.object(forKey: trialKey) as? Date else { return }

        // نرجّع تاريخ البداية لورا بعدد الأيام — هالشي يطوّل التجربة
        let extendedStart = Calendar.current.date(byAdding: .day, value: -days, to: startDate) ?? startDate
        defaults.set(extendedStart, forKey: trialKey)
        Task { @MainActor in
            FreeTrialManager.shared.refreshState()
        }
    }

    private static func generateCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<6).map { _ in chars.randomElement() ?? Character("A") })
    }

    private enum Keys {
        static let referralCode = "aiqo.referral.code"
        static let referralCount = "aiqo.referral.count"
        static let bonusDaysEarned = "aiqo.referral.bonusDays"
        static let appliedReferralCode = "aiqo.referral.appliedCode"
        static let hasAppliedReferral = "aiqo.referral.hasApplied"
    }
}
