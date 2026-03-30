import SwiftUI

// MARK: - Color Tokens

private extension Color {
    static let fiPrimaryBackground = Color(hex: "F5F7FB")
    static let fiTextPrimary       = Color(hex: "0F1721")
    static let fiTextSecondary     = Color(hex: "5F6F80")
    static let fiAccent            = Color(hex: "C6EFDB")
    static let fiBrandMint         = Color(hex: "C6EFDB")
    static let fiBrandSand         = Color(hex: "F7D7A7")
    static let fiDotInactive       = Color(hex: "EEF2F7")
    static let fiCtaLeading        = Color(hex: "C6EFDB")
    static let fiCtaTrailing       = Color(hex: "F7D7A7")
}

// MARK: - Main View

struct FeatureIntroView: View {
    let onComplete: () -> Void

    @State private var currentPage = 0
    @State private var showPage0   = false
    @State private var showPage1   = false
    @State private var showPage2   = false
    @State private var didComplete = false

    @AppStorage("appLanguage") private var appLanguage: String = "ar"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isArabic: Bool { appLanguage == "ar" }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // ── Background ───────────────────────────────────────────
                Color.fiPrimaryBackground.ignoresSafeArea()
                RadialGradient(
                    colors: [Color.fiBrandMint.opacity(0.14), .clear],
                    center: .init(x: 0.5, y: 1.1),
                    startRadius: 0,
                    endRadius: geo.size.height * 0.75
                )
                .ignoresSafeArea()

                // ── Content ──────────────────────────────────────────────
                VStack(spacing: 0) {
                    TabView(selection: $currentPage) {
                        FeatureIntroPage1(show: showPage0, isArabic: isArabic, geo: geo)
                            .tag(0)
                        FeatureIntroPage2(show: showPage1, isArabic: isArabic, geo: geo)
                            .tag(1)
                        FeatureIntroPage3(show: showPage2, isArabic: isArabic, geo: geo)
                            .tag(2)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .sensoryFeedback(.selection, trigger: currentPage)

                    bottomNav(geo: geo)
                        .padding(.horizontal, 24)
                        .padding(.bottom, geo.safeAreaInsets.bottom + 12)
                }
            }
        }
        .environment(\.layoutDirection, isArabic ? .rightToLeft : .leftToRight)
        .ignoresSafeArea(edges: .bottom)
        .onAppear { triggerAnimation(for: 0) }
        .onChange(of: currentPage) { _, newPage in triggerAnimation(for: newPage) }
    }

    // MARK: - Bottom Navigation

    private func bottomNav(geo: GeometryProxy) -> some View {
        VStack(spacing: 14) {
            // Dots
            HStack(spacing: 8) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(currentPage == index ? Color.fiAccent : Color.fiDotInactive)
                        .frame(
                            width:  currentPage == index ? 10 : 7,
                            height: currentPage == index ? 10 : 7
                        )
                        .animation(
                            reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7),
                            value: currentPage
                        )
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                String(format: NSLocalizedString("featureIntro.pageOf", comment: ""), currentPage + 1)
            )

            // CTA Button
            Button {
                if currentPage < 2 {
                    withAnimation(reduceMotion ? .none : .spring(response: 0.35, dampingFraction: 0.8)) {
                        currentPage += 1
                    }
                } else {
                    didComplete = true
                    onComplete()
                }
            } label: {
                Text(ctaTitle)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(
                        LinearGradient(
                            colors: [.fiCtaLeading, .fiCtaTrailing],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    )
                    .shadow(color: Color.fiCtaLeading.opacity(0.35), radius: 12, y: 6)
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.impact(weight: .light), trigger: didComplete)

            // Skip
            if currentPage < 2 {
                Button { onComplete() } label: {
                    Text(NSLocalizedString("featureIntro.skip", comment: ""))
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Color.fiTextSecondary)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85), value: currentPage)
    }

    private var ctaTitle: String {
        guard currentPage < 2 else {
            return NSLocalizedString("featureIntro.startJourney", comment: "")
        }
        return NSLocalizedString("featureIntro.next", comment: "")
    }

    // MARK: - Animation Trigger

    private func triggerAnimation(for page: Int) {
        // First reset all flags so animations re-run when revisiting a page
        let wasShowing0 = showPage0
        let wasShowing1 = showPage1
        let wasShowing2 = showPage2

        if wasShowing0 || wasShowing1 || wasShowing2 {
            showPage0 = false
            showPage1 = false
            showPage2 = false
        }

        let delay: Double = (wasShowing0 || wasShowing1 || wasShowing2) ? 0.05 : 0.0

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(reduceMotion ? .none : .spring(response: 0.55, dampingFraction: 0.82)) {
                switch page {
                case 0: showPage0 = true
                case 1: showPage1 = true
                case 2: showPage2 = true
                default: break
                }
            }
        }
    }
}

