import SwiftUI
import StoreKit
import UIKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss

    @StateObject private var purchaseManager = PurchaseManager.shared
    @ObservedObject private var entitlementStore = EntitlementStore.shared
    @AppStorage("aiqo.app.language") private var appLanguage = AppLanguage.arabic.rawValue

    @Namespace private var selectionNamespace

    @State private var selectedProductID: String?
    @State private var processingProductID: String?
    @State private var statusMessage: String?
    @State private var showPrivacyPolicy = false
    @State private var showTermsOfService = false

    private let supportedTiers: [SubscriptionTier] = [.max, .pro]
    private let onPurchaseSuccess: (() -> Void)?
    let source: PaywallSource

    init(source: PaywallSource = .manual, onPurchaseSuccess: (() -> Void)? = nil) {
        self.source = source
        self.onPurchaseSuccess = onPurchaseSuccess
    }

    private var orderedProducts: [Product] {
        purchaseManager.products.sorted {
            SubscriptionProductIDs.displayOrderIndex(for: $0.id) < SubscriptionProductIDs.displayOrderIndex(for: $1.id)
        }
    }

    private var isArabic: Bool {
        appLanguage == AppLanguage.arabic.rawValue
    }

    private var plans: [PaywallPlanModel] {
        supportedTiers.map { tier in
            PaywallPlanModel(
                tier: tier,
                product: orderedProducts.first(where: { SubscriptionTier.from(productID: $0.id) == tier }),
                details: details(for: tier)
            )
        }
    }

    private var effectiveSelectedProductID: String {
        if let selectedProductID, plans.contains(where: { $0.productID == selectedProductID }) {
            return selectedProductID
        }

        return SubscriptionTier.pro.productID
    }

    private var selectedPlan: PaywallPlanModel? {
        plans.first(where: { $0.productID == effectiveSelectedProductID })
    }

    private var missingPlans: [PaywallPlanModel] {
        plans.filter { $0.product == nil }
    }

    private var selectedProduct: Product? {
        orderedProducts.first(where: { $0.id == effectiveSelectedProductID })
    }

    private var isProcessingPurchase: Bool {
        processingProductID == effectiveSelectedProductID
    }

    private var isRestoringPurchases: Bool {
        processingProductID == "restore"
    }

    private var isPerformingAction: Bool {
        processingProductID != nil
    }

    private var actionGradientColors: [Color] {
        selectedPlan?.details.gradientColors ?? [Color(hex: "5ECDB7"), Color(hex: "B7E5D2")]
    }

    private var actionSubtitle: String {
        guard let selectedPlan else {
            return copy(ar: "جارٍ تحميل الباقات الحالية…", en: "Loading the available plans...")
        }

        if purchaseManager.isLoadingProducts && selectedProduct == nil {
            return copy(
                ar: "نزامن سعر \(selectedPlan.details.title) الآن من App Store",
                en: "Syncing the \(selectedPlan.details.title) price from the App Store"
            )
        }

        if selectedPlan.product == nil {
            return copy(
                ar: "هذه الباقة غير مربوطة بالكامل في App Store Connect حتى الآن",
                en: "This tier is not fully connected in App Store Connect yet"
            )
        }

        return copy(
            ar: "الخطة المختارة: \(selectedPlan.details.title) • ثم \(selectedPlan.priceText) شهرياً",
            en: "Selected tier: \(selectedPlan.details.title) • then \(selectedPlan.priceText) monthly"
        )
    }

    var body: some View {
        ZStack {
            paywallBackground

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    contextBanner
                    heroSection
                    credibilityStrip

                    if purchaseManager.isLoadingProducts && orderedProducts.isEmpty {
                        infoBanner(
                            icon: "arrow.triangle.2.circlepath.circle.fill",
                            title: copy(ar: "جارٍ تحميل الأسعار", en: "Loading pricing"),
                            message: copy(
                                ar: "نطلب الباقات مباشرة من App Store Connect حتى يظهر سعر كل باقة بدقة.",
                                en: "Fetching your plans directly from App Store Connect so each tier shows its live price."
                            ),
                            tint: Color(hex: "5ECDB7")
                        )
                    }

                    if !purchaseManager.isLoadingProducts, !missingPlans.isEmpty {
                        infoBanner(
                            icon: "exclamationmark.triangle.fill",
                            title: copy(ar: "بعض الباقات غير جاهزة بعد", en: "Some tiers are not ready yet"),
                            message: copy(
                                ar: "أكمل إعداد هذه الباقات في App Store Connect: \(missingPlans.map(\.details.title).joined(separator: "، ")).",
                                en: "Finish setting up these tiers in App Store Connect: \(missingPlans.map(\.details.title).joined(separator: ", "))."
                            ),
                            tint: Color(hex: "EBCF97")
                        )
                    }

                    if let productLoadErrorMessage = purchaseManager.productLoadErrorMessage {
                        errorBanner(message: productLoadErrorMessage)
                    }

                    if statusMessage == nil, entitlementStore.isActive, let expiresAt = entitlementStore.expiresAt {
                        infoBanner(
                            icon: "checkmark.shield.fill",
                            title: copy(ar: "اشتراكك الحالي نشط", en: "Your subscription is active"),
                            message: statusText(expiresAt: expiresAt),
                            tint: Color(hex: "B7E5D2")
                        )
                    }

                    plansSection

                    if let statusMessage {
                        infoBanner(
                            icon: "sparkles",
                            title: copy(ar: "حالة الاشتراك", en: "Subscription status"),
                            message: statusMessage,
                            tint: Color(hex: "EBCF97")
                        )
                    }

                    #if DEBUG
                    debugSection
                    #endif
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 250)
            }
        }
        .safeAreaInset(edge: .bottom) {
            purchaseActionBar
        }
        .task {
            await reloadProducts()
            AnalyticsService.shared.track(.paywallShown(source: source.rawValue))
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            LegalView(type: .privacyPolicy)
        }
        .sheet(isPresented: $showTermsOfService) {
            LegalView(type: .termsOfService)
        }
        .environment(\.layoutDirection, isArabic ? .rightToLeft : .leftToRight)
        .environment(\.locale, Locale(identifier: isArabic ? "ar" : "en"))
    }

    private var paywallBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: "06131A"),
                    Color(hex: "0B1016"),
                    Color(hex: "121C24")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color(hex: "5ECDB7").opacity(0.22))
                .frame(width: 320, height: 320)
                .blur(radius: 90)
                .offset(x: isArabic ? 120 : -120, y: -220)

            Circle()
                .fill(Color(hex: "EBCF97").opacity(0.18))
                .frame(width: 280, height: 280)
                .blur(radius: 100)
                .offset(x: isArabic ? -140 : 140, y: 260)

            Circle()
                .fill(Color(hex: "B7E5D2").opacity(0.12))
                .frame(width: 260, height: 260)
                .blur(radius: 80)
                .offset(x: isArabic ? 150 : -150, y: 480)

            Rectangle()
                .fill(.ultraThinMaterial.opacity(0.12))
        }
        .ignoresSafeArea()
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    heroPill(
                        icon: "sparkles",
                        title: copy(ar: "7 أيام مجانية", en: "7 free days")
                    )

                    heroPill(
                        icon: "lock.open.fill",
                        title: copy(ar: "فتح كامل بعد التفعيل", en: "Unlocks the full dashboard")
                    )

                    heroPill(
                        icon: "arrow.uturn.backward.circle",
                        title: copy(ar: "إلغاء في أي وقت", en: "Cancel anytime")
                    )
                }
                .padding(.vertical, 2)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(copy(
                    ar: "اكتشف قدراتك الحقيقية مع AiQo",
                    en: "Discover your true potential with AiQo"
                ))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

                Text(copy(
                    ar: "خياران واضحان فقط: AiQo Max للسرعة اليومية والتتبع الكامل، أو AiQo Intelligence Pro لفتح القمم وذاكرة كابتن أوسع وتحليل أعمق.",
                    en: "Two clear options only: AiQo Max for fast everyday coaching and full tracking, or AiQo Intelligence Pro for Peaks, expanded Captain memory, and deeper AI analysis."
                ))
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    benefitChip(title: copy(ar: "Captain السريع", en: "Fast Captain"))
                    benefitChip(title: copy(ar: "Kitchen + Gym", en: "Kitchen + Gym"))
                    benefitChip(title: copy(ar: "تتبع نمط الحياة", en: "Lifestyle Tracking"))
                    benefitChip(title: copy(ar: "Peaks", en: "Peaks"))
                }
                .padding(.vertical, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func heroPill(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))

            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(.white.opacity(0.9))
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private func benefitChip(title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.white.opacity(0.82))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.black.opacity(0.18))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }

    private var credibilityStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                credibilityItem(
                    icon: "heart.text.square.fill",
                    title: copy(ar: "ذكاء صحي", en: "Health intelligence")
                )

                credibilityItem(
                    icon: "moon.stars.fill",
                    title: copy(ar: "نوم وتحليل", en: "Sleep insights")
                )

                credibilityItem(
                    icon: "figure.run.circle.fill",
                    title: copy(ar: "تدريب حي", en: "Live coaching")
                )
            }
            .padding(.vertical, 2)
        }
    }

    private func credibilityItem(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color(hex: "B7E5D2"))

            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.82))
                .lineLimit(2)
        }
        .frame(width: 140, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var plansSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(copy(
                ar: "اختر باقتك الآن",
                en: "Choose your tier now"
            ))
            .font(.system(size: 21, weight: .bold, design: .rounded))
            .foregroundStyle(.white)

            Text(copy(
                ar: "بطاقتان فقط: AiQo Max للسرعة والتتبع اليومي الكامل، وAiQo Intelligence Pro لكل شيء مع ميزة القمم وذاكرة ممتدة للكابتن.",
                en: "Just two cards: AiQo Max for speed and complete everyday tracking, or AiQo Intelligence Pro for the full experience with Peaks and expanded Captain memory."
            ))
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundStyle(Color.white.opacity(0.62))
            .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 20) {
                ForEach(plans) { plan in
                    tierCard(for: plan)
                }
            }
            .padding(.top, 4)
        }
    }

    private func tierCard(for plan: PaywallPlanModel) -> some View {
        let isSelected = effectiveSelectedProductID == plan.productID
        let isAvailable = plan.product != nil || purchaseManager.isLoadingProducts
        let priceCaption = purchaseManager.isLoadingProducts && plan.product == nil
            ? copy(ar: "جارٍ مزامنة السعر من App Store", en: "Syncing price from the App Store")
            : !isAvailable
                ? copy(ar: "أكمل إنشاء هذه الباقة في App Store Connect", en: "Finish creating this tier in App Store Connect")
            : copy(ar: "7 أيام مجانية ثم يتجدد تلقائياً", en: "7 free days, then renews automatically")

        return Button {
            guard isAvailable else {
                statusMessage = copy(
                    ar: "باقة \(plan.details.title) غير جاهزة بعد في App Store Connect.",
                    en: "\(plan.details.title) is not ready in App Store Connect yet."
                )
                return
            }

            withAnimation(.spring(response: 0.44, dampingFraction: 0.82)) {
                selectedProductID = plan.productID
                statusMessage = nil
            }
        } label: {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 12) {
                    if let badge = plan.details.badge {
                        Text(badge)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(hex: "0F1721"))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(hex: "EBCF97"),
                                                Color(hex: "F7E5BE")
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                    }

                    if !isAvailable {
                        Text(copy(ar: "غير جاهز", en: "Not ready"))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.86))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.white.opacity(0.10))
                            )
                    }

                    Spacer(minLength: 0)

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(isSelected ? plan.details.secondaryTint : Color.white.opacity(0.34))
                }

                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: plan.details.gradientColors.map { $0.opacity(0.92) },
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 54, height: 54)

                        Image(systemName: plan.details.icon)
                            .font(.system(size: 21, weight: .bold))
                            .foregroundStyle(Color(hex: "071015"))
                    }
                    .shadow(color: plan.details.glow.opacity(0.35), radius: 18, x: 0, y: 10)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(plan.details.title)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text(plan.details.eyebrow)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(plan.details.secondaryTint)

                        Text(plan.details.summary)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.68))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(plan.priceText)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text(copy(ar: "/ شهرياً", en: "/ month"))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.54))
                    }

                    Text(priceCaption)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.52))
                }

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(plan.details.features) { feature in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: feature.icon)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(plan.details.secondaryTint)
                                .frame(width: 18)
                                .padding(.top, 2)

                            Text(feature.text)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.86))
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(plan.details.isFeatured ? 24 : 22)
            .background {
                PaywallGlassPanelBackground(
                    style: plan.details.glassStyle,
                    tint: UIColor(plan.details.tint),
                    intensity: plan.details.tintIntensity
                )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(Color.white.opacity(isSelected ? 0.18 : 0.08), lineWidth: 1)
                    .overlay {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 30, style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        colors: plan.details.gradientColors,
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2.4
                                )
                                .matchedGeometryEffect(id: "selected-tier-outline", in: selectionNamespace)
                        }
                    }
            }
            .shadow(
                color: (isSelected ? plan.details.glow.opacity(0.28) : Color.black.opacity(0.12)),
                radius: isSelected ? 26 : 16,
                x: 0,
                y: isSelected ? 16 : 10
            )
            .opacity(isAvailable ? 1 : 0.76)
            .scaleEffect(isSelected ? 1.05 : (plan.details.isFeatured ? 1.03 : 1.0))
            .animation(.spring(response: 0.44, dampingFraction: 0.82), value: effectiveSelectedProductID)
        }
        .buttonStyle(AiQoPressButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func infoBanner(icon: String, title: String, message: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.18))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(message)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background {
            PaywallGlassPanelBackground(
                style: .soft,
                tint: UIColor(tint),
                intensity: 0.14
            )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
    }

    private func errorBanner(message: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            infoBanner(
                icon: "wifi.exclamationmark",
                title: copy(ar: "تعذر تحميل الاشتراكات", en: "Couldn't load subscriptions"),
                message: message,
                tint: Color(hex: "EBCF97")
            )

            Button {
                retryLoadingProducts()
            } label: {
                Text(copy(ar: "إعادة المحاولة", en: "Retry"))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: "091117"))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color(hex: "EBCF97"))
                    )
            }
            .buttonStyle(AiQoPressButtonStyle())
            .disabled(isPerformingAction)
        }
    }

    private var purchaseActionBar: some View {
        VStack(spacing: 10) {
            Text(copy(
                ar: "تجربة مجانية 7 أيام، ثم يتجدد الاشتراك شهرياً تلقائياً حتى تلغيه. يمكنك الإلغاء بأي وقت من الإعدادات > Apple ID > الاشتراكات.",
                en: "7-day free trial, then auto-renews monthly until canceled. Cancel anytime in Settings > Apple ID > Subscriptions."
            ))
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(Color.white.opacity(0.62))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)

            Button {
                purchaseSelectedProduct()
            } label: {
                VStack(spacing: 6) {
                    HStack(spacing: 10) {
                        if isProcessingPurchase {
                            ProgressView()
                                .tint(Color(hex: "071015"))
                        } else {
                            Image(systemName: "sparkles.rectangle.stack.fill")
                                .font(.system(size: 15, weight: .bold))

                            Text(copy(
                                ar: "ابدأ فترتك التجريبية المجانية (7 أيام)",
                                en: "Start your 7-day free trial"
                            ))
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                        }
                    }

                    Text(actionSubtitle)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(hex: "071015").opacity(0.78))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(Color(hex: "071015"))
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 18)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(
                        colors: actionGradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 28, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.22), lineWidth: 1)
                )
                .shadow(
                    color: (selectedPlan?.details.glow ?? Color(hex: "5ECDB7")).opacity(0.28),
                    radius: 24,
                    x: 0,
                    y: 14
                )
            }
            .buttonStyle(AiQoPressButtonStyle())
            .disabled(selectedProduct == nil || isPerformingAction || purchaseManager.isLoadingProducts)
            .opacity(selectedProduct == nil || isPerformingAction || purchaseManager.isLoadingProducts ? 0.65 : 1)

            HStack(spacing: 14) {
                footerTextButton(
                    title: isRestoringPurchases
                        ? copy(ar: "جارٍ الاستعادة…", en: "Restoring...")
                        : copy(ar: "استعادة المشتريات", en: "Restore Purchases")
                ) {
                    restorePurchases()
                }
                .disabled(isPerformingAction || purchaseManager.isLoadingProducts)

                footerDivider

                footerTextButton(title: "legal.terms.title".localized) {
                    showTermsOfService = true
                }

                footerDivider

                footerTextButton(title: "legal.privacy.title".localized) {
                    showPrivacyPolicy = true
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.black.opacity(0.34))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
                .padding(.horizontal, 10)
                .padding(.bottom, 4)
        )
    }

    private func footerTextButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.54))
        }
        .buttonStyle(.plain)
    }

    private var footerDivider: some View {
        Text("·")
            .foregroundStyle(Color.white.opacity(0.28))
    }

    #if DEBUG
    private var debugSection: some View {
        Group {
            if let debugDetails = purchaseManager.productLoadDebugDetails {
                VStack(alignment: .leading, spacing: 10) {
                    Text("DEBUG")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.55))

                    Text(debugDetails)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.72))
                        .textSelection(.enabled)

                    Button("paywall.debug.resetPremium".localized) {
                        purchaseManager.debugResetPremiumData()
                        statusMessage = "paywall.debug.resetDone".localized
                    }
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(hex: "EBCF97"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
            }
        }
    }
    #endif

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
        formatter.locale = Locale(identifier: isArabic ? "ar" : "en")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        let activeProductID = entitlementStore.activeProductId ?? effectiveSelectedProductID
        let plan = SubscriptionProductIDs.displayName(for: activeProductID)
        return String(format: "paywall.status.currentPlan".localized, plan, formatter.string(from: expiresAt))
    }

    private func details(for tier: SubscriptionTier) -> PaywallPlanDetails {
        switch tier {
        case .max:
            return PaywallPlanDetails(
                title: "AiQo Max",
                eyebrow: copy(ar: "السرعة اليومية الذكية", en: "Fast everyday coaching"),
                summary: copy(
                    ar: "كل الأساسيات التي يحتاجها المستخدم يومياً: سرعة أعلى، تتبع كامل لنمط الحياة، Kitchen، Gym، والكابتن الأساسي.",
                    en: "Everything you need day to day: faster AI, full lifestyle tracking, Kitchen, Gym, and a focused basic Captain."
                ),
                features: [
                    PaywallFeature(icon: "bolt.fill", text: copy(ar: "مسار AI أسرع باستخدام نموذج سريع للاستجابة اليومية", en: "Faster AI routing with a speed-first model for everyday replies")),
                    PaywallFeature(icon: "figure.strengthtraining.traditional", text: copy(ar: "Gym وKitchen كاملين لبناء العادة والتغذية اليومية", en: "Full Gym and Kitchen support for training and daily nutrition")),
                    PaywallFeature(icon: "heart.text.square.fill", text: copy(ar: "تتبع كامل لنمط الحياة: النشاط، النوم، التحديات، ولوحة تقدم واضحة", en: "Full lifestyle tracking across activity, sleep, challenges, and a clear progress dashboard")),
                    PaywallFeature(icon: "person.crop.circle.badge.sparkles", text: copy(ar: "Captain الأساسي للمتابعة السريعة والتوجيه اليومي", en: "Basic Captain for quick check-ins and daily guidance"))
                ],
                badge: nil,
                icon: "bolt.heart.fill",
                tint: Color(hex: "264339"),
                secondaryTint: Color(hex: "B7E5D2"),
                glow: Color(hex: "5ECDB7"),
                glassStyle: .soft,
                tintIntensity: 0.18,
                isFeatured: false
            )
        case .pro:
            return PaywallPlanDetails(
                title: "AiQo Intelligence Pro",
                eyebrow: copy(ar: "الأقوى لكسر الأرقام والتحليل", en: "The full analytical stack"),
                summary: copy(
                    ar: "كل ما في AiQo Max وأكثر: ميزة القمم، ذاكرة ممتدة للكابتن، وذكاء اصطناعي تحليلي أعمق يقود التجربة بالكامل.",
                    en: "Everything in AiQo Max and more: Peaks, extended Captain memory, and deeper analytical AI for the complete AiQo experience."
                ),
                features: [
                    PaywallFeature(icon: "mountain.2.fill", text: copy(ar: "ميزة القمم (Peaks) لكسر الأرقام القياسية والتحديات الأسطورية", en: "Peaks for record-breaking legendary challenges")),
                    PaywallFeature(icon: "brain.head.profile", text: copy(ar: "ذاكرة ممتدة للكابتن لفهم تاريخك، أهدافك، وسياقك على مدى أطول", en: "Expanded Captain memory for longer-term context across your goals and history")),
                    PaywallFeature(icon: "point.3.connected.trianglepath.dotted", text: copy(ar: "ذكاء اصطناعي تحليلي أعمق باستخدام نموذج reasoning أقوى", en: "Deeper analytical AI powered by a stronger reasoning model")),
                    PaywallFeature(icon: "sparkles.rectangle.stack.fill", text: copy(ar: "كل مزايا AiQo Max مع كابتن أكثر فهماً وتخطيطاً", en: "All AiQo Max features plus a smarter, more strategic Captain"))
                ],
                badge: copy(ar: "الأكثر اختياراً", en: "Most chosen"),
                icon: "crown.fill",
                tint: Color(hex: "4A3E24"),
                secondaryTint: Color(hex: "EBCF97"),
                glow: Color(hex: "EBCF97"),
                glassStyle: .glass,
                tintIntensity: 0.16,
                isFeatured: true
            )
        case .none, .trial:
            return PaywallPlanDetails(
                title: "AiQo",
                eyebrow: "",
                summary: "",
                features: [],
                badge: nil,
                icon: "sparkles",
                tint: Color(hex: "1D2A30"),
                secondaryTint: Color(hex: "B7E5D2"),
                glow: Color(hex: "5ECDB7"),
                glassStyle: .soft,
                tintIntensity: 0.14,
                isFeatured: false
            )
        }
    }

    private func copy(ar: String, en: String) -> String {
        isArabic ? ar : en
    }

    // MARK: - Trial Context Banner

    @ViewBuilder
    private var contextBanner: some View {
        switch source {
        case .day6Preview:
            bannerText(isArabic ? "بعد يوم وراح تنتهي تجربتك" : "One day left in your trial")
        case .trialEnded:
            bannerText(isArabic ? "تجربتك انتهت — كمّل وية الكابتن" : "Your trial ended — keep going with Captain")
        default:
            EmptyView()
        }
    }

    private func bannerText(_ text: String) -> some View {
        Text(text)
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(red: 0.718, green: 0.898, blue: 0.824).opacity(0.4))
            )
            .padding(.horizontal)
    }
}

