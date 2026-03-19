import SwiftUI

/// شاشات الترحيب — تعرض مرة واحدة فقط قبل تسجيل الدخول
struct OnboardingWalkthroughView: View {
    @State private var currentPage = 0
    let onComplete: () -> Void

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "figure.run",
            titleKey: "onboarding.page1.title",
            subtitleKey: "onboarding.page1.subtitle",
            gradient: [Color.blue.opacity(0.3), Color.purple.opacity(0.2)]
        ),
        OnboardingPage(
            icon: "wand.and.stars",
            titleKey: "onboarding.page2.title",
            subtitleKey: "onboarding.page2.subtitle",
            gradient: [Color.purple.opacity(0.3), Color.pink.opacity(0.2)]
        ),
        OnboardingPage(
            icon: "person.3.fill",
            titleKey: "onboarding.page3.title",
            subtitleKey: "onboarding.page3.subtitle",
            gradient: [Color.orange.opacity(0.3), Color.red.opacity(0.2)]
        ),
        OnboardingPage(
            icon: "sparkles",
            titleKey: "onboarding.page4.title",
            subtitleKey: "onboarding.page4.subtitle",
            gradient: [Color.green.opacity(0.3), Color.teal.opacity(0.2)]
        )
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    ForEach(pages.indices, id: \.self) { index in
                        pageView(pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentPage)

                bottomSection
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
            }
        }
        .onAppear {
            AnalyticsService.shared.track(.onboardingStepViewed(0))
        }
        .onChange(of: currentPage) { _, newValue in
            AnalyticsService.shared.track(.onboardingStepViewed(newValue))
        }
    }

    // MARK: - Page View

    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: page.gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 160, height: 160)
                    .blur(radius: 30)

                Image(systemName: page.icon)
                    .font(.system(size: 72, weight: .light))
                    .foregroundStyle(.white.opacity(0.9))
                    .symbolEffect(.pulse, options: .repeating)
            }

            VStack(spacing: 14) {
                Text(page.titleKey.localized)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(page.subtitleKey.localized)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 32)
            }

            Spacer()
            Spacer()
        }
    }

    // MARK: - Bottom Section

    private var bottomSection: some View {
        VStack(spacing: 20) {
            // Page indicators
            HStack(spacing: 8) {
                ForEach(pages.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == currentPage ? Color.white : Color.white.opacity(0.25))
                        .frame(width: index == currentPage ? 24 : 8, height: 8)
                        .animation(.spring(response: 0.3), value: currentPage)
                }
            }

            // Buttons
            HStack(spacing: 16) {
                if currentPage > 0 {
                    Button {
                        withAnimation { currentPage -= 1 }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 56, height: 56)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.08))
                            )
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    if currentPage < pages.count - 1 {
                        withAnimation { currentPage += 1 }
                    } else {
                        AnalyticsService.shared.track(.onboardingCompleted)
                        onComplete()
                    }
                } label: {
                    Text(currentPage < pages.count - 1
                         ? "onboarding.next".localized
                         : "onboarding.getStarted".localized)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .fill(Color.white.opacity(0.92))
                        )
                }
                .buttonStyle(.plain)
            }

            if currentPage < pages.count - 1 {
                Button {
                    AnalyticsService.shared.track(.onboardingSkipped)
                    onComplete()
                } label: {
                    Text("onboarding.skip".localized)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Model

private struct OnboardingPage {
    let icon: String
    let titleKey: String
    let subtitleKey: String
    let gradient: [Color]
}

#Preview {
    OnboardingWalkthroughView {
        print("Done")
    }
}
