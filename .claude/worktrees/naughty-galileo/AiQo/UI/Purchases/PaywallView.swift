import SwiftUI
import StoreKit
import UIKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var purchaseManager = PurchaseManager.shared
    @ObservedObject private var entitlementStore = EntitlementStore.shared

    @State private var selectedProductID: String?
    @State private var processingProductID: String?
    @State private var statusMessage: String?
    @State private var isDebugTestSetupPresented = false
    @State private var isTribeFlowPresented = false

    private let onPurchaseSuccess: (() -> Void)?

    init(onPurchaseSuccess: (() -> Void)? = nil) {
        self.onPurchaseSuccess = onPurchaseSuccess
    }

    private var orderedProducts: [Product] {
        purchaseManager.products.sorted {
            SubscriptionProductIDs.displayOrderIndex(for: $0.id) < SubscriptionProductIDs.displayOrderIndex(for: $1.id)
        }
    }

    private var effectiveSelectedProductID: String {
        if let selectedProductID, orderedProducts.contains(where: { $0.id == selectedProductID }) {
            return selectedProductID
        }

        if orderedProducts.contains(where: { $0.id == SubscriptionProductIDs.intelligenceProMonthly }) {
            return SubscriptionProductIDs.intelligenceProMonthly
        }

        return orderedProducts.first?.id ?? SubscriptionProductIDs.standardMonthly
    }

    private var selectedProduct: Product? {
        orderedProducts.first(where: { $0.id == effectiveSelectedProductID })
    }

    private var isProcessingPurchase: Bool {
        guard let selectedProduct else { return false }
        return processingProductID == selectedProduct.id
    }

    private var isPerformingAction: Bool {
        processingProductID != nil
    }

    private var visibleStatusMessage: String? { statusMessage }

    private var isArabic: Bool {
        Locale.current.language.languageCode?.identifier == "ar"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                paywallBackground

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        heroSection

                        if statusMessage == nil, entitlementStore.isActive, let expiresAt = entitlementStore.expiresAt {
                            statusCard(text: statusText(expiresAt: expiresAt), tint: AiQoTheme.Colors.accent.opacity(0.14))
                        }

                        tribeEntryButton
                        plansSection

                        if let visibleStatusMessage {
                            statusCard(text: visibleStatusMessage, tint: AiQoTheme.Colors.ctaGradientTrailing.opacity(0.14))
                        }

                        if purchaseManager.productLoadErrorMessage == nil, !orderedProducts.isEmpty {
                            primaryActionSection
                            legalFooter
                        }

                        #if DEBUG
                        debugSection
                        #endif
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("paywall.title".localized)
            .navigationBarTitleDisplayMode(.inline)
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

    private var paywallBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    AiQoTheme.Colors.primaryBackground,
                    AiQoTheme.Colors.surfaceSecondary,
                    AiQoTheme.Colors.primaryBackground
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(AiQoTheme.Colors.accent.opacity(0.16))
                .frame(width: 260, height: 260)
                .blur(radius: 18)
                .offset(x: 120, y: -180)

            Circle()
                .fill(AiQoTheme.Colors.ctaGradientTrailing.opacity(0.12))
                .frame(width: 220, height: 220)
                .blur(radius: 20)
                .offset(x: -120, y: 260)
        }
        .ignoresSafeArea()
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(copy(
                        ar: "اختر مستوى AiQo المناسب لك",
                        en: "Choose the AiQo tier that fits you"
                    ))
                    .font(.system(size: 31, weight: .bold, design: .rounded))
                    .foregroundStyle(AiQoTheme.Colors.textPrimary)

                    Text(copy(
                        ar: "ثلاث خطط شهرية متجدّدة عبر StoreKit 2: Core و Pro و Intelligence.",
                        en: "Three monthly subscription tiers through StoreKit 2: Core, Pro, and Intelligence."
                    ))
                    .font(AiQoTheme.Typography.body)
                    .foregroundStyle(AiQoTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    AiQoTheme.Colors.ctaGradientLeading,
                                    AiQoTheme.Colors.ctaGradientTrailing
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 62, height: 62)

                    Image(systemName: "sparkles")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .shadow(color: AiQoTheme.Colors.accent.opacity(0.22), radius: 16, x: 0, y: 10)
            }

            HStack(spacing: 8) {
                Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                    .font(.caption.weight(.bold))
                Text(copy(
                    ar: "اشتراكات شهرية متجددة. يمكنك الترقية أو الإلغاء من آبل في أي وقت.",
                    en: "Monthly renewable subscriptions. Upgrade or cancel anytime from Apple."
                ))
                .font(AiQoTheme.Typography.caption)
            }
            .foregroundStyle(AiQoTheme.Colors.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(AiQoTheme.Colors.surface.opacity(0.72))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(AiQoTheme.Colors.border, lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var tribeEntryButton: some View {
        Button {
            isTribeFlowPresented = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 13, weight: .bold))

                Text("paywall.joinTribe".localized)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .tracking(isArabic ? 0 : 1.1)
            }
            .foregroundStyle(AiQoTheme.Colors.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(AiQoTheme.Colors.surface.opacity(0.82))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(AiQoTheme.Colors.borderStrong, lineWidth: 1)
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(AiQoPressButtonStyle())
    }

    @ViewBuilder
    private var plansSection: some View {
        if purchaseManager.isLoadingProducts {
            loadingStateCard
        } else if let productLoadErrorMessage = purchaseManager.productLoadErrorMessage {
            errorStateCard(message: productLoadErrorMessage)
        } else {
            VStack(spacing: 16) {
                ForEach(orderedProducts, id: \.id) { product in
                    tierCard(for: product)
                }
            }
        }
    }

    private var loadingStateCard: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)

            Text(copy(
                ar: "جارٍ تحميل الباقات الحالية…",
                en: "Loading the current subscription tiers..."
            ))
            .font(AiQoTheme.Typography.sectionTitle)
            .foregroundStyle(AiQoTheme.Colors.textPrimary)

            Text(copy(
                ar: "نطلب المنتجات مباشرة من App Store Connect عبر StoreKit 2.",
                en: "Products are being fetched directly from App Store Connect via StoreKit 2."
            ))
            .font(AiQoTheme.Typography.body)
            .foregroundStyle(AiQoTheme.Colors.textSecondary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AiQoTheme.Colors.surface.opacity(0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AiQoTheme.Colors.border, lineWidth: 1)
        )
    }

    private func errorStateCard(message: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label {
                Text(copy(
                    ar: "تعذر تحميل الاشتراكات",
                    en: "Could not load subscriptions"
                ))
                .font(AiQoTheme.Typography.sectionTitle)
            } icon: {
                Image(systemName: "wifi.exclamationmark")
            }
            .foregroundStyle(AiQoTheme.Colors.textPrimary)

            Text(message)
                .font(AiQoTheme.Typography.body)
                .foregroundStyle(AiQoTheme.Colors.textSecondary)

            VStack(spacing: 10) {
                secondaryActionButton(
                    title: "paywall.retry".localized,
                    tint: AiQoTheme.Colors.accent
                ) {
                    retryLoadingProducts()
                }

                secondaryActionButton(
                    title: "paywall.restore".localized,
                    tint: AiQoTheme.Colors.ctaGradientTrailing
                ) {
                    restorePurchases()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AiQoTheme.Colors.surface.opacity(0.84))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AiQoTheme.Colors.borderStrong, lineWidth: 1)
        )
    }

    private func tierCard(for product: Product) -> some View {
        let details = tierDetails(for: product.id)
        let isSelected = effectiveSelectedProductID == product.id

        return Button {
            selectedProductID = product.id
            statusMessage = nil
        } label: {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill((isSelected ? AiQoTheme.Colors.accent : details.tint).opacity(0.18))
                            .frame(width: 44, height: 44)

                        Image(systemName: details.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(isSelected ? AiQoTheme.Colors.accent : details.tint)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(product.displayName)
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(AiQoTheme.Colors.textPrimary)

                            if let badge = details.badge {
                                Text(badge)
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(isSelected ? .white : AiQoTheme.Colors.accent)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        Capsule(style: .continuous)
                                            .fill(isSelected ? AiQoTheme.Colors.accent : AiQoTheme.Colors.accent.opacity(0.12))
                                    )
                            }
                        }

                        Text(details.kicker)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(isSelected ? AiQoTheme.Colors.accent : AiQoTheme.Colors.textSecondary)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(isSelected ? AiQoTheme.Colors.accent : AiQoTheme.Colors.borderStrong)
                }

                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(product.displayPrice)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(AiQoTheme.Colors.textPrimary)

                    Text(copy(ar: "شهرياً", en: "monthly"))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(AiQoTheme.Colors.textSecondary)
                }

                Text(details.summary)
                    .font(AiQoTheme.Typography.body)
                    .foregroundStyle(AiQoTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(details.features, id: \.self) { feature in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(isSelected ? AiQoTheme.Colors.accent : details.tint)
                                .padding(.top, 2)

                            Text(feature)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(AiQoTheme.Colors.textPrimary)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background {
                PaywallGlassBackground(tint: UIColor(isSelected ? AiQoTheme.Colors.accent : details.tint))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(
                        isSelected ? AiQoTheme.Colors.accent : AiQoTheme.Colors.border,
                        lineWidth: isSelected ? 2 : 1
                    )
            }
        }
        .buttonStyle(AiQoPressButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var primaryActionSection: some View {
        VStack(spacing: 12) {
            Button {
                purchaseSelectedProduct()
            } label: {
                HStack(spacing: 10) {
                    if isProcessingPurchase {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "lock.open.fill")
                            .font(.system(size: 15, weight: .bold))

                        Text(copy(
                            ar: "اشترك في \(SubscriptionProductIDs.displayName(for: effectiveSelectedProductID))",
                            en: "Subscribe to \(SubscriptionProductIDs.displayName(for: effectiveSelectedProductID))"
                        ))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [
                            AiQoTheme.Colors.ctaGradientLeading,
                            AiQoTheme.Colors.ctaGradientTrailing
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 24, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                )
            }
            .buttonStyle(AiQoPressButtonStyle())
            .disabled(selectedProduct == nil || isPerformingAction || purchaseManager.isLoadingProducts)
            .opacity(selectedProduct == nil || isPerformingAction || purchaseManager.isLoadingProducts ? 0.65 : 1)

            secondaryActionButton(
                title: "paywall.restore".localized,
                tint: AiQoTheme.Colors.surfaceSecondary
            ) {
                restorePurchases()
            }
        }
    }

    private var legalFooter: some View {
        VStack(spacing: 12) {
            Text(copy(
                ar: "يتجدد الاشتراك كل شهر تلقائياً. يمكنك إدارة أو إلغاء الاشتراك من إعدادات Apple ID في أي وقت.",
                en: "Subscriptions renew monthly until cancelled. Manage or cancel anytime from your Apple ID settings."
            ))
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(AiQoTheme.Colors.textSecondary)
            .multilineTextAlignment(.center)

            VStack(spacing: 10) {
                LegalLinksView()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                PaywallGlassBackground(tint: .black)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            }
        }
    }

    @ViewBuilder
    private var debugSection: some View {
        if purchaseManager.productLoadErrorMessage != nil, let debugDetails = purchaseManager.productLoadDebugDetails {
            VStack(alignment: .leading, spacing: 12) {
                Text("DEBUG")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(AiQoTheme.Colors.textSecondary)

                Text(debugDetails)
                    .font(.caption2)
                    .foregroundStyle(AiQoTheme.Colors.textSecondary)
                    .textSelection(.enabled)

                secondaryActionButton(
                    title: "Open test setup",
                    tint: AiQoTheme.Colors.surfaceSecondary
                ) {
                    isDebugTestSetupPresented = true
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(AiQoTheme.Colors.surface.opacity(0.84))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(AiQoTheme.Colors.borderStrong, lineWidth: 1)
            )
        }

        VStack(alignment: .leading, spacing: 12) {
            Text("paywall.debug.testing".localized)
                .font(AiQoTheme.Typography.sectionTitle)
                .foregroundStyle(AiQoTheme.Colors.textPrimary)

            Button("paywall.debug.resetPremium".localized) {
                purchaseManager.debugResetPremiumData()
                statusMessage = "paywall.debug.resetDone".localized
            }
            .foregroundStyle(.red)
            .disabled(isPerformingAction)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AiQoTheme.Colors.surface.opacity(0.84))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AiQoTheme.Colors.border, lineWidth: 1)
        )
    }

    private func secondaryActionButton(
        title: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(AiQoTheme.Colors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(tint.opacity(0.14))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(tint.opacity(0.28), lineWidth: 1)
                )
        }
        .buttonStyle(AiQoPressButtonStyle())
        .disabled(isPerformingAction || purchaseManager.isLoadingProducts)
    }

    private func statusCard(text: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AiQoTheme.Colors.accent)
                .padding(.top, 2)

            Text(text)
                .font(AiQoTheme.Typography.body)
                .foregroundStyle(AiQoTheme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(tint)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AiQoTheme.Colors.border, lineWidth: 1)
        )
    }

    private func reloadProducts() async {
        purchaseManager.start()
        _ = await purchaseManager.refreshEntitlements()
        _ = await purchaseManager.loadProducts()
    }

    private func retryLoadingProducts() {
        statusMessage = nil

        Task {
            await reloadProducts()
        }
    }

    private func purchaseSelectedProduct() {
        guard let selectedProduct else { return }

        processingProductID = selectedProduct.id
        statusMessage = nil

        Task {
            let outcome = await purchaseManager.purchase(product: selectedProduct)
            await MainActor.run {
                processingProductID = nil
                statusMessage = statusMessage(for: outcome)
                dismissIfNeeded(after: outcome)
            }
        }
    }

    private func restorePurchases() {
        processingProductID = "restore"
        statusMessage = nil

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
        guard case .success = outcome, entitlementStore.isActive else { return }
        onPurchaseSuccess?()
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

        let activeProductID = entitlementStore.activeProductId ?? effectiveSelectedProductID
        let plan = SubscriptionProductIDs.displayName(for: activeProductID)
        return String(format: "paywall.status.currentPlan".localized, plan, formatter.string(from: expiresAt))
    }

    private func tierDetails(for productID: String) -> PaywallTierDetails {
        switch productID {
        case SubscriptionProductIDs.standardMonthly:
            return PaywallTierDetails(
                icon: "bolt.heart.fill",
                badge: nil,
                kicker: copy(ar: "تدريب AI أساسي", en: "Essential AI Coaching"),
                summary: copy(
                    ar: "كل أساسيات AiQo اليومية مع ٢٠ رسالة سحابية يومياً: الكابتن، التمرين، التغذية، والإيقاع اليومي.",
                    en: "The essential AiQo stack with 20 cloud messages per day: Captain, training, nutrition, and daily rhythm."
                ),
                features: [
                    copy(ar: "Captain Hamoudi كمدربك الشخصي", en: "Captain Hamoudi as your personal coach"),
                    copy(ar: "Gym و Kitchen و My Vibe", en: "Gym, Kitchen, and My Vibe"),
                    copy(ar: "٢٠ رسالة سحابية يومياً (Gemini Flash)", en: "20 cloud AI messages per day (Gemini Flash)"),
                    copy(ar: "Challenges يومية وإشعارات ذكية", en: "Daily Challenges and smart notifications")
                ],
                tint: AiQoTheme.Colors.surfaceSecondary
            )
        case SubscriptionProductIDs.proMonthly:
            return PaywallTierDetails(
                icon: "eye.fill",
                badge: copy(ar: "الأكثر شعبية", en: "Most popular"),
                kicker: copy(ar: "AI متقدم + رؤية المطبخ", en: "Advanced AI + Kitchen Vision"),
                summary: copy(
                    ar: "كل ما في Core مع ١٠٠ رسالة سحابية يومياً، ماسح المطبخ الذكي، وقمم.",
                    en: "Everything in Core with 100 cloud messages per day, Kitchen Scanner, and Peaks."
                ),
                features: [
                    copy(ar: "كل ميزات Core", en: "Everything in Core"),
                    copy(ar: "١٠٠ رسالة سحابية يومياً (Gemini Pro)", en: "100 cloud AI messages per day (Gemini Pro)"),
                    copy(ar: "Kitchen Scanner — ماسح المطبخ الذكي", en: "Kitchen Scanner — AI-powered food vision"),
                    copy(ar: "Peaks / قمم و HRR", en: "Peaks and HRR assessment")
                ],
                tint: AiQoTheme.Colors.accent
            )
        case SubscriptionProductIDs.intelligenceProMonthly:
            return PaywallTierDetails(
                icon: "brain.head.profile",
                badge: copy(ar: "الأكثر اكتمالاً", en: "Most complete"),
                kicker: copy(ar: "ذكاء حيوي-رقمي بلا حدود", en: "Limitless Bio-Digital Intelligence"),
                summary: copy(
                    ar: "رسائل سحابية غير محدودة، ذاكرة موسعة، واستدلال عميق مع مشاريع الأرقام القياسية.",
                    en: "Unlimited cloud messages, extended memory, deep reasoning, and record projects."
                ),
                features: [
                    copy(ar: "كل ميزات Pro", en: "Everything in Pro"),
                    copy(ar: "رسائل سحابية غير محدودة (Gemini Ultra)", en: "Unlimited cloud AI messages (Gemini Ultra)"),
                    copy(ar: "Extended Memory حتى 500 ذكرى", en: "Extended Memory up to 500 memories"),
                    copy(ar: "مشاريع الأرقام القياسية والمراجعة الأسبوعية", en: "Record projects and weekly review"),
                    copy(ar: "استدلال عميق ومتقدم", en: "Deep analytical reasoning")
                ],
                tint: AiQoTheme.Colors.ctaGradientTrailing
            )
        default:
            return PaywallTierDetails(
                icon: "sparkles",
                badge: nil,
                kicker: copy(ar: "خطة AiQo", en: "AiQo tier"),
                summary: "",
                features: [],
                tint: AiQoTheme.Colors.surfaceSecondary
            )
        }
    }

    private func copy(ar: String, en: String) -> String {
        isArabic ? ar : en
    }
}

private struct PaywallTierDetails {
    let icon: String
    let badge: String?
    let kicker: String
    let summary: String
    let features: [String]
    let tint: Color
}

private struct PaywallGlassBackground: UIViewRepresentable {
    let tint: UIColor

    func makeUIView(context: Context) -> GlassCardView {
        let view = GlassCardView()
        view.isUserInteractionEnabled = false
        view.setTint(tint)
        return view
    }

    func updateUIView(_ uiView: GlassCardView, context: Context) {
        uiView.setTint(tint)
    }
}

#Preview {
    PaywallView()
}
