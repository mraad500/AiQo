import Foundation
internal import Combine
import StoreKit

@MainActor
final class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()

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

        let requestedProductIDs = SubscriptionProductIDs.storeKitLookupIDs
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
        print("🛒 DEBUG premium data cleared. Local entitlement and scheduled premium notifications were removed.")
#else
        print("🛒 DEBUG premium reset is unavailable in non-DEBUG builds.")
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
                print("🛒 Purchase finished for \(transaction.productID). New expiry: \(entitlementStore.expiresAt?.description ?? "nil")")

                // Server-side receipt validation (non-blocking)
                Task.detached(priority: .utility) {
                    _ = await ReceiptValidator.shared.validate(transaction: transaction)
                }

                return .success
            case .pending:
                lastOutcome = .pending
                print("🛒 Purchase is pending for \(product.id).")
                return .pending
            case .userCancelled:
                lastOutcome = .cancelled
                print("🛒 Purchase cancelled for \(product.id).")
                return .cancelled
            @unknown default:
                let message = "Unknown StoreKit purchase state."
                lastOutcome = .failed(message)
                print("🛒 \(message)")
                return .failed(message)
            }
        } catch {
            let message = error.localizedDescription
            lastOutcome = .failed(message)
            print("🛒 Purchase failed for \(product.id): \(message)")
            return .failed(message)
        }
    }

    @discardableResult
    func restorePurchases() async -> PurchaseOutcome {
        do {
            try await AppStore.sync()
            _ = await refreshEntitlements()
            lastOutcome = .success
            print("🛒 Restore completed. Active product: \(entitlementStore.activeProductId ?? "nil"), expiresAt: \(entitlementStore.expiresAt?.description ?? "nil")")
            return .success
        } catch {
            let message = error.localizedDescription
            lastOutcome = .failed(message)
            print("🛒 Restore failed: \(message)")
            return .failed(message)
        }
    }

    func updateEntitlementsFromLatestTransactions() async {
        let transactions = await verifiedTransactions()
        let state = Self.rebuiltState(from: transactions, calendar: calendar)

        if state.productId == nil, state.expiresAt == nil {
            entitlementStore.clear()
            print("🛒 Cleared local entitlement because no verified purchases were found.")
            return
        }

        entitlementStore.setEntitlement(productId: state.productId, expiresAt: state.expiresAt)
        print("🛒 Refreshed entitlement from StoreKit history. productId=\(state.productId ?? "nil"), expiresAt=\(state.expiresAt?.description ?? "nil")")
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
                    print("🛒 Ignored unverified transaction update: \(error.localizedDescription)")
                }
            }
        }
    }

    private func handleBackgroundTransactionUpdate(productId: String) async {
        _ = await refreshEntitlements()
        print("🛒 Processed StoreKit transaction update for \(productId).")
    }

    private func appendProductLoadDiagnostic(_ line: String) {
        print("🛒 \(line)")

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
            print("🛒 Using StoreKit Configuration AiQo_Test.storekit. Ensure scheme is configured.")
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
            print("🛒 \(localStoreKitConfigurationName) is bundled. Run the app from Xcode with the StoreKit configuration enabled for local testing.")
        } else {
            let context = isPreview ? "Preview" : "Simulator"
            print("🛒 \(context) detected. \(localStoreKitConfigurationName) is not bundled. If products fail to load locally, set Scheme > Run > Options > StoreKit Configuration to AiQo/Resources/\(localStoreKitConfigurationName).")
        }
    }

    private func verifiedTransactions() async -> [Transaction] {
        var transactions: [Transaction] = []

        for await verification in Transaction.all {
            do {
                let transaction = try Self.verifiedTransaction(from: verification)
                guard SubscriptionProductIDs.all.contains(transaction.productID) else { continue }
                guard transaction.revocationDate == nil else { continue }
                transactions.append(transaction)
            } catch {
                print("🛒 Skipping unverified historical transaction: \(error.localizedDescription)")
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
