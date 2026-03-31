import StoreKit
import SwiftUI

struct PremiumPaywallView: View {
    @ObservedObject private var trialManager = FreeTrialManager.shared
    @Environment(\.dismiss) private var dismiss

    var onUnlocked: (() -> Void)? = nil

    @State private var selectedTier: SubscriptionTier = .pro
    @State private var isLoading = false
    @State private var products: [Product] = []
    @State private var statusMessage: String?

    private let mint = Color(hex: "5ECDB7")
    private let sand = Color(hex: "EBCF97")

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                headerSection

                // Plan cards
                VStack(spacing: 14) {
                    planCard(tier: .core, features: [
                        "الكابتن حمودي — مدربك الشخصي",
                        "التمارين والمطبخ كاملة",
                        "My Vibe — موسيقى تناسب طاقتك",
                        "تحديات يومية وإشعارات ذكية"
                    ])

                    planCard(tier: .pro, features: [
                        "كل ميزات Core",
                        "قمم — اكسر أرقام قياسية عالمية",
                        "خطة تمرين أسبوعية بالذكاء الاصطناعي",
                        "تقييم HRR لقلبك"
                    ], isMostPopular: true)

                    planCard(tier: .intelligence, features: [
                        "كل ميزات Pro",
                        "ذاكرة الكابتن الممتدة — 500 ذكرى",
                        "نموذج Gemini Pro أقوى وأذكى",
                        "تحليل متقدم لأدائك"
                    ])
                }

                ctaButton

                footerSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(AiQoTheme.Colors.primaryBackground.ignoresSafeArea())
        .environment(\.layoutDirection, .rightToLeft)
        .task {
            AnalyticsService.shared.track(.paywallViewed)
            await loadProducts()
        }
        .onChange(of: EntitlementStore.shared.currentTier) {
            guard EntitlementStore.shared.currentTier != .none else { return }
            onUnlocked?()
            dismiss()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 10) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(mint)

            Text("اختر خطتك")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(AiQoTheme.Colors.textPrimary)

            Text("أسبوع مجاني — بدون رسوم")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(AiQoTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - Plan Card

    private func planCard(tier: SubscriptionTier, features: [String], isMostPopular: Bool = false) -> some View {
        let isSelected = selectedTier == tier
        let storePrice = products.first(where: { $0.id == tier.productID })?.displayPrice ?? tier.monthlyPrice

        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                selectedTier = tier
            }
        } label: {
            VStack(alignment: .trailing, spacing: 12) {
                // Header row
                HStack {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(mint)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 8) {
                            if isMostPopular {
                                Text("الأكثر شعبية")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule().fill(mint)
                                    )
                            }

                            Text(tier.arabicDisplayName)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(AiQoTheme.Colors.textPrimary)
                        }

                        HStack(spacing: 4) {
                            Text("بالشهر")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(AiQoTheme.Colors.textSecondary)

                            Text(storePrice)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(AiQoTheme.Colors.textPrimary)
                        }
                    }
                }

                // Features
                VStack(alignment: .trailing, spacing: 6) {
                    ForEach(features, id: \.self) { feature in
                        HStack(spacing: 6) {
                            Text(feature)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(AiQoTheme.Colors.textSecondary)
                                .multilineTextAlignment(.trailing)

                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(mint.opacity(0.8))
                        }
                    }
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(
                                isSelected ? mint : AiQoTheme.Colors.border,
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(tier.arabicDisplayName) — \(storePrice) بالشهر")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - CTA

    private var ctaButton: some View {
        Button {
            guard !isLoading else { return }
            purchaseSelectedPlan()
        } label: {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("ابدأ أسبوعك المجاني")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [mint, mint.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isLoading || selectedTier == .none)
        .opacity(selectedTier == .none ? 0.5 : 1)
        .accessibilityLabel("ابدأ التجربة المجانية")
        .accessibilityAddTraits(.isButton)

        .overlay(alignment: .bottom) {
            if let statusMessage {
                Text(statusMessage)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(AiQoTheme.Colors.textSecondary)
                    .padding(.top, 8)
                    .offset(y: 24)
            }
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 12) {
            Button {
                restorePurchases()
            } label: {
                Text("استعادة المشتريات")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(AiQoTheme.Colors.textSecondary)
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
            .accessibilityAddTraits(.isButton)

            Text("يتجدد تلقائياً — يمكن الإلغاء في أي وقت")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(AiQoTheme.Colors.textSecondary.opacity(0.7))
                .multilineTextAlignment(.center)

            LegalLinksView()
        }
        .padding(.top, 8)
    }

    // MARK: - Actions

    private func loadProducts() async {
        let loaded = await PurchaseManager.shared.loadProducts()
        products = loaded
    }

    private func purchaseSelectedPlan() {
        guard let product = products.first(where: { $0.id == selectedTier.productID }) else {
            statusMessage = "تعذر تحميل الباقة. حاول مرة ثانية."
            return
        }

        isLoading = true
        Task {
            let outcome = await PurchaseManager.shared.purchase(product: product)
            isLoading = false

            switch outcome {
            case .success:
                statusMessage = nil
            case .pending:
                statusMessage = "الطلب قيد المعالجة"
            case .cancelled:
                statusMessage = nil
            case .failed(let message):
                statusMessage = message
            }
        }
    }

    private func restorePurchases() {
        isLoading = true
        Task {
            let outcome = await PurchaseManager.shared.restorePurchases()
            isLoading = false

            switch outcome {
            case .success:
                statusMessage = "تم استعادة المشتريات"
            case .failed(let message):
                statusMessage = message
            default:
                break
            }
        }
    }
}

#Preview {
    PremiumPaywallView()
        .environment(\.layoutDirection, .rightToLeft)
}
