import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var purchaseManager = PurchaseManager.shared
    @ObservedObject private var entitlementStore = EntitlementStore.shared

    @State private var processingProductID: String?
    @State private var statusMessage: String?
    @State private var isDebugTestSetupPresented = false
    @State private var isTribeFlowPresented = false

    let dismissOnFamilyUnlock: Bool

    private let productIDs = Array(SubscriptionProductIDs.allCurrentIDs)

    init(dismissOnFamilyUnlock: Bool = false) {
        self.dismissOnFamilyUnlock = dismissOnFamilyUnlock
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("paywall.duration".localized)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button {
                        isTribeFlowPresented = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("paywall.joinTribe".localized)
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .tracking(1.2)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }

                Section("paywall.plans".localized) {
                    if purchaseManager.isLoadingProducts {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else if let productLoadError = purchaseManager.productLoadErrorMessage {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(productLoadError)
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            Button("paywall.retry".localized) {
                                retryLoadingProducts()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(processingProductID != nil || purchaseManager.isLoadingProducts)

                            Button("paywall.restore".localized) {
                                restorePurchases()
                            }
                            .buttonStyle(.bordered)
                            .disabled(processingProductID != nil || purchaseManager.isLoadingProducts)
                        }
                        .padding(.vertical, 6)
                    } else {
                        ForEach(productIDs, id: \.self) { productID in
                            productRow(for: productID)
                        }
                    }
                }

                Section {
                    Button("paywall.restore".localized) {
                        restorePurchases()
                    }
                    .disabled(processingProductID != nil || purchaseManager.productLoadErrorMessage != nil)
                }

                Section {
                    LegalLinksView()
                }

                #if DEBUG
                if purchaseManager.productLoadErrorMessage != nil, let debugDetails = purchaseManager.productLoadDebugDetails {
                    Section("DEBUG") {
                        Text(debugDetails)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)

                        Button("Open test setup") {
                            isDebugTestSetupPresented = true
                        }
                        .buttonStyle(.bordered)
                        .disabled(processingProductID != nil || purchaseManager.isLoadingProducts)
                    }
                }

                Section("paywall.debug.testing".localized) {
                    Button("paywall.debug.resetPremium".localized) {
                        purchaseManager.debugResetPremiumData()
                        statusMessage = "paywall.debug.resetDone".localized
                    }
                    .foregroundStyle(.red)
                    .disabled(processingProductID != nil)
                }
                #endif

                if let statusMessage {
                    Section("paywall.status".localized) {
                        Text(statusMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else if let expiresAt = entitlementStore.expiresAt {
                    Section("paywall.status".localized) {
                        Text(statusText(expiresAt: expiresAt))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("paywall.title".localized)
            .task {
                await reloadProducts()
            }
            .sheet(isPresented: $isTribeFlowPresented) {
                TribeExperienceFlowView(source: .premium)
            }
            #if DEBUG
            .alert("paywall.debug.setupTitle".localized, isPresented: $isDebugTestSetupPresented) {
                Button("paywall.debug.ok".localized, role: .cancel) { }
            } message: {
                Text("paywall.debug.setupMessage".localized)
            }
            #endif
        }
    }

    @ViewBuilder
    private func productRow(for productID: String) -> some View {
        let product = purchaseManager.products.first(where: { $0.id == productID })
        let isProcessing = processingProductID == productID

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(SubscriptionProductIDs.displayName(for: productID)) - " + "paywall.thirtyDays".localized)
                        .font(.headline)
                    Text(product?.displayPrice ?? SubscriptionProductIDs.fallbackDisplayPrice(for: productID))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if SubscriptionProductIDs.isFamily(productID: productID) {
                    Label("paywall.tribe".localized, systemImage: "person.3.fill")
                        .font(.caption)
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(.secondary)
                }
            }

            Text(planDescription(for: productID))
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button {
                if let product {
                    purchase(product: product)
                }
            } label: {
                if isProcessing {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("paywall.buy".localized)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(product == nil || processingProductID != nil || purchaseManager.isLoadingProducts)
        }
        .padding(.vertical, 6)
    }

    private func reloadProducts() async {
        _ = await purchaseManager.refreshEntitlements()
        _ = await purchaseManager.loadProducts()
    }

    private func retryLoadingProducts() {
        Task {
            await reloadProducts()
        }
    }

    private func purchase(product: Product) {
        processingProductID = product.id

        Task {
            let outcome = await purchaseManager.purchase(product: product)
            await MainActor.run {
                processingProductID = nil
                statusMessage = statusMessage(for: outcome)
                dismissIfNeeded(after: outcome)
            }
        }
    }

    private func restorePurchases() {
        processingProductID = "restore"

        Task {
            let outcome = await purchaseManager.restorePurchases()
            await MainActor.run {
                processingProductID = nil
                statusMessage = statusMessage(for: outcome)
                dismissIfNeeded(after: outcome)
            }
        }
    }

    private func dismissIfNeeded(after outcome: PurchaseManager.PurchaseOutcome) {
        guard case .success = outcome else { return }
        guard entitlementStore.isActive || (dismissOnFamilyUnlock && entitlementStore.canCreateTribe) else { return }
        dismiss()
    }

    private func statusMessage(for outcome: PurchaseManager.PurchaseOutcome) -> String {
        switch outcome {
        case .success:
            if let expiresAt = entitlementStore.expiresAt {
                return statusText(expiresAt: expiresAt)
            }
            return "paywall.status.synced".localized
        case .pending:
            return "paywall.status.pending".localized
        case .cancelled:
            return "paywall.status.cancelled".localized
        case .failed(let message):
            return String(format: "paywall.status.failed".localized, message)
        }
    }

    private func statusText(expiresAt: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        let plan = SubscriptionProductIDs.displayName(for: entitlementStore.activeProductId ?? SubscriptionProductIDs.coreMonthly)
        let tribeNote = entitlementStore.canCreateTribe ? " " + "paywall.status.canCreateTribe".localized : ""
        return String(format: "paywall.status.currentPlan".localized, plan, formatter.string(from: expiresAt)) + tribeNote
    }

    private func planDescription(for productID: String) -> String {
        if SubscriptionProductIDs.isFamily(productID: productID) {
            return "paywall.plan.familyDescription".localized
        }

        return "paywall.plan.individualDescription".localized
    }
}

#Preview {
    PaywallView()
}
