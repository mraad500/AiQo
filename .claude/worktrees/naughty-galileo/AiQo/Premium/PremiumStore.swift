import Foundation
import Combine
import StoreKit

enum PremiumPlan: String, CaseIterable, Identifiable {
    case standard
    case pro
    case intelligencePro

    var id: String { rawValue }

    var canonicalProductID: String {
        switch self {
        case .standard:
            return SubscriptionProductIDs.standardMonthly
        case .pro:
            return SubscriptionProductIDs.proMonthly
        case .intelligencePro:
            return SubscriptionProductIDs.intelligenceProMonthly
        }
    }

    var title: String {
        switch self {
        case .standard:
            return "AiQo Core"
        case .pro:
            return "AiQo Pro"
        case .intelligencePro:
            return "AiQo Intelligence"
        }
    }

    var description: String {
        switch self {
        case .standard:
            return localized(
                ar: "تدريب AI أساسي: الكابتن، Gym، Kitchen، My Vibe، والتحديات اليومية. ٢٠ رسالة سحابية يومياً.",
                en: "Essential AI Coaching: Captain, Gym, Kitchen, My Vibe, and daily Challenges. 20 cloud messages per day."
            )
        case .pro:
            return localized(
                ar: "AI متقدم + رؤية المطبخ. ١٠٠ رسالة سحابية يومياً، ماسح المطبخ الذكي، وقمم.",
                en: "Advanced AI + Kitchen Vision. 100 cloud messages per day, Kitchen Scanner, and Peaks."
            )
        case .intelligencePro:
            return localized(
                ar: "ذكاء حيوي-رقمي بلا حدود. رسائل سحابية غير محدودة، ذاكرة موسعة، واستدلال عميق.",
                en: "Limitless Bio-Digital Intelligence. Unlimited cloud messages, extended memory, and deep reasoning."
            )
        }
    }

    static func fromStoredValue(_ value: String) -> PremiumPlan? {
        switch value {
        case "standard", "core", "individual":
            return .standard
        case "pro":
            return .pro
        case "intelligencePro", "intelligence", "family":
            return .intelligencePro
        default:
            return PremiumPlan(rawValue: value)
        }
    }

    private func localized(ar: String, en: String) -> String {
        let isArabic = Locale.current.language.languageCode?.identifier == "ar"
        return isArabic ? ar : en
    }
}

@MainActor
final class PremiumStore: ObservableObject {
    static let shared = PremiumStore()

    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoading = false
    @Published private(set) var statusMessage: String?

    var activeProductId: String? { accessManager.activeProductId }

    var expiresAt: Date? {
        entitlementStore.expiresAt
    }

    var hasAnyPremiumAccess: Bool {
        accessManager.canAccessTribe
    }

    var canJoinTribe: Bool {
        accessManager.canAccessTribe
    }

    var canCreateTribe: Bool {
        accessManager.canCreateTribe
    }

    private let purchaseManager = PurchaseManager.shared
    private let entitlementStore = EntitlementStore.shared
    private let accessManager = AccessManager.shared
    private var cancellables: Set<AnyCancellable> = []
    private var didStart = false

    private init() {
        bind()
    }

    func start() {
        guard !didStart else { return }
        didStart = true
        purchaseManager.start()

        Task {
            await refresh()
        }
    }

    func refresh() async {
        isLoading = true
        _ = await purchaseManager.refreshEntitlements()
        _ = await purchaseManager.loadProducts()
        isLoading = false
        products = purchaseManager.products
    }

    func purchase(_ plan: PremiumPlan) async {
        guard let product = product(for: plan) else {
            statusMessage = "premium.error.productMissing".localized
            return
        }

        isLoading = true
        let outcome = await purchaseManager.purchase(product: product)
        isLoading = false
        products = purchaseManager.products
        statusMessage = message(for: outcome)

        switch outcome {
        case .success:
            AnalyticsService.shared.track(.subscriptionStarted(
                plan: plan.rawValue,
                price: product.displayPrice
            ))
        case .failed(let msg):
            AnalyticsService.shared.track(.subscriptionFailed(
                plan: plan.rawValue,
                error: msg
            ))
        case .cancelled:
            AnalyticsService.shared.track(.subscriptionCancelled)
        case .pending:
            break
        }
    }

    func restore() async {
        isLoading = true
        let outcome = await purchaseManager.restorePurchases()
        isLoading = false
        products = purchaseManager.products
        statusMessage = message(for: outcome)

        if case .success = outcome {
            AnalyticsService.shared.track(.subscriptionRestored)
        }
    }

    func product(for plan: PremiumPlan) -> Product? {
        products.first(where: { $0.id == plan.canonicalProductID })
    }

    private func bind() {
        purchaseManager.$products
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                self?.products = $0
            }
            .store(in: &cancellables)

        purchaseManager.$lastOutcome
            .receive(on: RunLoop.main)
            .sink { [weak self] outcome in
                guard let self, let outcome else { return }
                self.statusMessage = self.message(for: outcome)
            }
            .store(in: &cancellables)

        entitlementStore.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        accessManager.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    private func message(for outcome: PurchaseManager.PurchaseOutcome) -> String {
        switch outcome {
        case .success:
            if let expiresAt = entitlementStore.expiresAt {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                return String(
                    format: "premium.status.activeUntil".localized,
                    locale: Locale.current,
                    formatter.string(from: expiresAt)
                )
            }
            return "premium.status.synced".localized
        case .pending:
            return "premium.status.pending".localized
        case .cancelled:
            return "premium.status.cancelled".localized
        case .failed(let message):
            return String(
                format: "premium.status.failed".localized,
                locale: Locale.current,
                message
            )
        }
    }
}
