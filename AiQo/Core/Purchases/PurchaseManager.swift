import Foundation
import os.log
import Combine
import StoreKit

@MainActor
final class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "AiQo", category: "PurchaseManager")

    #if DEBUG
    let useLocalStoreKitConfig = true
    #else
    let useLocalStoreKitConfig = false
    #endif

    enum PurchaseOutcome: Equatable {
        case success
        case pending
        case cancelled
        case failed(String)
    }

    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var productLoadErrorMessage: String?
    @Published private(set) var productLoadDebugDetails: String?
    @Published private(set) var lastOutcome: PurchaseOutcome?

    let entitlementStore: EntitlementStore

    private let calendar: Calendar
    private let nowProvider: () -> Date
    private let scheduleNotifications: @MainActor (Date) -> Void

    private var updatesTask: Task<Void, Never>?
    private var didStart = false
    private var didInspectLocalStoreKitConfig = false
    private let localStoreKitConfigurationName = "AiQo_Test.storekit"
    private let productLoadRetryDelayNanoseconds: UInt64 = 2_000_000_000
    private let userFacingProductLoadFailureMessage = "تعذر تحميل الباقات حالياً. حاول مرة ثانية."

    private init(
        calendar: Calendar = .current,
        nowProvider: @escaping () -> Date = Date.init,
        scheduleNotifications: @escaping @MainActor (Date) -> Void = PremiumExpiryNotifier.scheduleAllNotifications
    ) {
        self.entitlementStore = EntitlementStore.shared
        self.calendar = calendar
        self.nowProvider = nowProvider
        self.scheduleNotifications = scheduleNotifications
    }

    func start() {
        guard !didStart else { return }
        didStart = true
        observeTransactionUpdates()

        Task { @MainActor in
            _ = await refreshEntitlements()
        }
    }

    @discardableResult
    func refreshEntitlements() async -> Bool {
        await updateEntitlementsFromLatestTransactions()
        scheduleNotificationsIfNeeded()
        return entitlementStore.isActive
    }

    @discardableResult
    func loadProducts() async -> [Product] {
        prepareLocalStoreKitTestingIfNeeded()

        let requestedProductIDs = Array(SubscriptionProductIDs.allCurrentIDs)
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "nil"

        isLoadingProducts = true
        productLoadErrorMessage = nil
        productLoadDebugDetails = nil

        defer {
            isLoadingProducts = false
        }

        appendProductLoadDiagnostic("Current bundle identifier: \(bundleIdentifier)")
        appendProductLoadDiagnostic("Requested product IDs: \(requestedProductIDs)")

        for attempt in 1...2 {
            appendProductLoadDiagnostic("Loading products attempt \(attempt) of 2.")

            do {
                let loadedProducts = try await Product.products(for: requestedProductIDs)
                let sortedProducts = loadedProducts.sorted {
                    SubscriptionProductIDs.displayOrderIndex(for: $0.id) < SubscriptionProductIDs.displayOrderIndex(for: $1.id)
                }

                products = sortedProducts
                appendProductLoadDiagnostic("Returned products count: \(sortedProducts.count)")

                let returnedProductIDs = Set(sortedProducts.map(\.id))
                let missingProductIDs = requestedProductIDs.filter { !returnedProductIDs.contains($0) }
                if !missingProductIDs.isEmpty {
                    appendProductLoadDiagnostic("Missing product IDs from response: \(missingProductIDs)")
                }

                if !sortedProducts.isEmpty {
                    return sortedProducts
                }

                appendProductLoadDiagnostic("No products returned. Check App Store Connect product IDs, agreements, sandbox login, bundle id.")

                if attempt == 1 {
                    appendProductLoadDiagnostic("Retrying product request in 2 seconds to avoid transient StoreKit cache issues.")
                    try? await Task.sleep(nanoseconds: productLoadRetryDelayNanoseconds)
                    continue
                }

                appendNoProductsChecklist()
                products = []
                productLoadErrorMessage = userFacingProductLoadFailureMessage
                lastOutcome = .failed("No products returned")
                return []
            } catch {
                let message = error.localizedDescription
                appendProductLoadDiagnostic("Product load error: \(message)")

                if attempt == 1 {
                    appendProductLoadDiagnostic("Retrying product request in 2 seconds after the error.")
                    try? await Task.sleep(nanoseconds: productLoadRetryDelayNanoseconds)
                    continue
                }

                appendNoProductsChecklist()
                products = []
                productLoadErrorMessage = userFacingProductLoadFailureMessage
                lastOutcome = .failed(message)
                return []
            }
        }

        products = []
        productLoadErrorMessage = userFacingProductLoadFailureMessage
        return []
    }

    func debugResetPremiumData() {
#if DEBUG
        prepareLocalStoreKitTestingIfNeeded()

        entitlementStore.clear()
        productLoadErrorMessage = nil
        productLoadDebugDetails = nil
        lastOutcome = nil
        PremiumExpiryNotifier.clearScheduledNotifications()
        logger.debug("debug_premium_data_cleared")
#else
        logger.warning("debug_premium_reset_unavailable_in_release")
#endif
    }

    @discardableResult
    func purchase(product: Product) async -> PurchaseOutcome {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try Self.verifiedTransaction(from: verification)
                applySuccessfulPurchase(productId: transaction.productID)
                scheduleNotificationsIfNeeded()
                await transaction.finish()
                lastOutcome = .success
                logger.info("purchase_finished product=\(transaction.productID, privacy: .public)")

                // Server-side receipt validation (non-blocking)
                Task.detached(priority: .utility) {
                    _ = await ReceiptValidator.shared.validate(transaction: transaction)
                }

                return .success
            case .pending:
                lastOutcome = .pending
                logger.info("purchase_pending product=\(product.id, privacy: .public)")
                return .pending
            case .userCancelled:
                lastOutcome = .cancelled
                logger.info("purchase_cancelled product=\(product.id, privacy: .public)")
                return .cancelled
            @unknown default:
                let message = "Unknown StoreKit purchase state."
                lastOutcome = .failed(message)
                logger.warning("purchase_unknown_state message=\(message, privacy: .public)")
                return .failed(message)
            }
        } catch {
            let message = error.localizedDescription
            lastOutcome = .failed(message)
            logger.error("purchase_failed product=\(product.id, privacy: .public) error=\(message, privacy: .public)")
            return .failed(message)
        }
    }

    @discardableResult
    func restorePurchases() async -> PurchaseOutcome {
        do {
            try await AppStore.sync()
            _ = await refreshEntitlements()
            lastOutcome = .success
            logger.info("restore_completed product=\(self.entitlementStore.activeProductId ?? "nil", privacy: .public)")
            return .success
        } catch {
            let message = error.localizedDescription
            lastOutcome = .failed(message)
            logger.error("restore_failed error=\(message, privacy: .public)")
            return .failed(message)
        }
    }

    func updateEntitlementsFromLatestTransactions() async {
        let transactions = await verifiedTransactions()
        let state = Self.rebuiltState(from: transactions, calendar: calendar)

        if state.productId == nil, state.expiresAt == nil {
            entitlementStore.clear()
            logger.info("entitlement_cleared — no verified purchases found")
            return
        }

        entitlementStore.setEntitlement(productId: state.productId, expiresAt: state.expiresAt)
        logger.info("entitlement_refreshed product=\(state.productId ?? "nil", privacy: .public)")
    }

    private func applySuccessfulPurchase(productId: String) {
        let nextExpiry = Self.nextExpiryAfterPurchase(
            currentExpiresAt: entitlementStore.expiresAt,
            now: nowProvider(),
            calendar: calendar
        )
        entitlementStore.setEntitlement(productId: productId, expiresAt: nextExpiry)
    }

    private func scheduleNotificationsIfNeeded() {
        if let expiresAt = entitlementStore.expiresAt {
            scheduleNotifications(expiresAt)
        } else {
            PremiumExpiryNotifier.clearScheduledNotifications()
        }
    }

    private func observeTransactionUpdates() {
        updatesTask?.cancel()
        updatesTask = Task.detached(priority: .background) { [weak self] in
            for await verification in Transaction.updates {
                guard let self else { return }

                do {
                    let transaction = try Self.verifiedTransaction(from: verification)
                    await transaction.finish()

                    await MainActor.run {
                        self.lastOutcome = .success
                    }

                    await self.handleBackgroundTransactionUpdate(productId: transaction.productID)
                } catch {
                    self.logger.warning("unverified_transaction_update error=\(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }

    private func handleBackgroundTransactionUpdate(productId: String) async {
        _ = await refreshEntitlements()
        logger.info("transaction_update_processed product=\(productId, privacy: .public)")
    }

    private func appendProductLoadDiagnostic(_ line: String) {
        logger.debug("\(line, privacy: .public)")

        if let currentDetails = productLoadDebugDetails, !currentDetails.isEmpty {
            productLoadDebugDetails = currentDetails + "\n" + line
        } else {
            productLoadDebugDetails = line
        }
    }

    private func appendNoProductsChecklist() {
        appendProductLoadDiagnostic("Possible causes:")
        appendProductLoadDiagnostic("1. Paid Applications agreement, banking, or tax info is incomplete.")
        appendProductLoadDiagnostic("2. The in-app purchases are not ready yet in App Store Connect.")
        appendProductLoadDiagnostic("3. The app is not signed into the correct Sandbox Apple ID for testing.")
        appendProductLoadDiagnostic("4. The bundle identifier does not match the App Store Connect app.")
        appendProductLoadDiagnostic("5. One or more product IDs do not exactly match App Store Connect.")
    }

    private func prepareLocalStoreKitTestingIfNeeded() {
        guard useLocalStoreKitConfig else { return }

#if DEBUG
        if !didInspectLocalStoreKitConfig {
            logger.debug("using_local_storekit_config AiQo_Test.storekit")
        }
#endif

        let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

#if !targetEnvironment(simulator)
        guard isPreview else { return }
#endif
        guard !didInspectLocalStoreKitConfig else { return }
        didInspectLocalStoreKitConfig = true

        let fileStem = String(localStoreKitConfigurationName.dropLast(".storekit".count))

        if Bundle.main.url(forResource: fileStem, withExtension: "storekit") != nil {
            logger.debug("storekit_config_bundled name=\(self.localStoreKitConfigurationName, privacy: .public)")
        } else {
            let context = isPreview ? "Preview" : "Simulator"
            logger.debug("storekit_config_not_bundled context=\(context, privacy: .public) name=\(self.localStoreKitConfigurationName, privacy: .public)")
        }
    }

    private func verifiedTransactions() async -> [Transaction] {
        var transactions: [Transaction] = []

        for await verification in Transaction.all {
            do {
                let transaction = try Self.verifiedTransaction(from: verification)
                guard SubscriptionProductIDs.isAnyPremium(productID: transaction.productID) else { continue }
                guard transaction.revocationDate == nil else { continue }
                transactions.append(transaction)
            } catch {
                logger.warning("skipping_unverified_transaction error=\(error.localizedDescription, privacy: .public)")
            }
        }

        return transactions.sorted { $0.purchaseDate < $1.purchaseDate }
    }

    private static func rebuiltState(
        from transactions: [Transaction],
        calendar: Calendar
    ) -> EntitlementState {
        guard !transactions.isEmpty else {
            return EntitlementState(productId: nil, expiresAt: nil)
        }

        var productId: String?
        var expiresAt: Date?

        for transaction in transactions {
            let baseDate: Date
            if let expiresAt, expiresAt > transaction.purchaseDate {
                baseDate = expiresAt
            } else {
                baseDate = transaction.purchaseDate
            }

            productId = transaction.productID
            expiresAt = addThirtyDays(to: baseDate, calendar: calendar)
        }

        return EntitlementState(productId: productId, expiresAt: expiresAt)
    }

    nonisolated static func nextExpiryAfterPurchase(
        currentExpiresAt: Date?,
        now: Date,
        calendar: Calendar = .current
    ) -> Date {
        let baseDate: Date
        if let currentExpiresAt, currentExpiresAt > now {
            baseDate = currentExpiresAt
        } else {
            baseDate = now
        }

        return addThirtyDays(to: baseDate, calendar: calendar)
    }

    private nonisolated static func addThirtyDays(to date: Date, calendar: Calendar) -> Date {
        calendar.date(byAdding: .day, value: 30, to: date) ?? date.addingTimeInterval(30 * 24 * 60 * 60)
    }

    private nonisolated static func verifiedTransaction(
        from result: VerificationResult<Transaction>
    ) throws -> Transaction {
        switch result {
        case .verified(let transaction):
            return transaction
        case .unverified(_, let error):
            throw error
        }
    }
}

private struct EntitlementState {
    let productId: String?
    let expiresAt: Date?
}