// MARK: - Page 1: Captain Hamoudi

private struct FeatureIntroPage1: View {
    let show: Bool
    let isArabic: Bool
    let geo: GeometryProxy
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            // ── Hero: Captain Image ───────────────────────────────────
            ZStack(alignment: .bottom) {
                // Glow behind character
                RadialGradient(
                    colors: [Color.fiBrandMint.opacity(0.30), .clear],
                    center: .center,
                    startRadius: 10,
                    endRadius: 130
                )
                .frame(width: 260, height: 180)
                .offset(y: 20)
                .blur(radius: 10)

                Image("Hammoudi5")
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: geo.size.height * 0.50)
                    .shadow(color: .black.opacity(0.09), radius: 30, x: 0, y: 15)
                    .accessibilityLabel(NSLocalizedString("featureIntro.captainHamoudi", comment: ""))
                    .opacity(show ? 1 : 0)
                    .offset(y: show ? 0 : (reduceMotion ? 0 : 34))
                    .scaleEffect(show ? 1 : (reduceMotion ? 1 : 0.88))
                    .animation(
                        reduceMotion ? nil : .spring(response: 0.62, dampingFraction: 0.80).delay(0.12),
                        value: show
                    )
            }
            .frame(height: geo.size.height * 0.52)

            // ── Card ─────────────────────────────────────────────────
            FeatureIntroCard(
                title: NSLocalizedString("featureIntro.captainHamoudi", comment: ""),
                subtitle: NSLocalizedString("featureIntro.captainSubtitle", comment: "")
            )
            .padding(.horizontal, 24)
            .opacity(show ? 1 : 0)
            .offset(y: show ? 0 : (reduceMotion ? 0 : 22))
            .animation(
                reduceMotion ? nil : .spring(response: 0.52, dampingFraction: 0.85).delay(0.32),
                value: show
            )

            Spacer()
        }
    }
}

// MARK: - Page 2: Workouts, Challenges & Peaks

private struct FeatureIntroPage2: View {
    let show: Bool
    let isArabic: Bool
    let geo: GeometryProxy
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            // ── Hero: Triangle Icon Composition ──────────────────────
            workoutsComposition
                .frame(height: geo.size.height * 0.48)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(NSLocalizedString("featureIntro.workoutsAccessibility", comment: ""))

            // ── Card ─────────────────────────────────────────────────
            FeatureIntroCard(
                title: NSLocalizedString("featureIntro.workoutsTitle", comment: ""),
                subtitle: NSLocalizedString("featureIntro.workoutsSubtitle", comment: "")
            )
            .padding(.horizontal, 24)
            .opacity(show ? 1 : 0)
            .offset(y: show ? 0 : (reduceMotion ? 0 : 22))
            .animation(
                reduceMotion ? nil : .spring(response: 0.52, dampingFraction: 0.85).delay(0.48),
                value: show
            )

