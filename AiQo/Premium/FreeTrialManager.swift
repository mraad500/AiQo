import Foundation

/// يدير فترة التجربة المجانية (7 أيام) — بدون اشتراك StoreKit
/// الفكرة: أول ما المستخدم يفتح التطبيق، يبدأ العد التنازلي 7 أيام
/// خلال هالفترة يقدر يستخدم كل الميزات المدفوعة
@MainActor
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
        guard defaults.object(forKey: Keys.trialStartDate) == nil else {
            refreshState()
            return
        }

        let now = nowProvider()
        defaults.set(now, forKey: Keys.trialStartDate)
        AnalyticsService.shared.track(.freeTrialStarted)
        refreshState()
    }

    /// هل المستخدم بفترة التجربة المجانية النشطة؟
    var isTrialActive: Bool {
        if case .active = trialState { return true }
        return false
    }

    /// هل المستخدم جرب التطبيق قبل (بدأ trial سابقاً)؟
    var hasUsedTrial: Bool {
        defaults.object(forKey: Keys.trialStartDate) != nil
    }

    /// كم يوم باقي بالتجربة
    var daysRemaining: Int {
        if case .active(let days) = trialState { return days }
        return 0
    }

    /// تاريخ انتهاء التجربة
    var trialEndDate: Date? {
        guard let startDate = defaults.object(forKey: Keys.trialStartDate) as? Date else {
            return nil
        }
        return Calendar.current.date(byAdding: .day, value: Self.trialDurationDays, to: startDate)
    }

    /// يحدّث الحالة — ينادى عند فتح التطبيق
    func refreshState() {
        guard let startDate = defaults.object(forKey: Keys.trialStartDate) as? Date else {
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
}
