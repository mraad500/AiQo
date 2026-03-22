import Foundation
import Security
import Combine

/// يدير فترة التجربة المجانية (7 أيام) — بدون اشتراك StoreKit
/// الفكرة: أول ما المستخدم يفتح التطبيق، يبدأ العد التنازلي 7 أيام
/// خلال هالفترة يقدر يستخدم كل الميزات المدفوعة
final class FreeTrialManager: ObservableObject {
    static let shared = FreeTrialManager()

    @Published private(set) var trialState: TrialState = .notStarted

    private let defaults: UserDefaults
    private let nowProvider: () -> Date
    static let trialDurationDays = 7

    enum TrialState: Equatable {
        case notStarted
        case active(daysRemaining: Int)
        case expired
    }

    private init(
        defaults: UserDefaults = .standard,
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.defaults = defaults
        self.nowProvider = nowProvider
        refreshState()
    }

    // MARK: - Public

    /// يبدأ التجربة المجانية — ينحفظ التاريخ ومايتغير
    func startTrialIfNeeded() {
        // Check both Keychain and UserDefaults — trial may already exist from a previous install
        guard trialStartDate == nil else {
            refreshState()
            return
        }

        let now = nowProvider()
        defaults.set(now, forKey: Keys.trialStartDate)
        KeychainTrialHelper.writeTrialStartDate(now)
        Task { @MainActor in
            AnalyticsService.shared.track(.freeTrialStarted)
        }
        refreshState()
    }

    /// هل المستخدم بفترة التجربة المجانية النشطة؟
    var isTrialActive: Bool {
        if case .active = trialState { return true }
        return false
    }

    /// هل المستخدم جرب التطبيق قبل (بدأ trial سابقاً)؟
    var hasUsedTrial: Bool {
        trialStartDate != nil
    }

    /// كم يوم باقي بالتجربة
    var daysRemaining: Int {
        if case .active(let days) = trialState { return days }
        return 0
    }

    /// تاريخ انتهاء التجربة
    var trialEndDate: Date? {
        guard let startDate = trialStartDate else {
            return nil
        }
        return Calendar.current.date(byAdding: .day, value: Self.trialDurationDays, to: startDate)
    }

    /// Reads the trial start date from Keychain first (persists across reinstalls),
    /// falling back to UserDefaults. Syncs between the two stores if one is missing.
    private var trialStartDate: Date? {
        // Keychain is the source of truth (survives reinstall)
        if let keychainDate = KeychainTrialHelper.readTrialStartDate() {
            // Sync back to UserDefaults if it was lost (e.g. after reinstall)
            if defaults.object(forKey: Keys.trialStartDate) == nil {
                defaults.set(keychainDate, forKey: Keys.trialStartDate)
            }
            return keychainDate
        }
        // Fall back to UserDefaults
        if let defaultsDate = defaults.object(forKey: Keys.trialStartDate) as? Date {
            // Sync to Keychain so future reinstalls are protected
            KeychainTrialHelper.writeTrialStartDate(defaultsDate)
            return defaultsDate
        }
        return nil
    }

    /// يحدّث الحالة — ينادى عند فتح التطبيق
    func refreshState() {
        guard let startDate = trialStartDate else {
            trialState = .notStarted
            return
        }

        let now = nowProvider()
        let endDate = Calendar.current.date(byAdding: .day, value: Self.trialDurationDays, to: startDate) ?? startDate

        if now < endDate {
            let components = Calendar.current.dateComponents([.day], from: now, to: endDate)
            let remaining = max(components.day ?? 0, 0)
            trialState = .active(daysRemaining: remaining)
        } else {
            trialState = .expired
        }
    }

    #if DEBUG
    func resetTrial() {
        defaults.removeObject(forKey: Keys.trialStartDate)
        refreshState()
    }
    #endif

    private enum Keys {
        static let trialStartDate = "aiqo.freeTrial.startDate"
    }

    // MARK: - Keychain Helper (persists across app reinstalls)

    private enum KeychainTrialHelper {
        private static let service = "com.aiqo.trial"
        private static let account = "trialStartDate"

        static func readTrialStartDate() -> Date? {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]
            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            guard status == errSecSuccess, let data = result as? Data else { return nil }
            return try? JSONDecoder().decode(Date.self, from: data)
        }

        static func writeTrialStartDate(_ date: Date) {
            guard let data = try? JSONEncoder().encode(date) else { return }
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account
            ]
            SecItemDelete(query as CFDictionary)
            var newItem = query
            newItem[kSecValueData as String] = data
            SecItemAdd(newItem as CFDictionary, nil)
        }
    }
}