            Spacer()
        }
    }

    private var workoutsComposition: some View {
        VStack(spacing: 18) {
            Spacer()

            // Top: Trophy
            FeatureIntroIconCircle(
                symbol: "trophy.fill",
                size: 120,
                iconSize: 46,
                background: Color.fiBrandSand.opacity(0.60),
                delay: 0.08,
                show: show
            )

            // Bottom row: Flame + Run
            HStack(spacing: 32) {
                FeatureIntroIconCircle(
                    symbol: "flame.fill",
                    size: 100,
                    iconSize: 40,
                    background: Color.fiBrandMint.opacity(0.60),
                    delay: 0.22,
                    show: show
                )
                FeatureIntroIconCircle(
                    symbol: "figure.run",
                    size: 100,
                    iconSize: 40,
                    background: Color.fiBrandMint.opacity(0.60),
                    delay: 0.38,
                    show: show
                )
            }

            Spacer()
        }
    }
}

// MARK: - Page 3: Alchemy Kitchen

private struct FeatureIntroPage3: View {
    let show: Bool
    let isArabic: Bool
    let geo: GeometryProxy
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            // ── Hero: Triangle Icon Composition ──────────────────────
            kitchenComposition
                .frame(height: geo.size.height * 0.48)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(NSLocalizedString("featureIntro.kitchenAccessibility", comment: ""))

            // ── Card ─────────────────────────────────────────────────
            FeatureIntroCard(
                title: NSLocalizedString("featureIntro.kitchenTitle", comment: ""),
                subtitle: NSLocalizedString("featureIntro.kitchenSubtitle", comment: "")
            )
            .padding(.horizontal, 24)
            .opacity(show ? 1 : 0)
            .offset(y: show ? 0 : (reduceMotion ? 0 : 22))
            .animation(
                reduceMotion ? nil : .spring(response: 0.52, dampingFraction: 0.85).delay(0.48),
                value: show
            )

            Spacer()
        }
    }

    private var kitchenComposition: some View {
        VStack(spacing: 18) {
            Spacer()

            // Top: Camera
            FeatureIntroIconCircle(
                symbol: "camera.fill",
                size: 120,
                iconSize: 46,
                background: Color.fiBrandSand.opacity(0.60),
                delay: 0.08,
                show: show
            )

            // Bottom row: Leaf + Fork & Knife
            HStack(spacing: 32) {
                FeatureIntroIconCircle(
                    symbol: "leaf.fill",
                    size: 100,
                    iconSize: 40,
                    background: Color.fiBrandMint.opacity(0.60),
                    delay: 0.22,
                    show: show
                )
                FeatureIntroIconCircle(
                    symbol: "fork.knife",
                    size: 100,
                    iconSize: 40,
                    background: Color.fiBrandMint.opacity(0.60),
                    delay: 0.38,
                    show: show
                )
            }

            Spacer()
        }
    }
}

// MARK: - Reusable: Icon Circle

private struct FeatureIntroIconCircle: View {
    let symbol: String
    let size: CGFloat
    let iconSize: CGFloat
    let background: Color
    let delay: Double
    let show: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .fill(background)
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.06), radius: 14, x: 0, y: 7)

            Image(systemName: symbol)
                .font(.system(size: iconSize, weight: .medium))
                .foregroundStyle(Color.fiTextPrimary)
        }
        .opacity(show ? 1 : 0)
        .scaleEffect(show ? 1 : (reduceMotion ? 1 : 0.65))
        .animation(
            reduceMotion ? nil : .spring(response: 0.50, dampingFraction: 0.72).delay(delay),
            value: show
        )
    }
}

// MARK: - Reusable: Glassmorphism Card

private struct FeatureIntroCard: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(Color.fiTextPrimary)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            Text(subtitle)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Color.fiTextSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 26)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.90), .white.opacity(0.78)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.20), lineWidth: 1)
            }
        )
        .shadow(color: .black.opacity(0.06), radius: 16, x: 0, y: 7)
    }
}