private struct PaywallPlanModel: Identifiable {
    let tier: SubscriptionTier
    let product: Product?
    let details: PaywallPlanDetails

    var id: String { productID }
    var productID: String { tier.productID }
    var priceText: String { product?.displayPrice ?? tier.monthlyPrice }
}

private struct PaywallPlanDetails {
    let title: String
    let eyebrow: String
    let summary: String
    let features: [PaywallFeature]
    let badge: String?
    let icon: String
    let tint: Color
    let secondaryTint: Color
    let glow: Color
    let glassStyle: PaywallGlassPanelStyle
    let tintIntensity: CGFloat
    let isFeatured: Bool

    var gradientColors: [Color] {
        [secondaryTint, tint.opacity(0.92)]
    }
}

private struct PaywallFeature: Identifiable {
    let id = UUID()
    let icon: String
    let text: String
}

private enum PaywallGlassPanelStyle {
    case glass
    case soft
}

private struct PaywallGlassPanelBackground: UIViewRepresentable {
    let style: PaywallGlassPanelStyle
    let tint: UIColor
    let intensity: CGFloat

    func makeUIView(context: Context) -> UIView {
        switch style {
        case .glass:
            let view = GlassCardView()
            view.isUserInteractionEnabled = false
            view.setTint(tint)
            return view
        case .soft:
            let view = SoftGlassCardView()
            view.isUserInteractionEnabled = false
            view.setTint(tint, intensity: intensity)
            return view
        }
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let glassView = uiView as? GlassCardView {
            glassView.setTint(tint)
        } else if let softGlassView = uiView as? SoftGlassCardView {
            softGlassView.setTint(tint, intensity: intensity)
        }
    }
}

#Preview {
    PaywallView()
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.locale, Locale(identifier: "ar"))
}
