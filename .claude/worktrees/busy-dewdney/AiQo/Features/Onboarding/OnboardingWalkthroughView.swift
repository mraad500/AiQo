import SwiftUI

/// شاشة شرح النقاط — تعرض بعد اختيار اللغة وقبل تسجيل الدخول
struct OnboardingWalkthroughView: View {
    let onComplete: () -> Void

    @State private var appeared = false

    private var isArabic: Bool {
        AppSettingsStore.shared.appLanguage == .arabic
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Full-screen design image as background
                Image("22")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .ignoresSafeArea()

                // Overlay text & buttons
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: 60)

                    // AiQo title
                    Text("AiQo")
                        .font(.aiqoDisplay(40))
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : -15)

                    Divider()
                        .padding(.horizontal, 60)
                        .padding(.top, 8)

                    Spacer()
                        .frame(height: 14)

                    // Subtitle
                    Text(isArabic
                         ? "تاريخك الصحي يتحوّل إلى مستوى حقيقي"
                         : "Your health history becomes a real level")
                        .font(.aiqoHeading(19))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .opacity(appeared ? 1 : 0)

                    Spacer()
                        .frame(height: 8)

                    // Section title
                    Text(isArabic
                         ? "كيف يُحسب مستواك؟"
                         : "How is your level calculated?")
                        .font(.aiqoHeading(18))
                        .foregroundStyle(Color(hex: "2AA88E"))
                        .opacity(appeared ? 1 : 0)

                    Spacer()
                        .frame(height: 20)

                    // Points explanation card
                    pointsCard
                        .padding(.horizontal, 32)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)

                    Spacer()
                        .frame(height: 20)

                    // Level progress indicator
                    levelProgressBar
                        .padding(.horizontal, 32)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 15)

                    Spacer()
                        .frame(height: 24)

                    // Motivational text
                    Text(isArabic
                         ? "إنت مو شخص يبدأ من صفر — إنت جاي وياك تاريخ."
                         : "You're not starting from zero — you come with history.")
                        .font(.aiqoBody(15))
                        .foregroundStyle(Color(hex: "1D7A65"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .opacity(appeared ? 1 : 0)

                    Spacer()

                    // Continue button
                    Button {
                        HapticEngine.selection()
                        AnalyticsService.shared.track(.onboardingCompleted)
                        onComplete()
                    } label: {
                        HStack(spacing: 10) {
                            if !isArabic {
                                Text("Continue")
                                    .font(.aiqoHeading(18))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 16, weight: .bold))
                            } else {
                                Image(systemName: "arrow.left")
                                    .font(.system(size: 16, weight: .bold))
                                Text("متابعة")
                                    .font(.aiqoHeading(18))
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "5ECDB7"), Color(hex: "2AA88E")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: Color(hex: "2AA88E").opacity(0.3), radius: 10, y: 5)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 32)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 15)

                    Spacer()
                        .frame(height: 12)

                    // Not now button
                    Button {
                        AnalyticsService.shared.track(.onboardingSkipped)
                        onComplete()
                    } label: {
                        Text(isArabic ? "ليس الآن" : "Not now")
                            .font(.aiqoBody(15))
                            .foregroundStyle(.primary.opacity(0.6))
                            .padding(.horizontal, 32)
                            .padding(.vertical, 12)
                            .background(
                                Capsule()
                                    .fill(AuthFlowTheme.sand.opacity(0.3))
                            )
                    }
                    .buttonStyle(.plain)
                    .opacity(appeared ? 1 : 0)

                    Spacer()
                        .frame(height: geo.safeAreaInsets.bottom + 30)
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.15)) {
                appeared = true
            }
            AnalyticsService.shared.track(.onboardingStepViewed(0))
        }
    }

    // MARK: - Points Card

    private var pointsCard: some View {
        AuthFlowCard {
            VStack(spacing: 12) {
                pointRow(
                    icon: "figure.walk",
                    iconColor: Color(hex: "2AA88E"),
                    points: isArabic ? "١ نقطة" : "1 pt",
                    description: isArabic ? "كل ١٠٠ خطوة" : "Every 100 steps"
                )

                Divider().opacity(0.3)

                pointRow(
                    icon: "drop.fill",
                    iconColor: Color(hex: "5ECDB7"),
                    points: isArabic ? "١ نقطة" : "1 pt",
                    description: isArabic ? "كل ١٠ سعرة" : "Every 10 calories"
                )

                Divider().opacity(0.3)

                pointRow(
                    icon: "moon.fill",
                    iconColor: Color(hex: "9ABFB0"),
                    points: isArabic ? "١٠ نقطة" : "10 pts",
                    description: isArabic ? "كل ساعة نوم" : "Every hour of sleep"
                )
            }
        }
    }

    private func pointRow(
        icon: String,
        iconColor: Color,
        points: String,
        description: String
    ) -> some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(iconColor)
            }

            // Description
            Text(description)
                .font(.aiqoBody(14))
                .foregroundStyle(.secondary)

            Spacer()

            Text("=")
                .font(.aiqoBody(14))
                .foregroundStyle(.tertiary)

            // Points badge
            Text(points)
                .font(.aiqoLabel(13))
                .foregroundStyle(Color(hex: "2AA88E"))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(hex: "2AA88E").opacity(0.1))
                )
        }
    }

    // MARK: - Level Progress Bar

    private var levelProgressBar: some View {
        HStack(spacing: 6) {
            Text(isArabic ? "١٠٠ نقطة" : "100 pts")
                .font(.aiqoCaption(12))
                .foregroundStyle(.secondary)

            Image(systemName: isArabic ? "arrow.left" : "arrow.right")
                .font(.system(size: 9))
                .foregroundStyle(AuthFlowTheme.mint.opacity(0.5))

            // Level badge
            Text(isArabic ? "مستوى ١" : "Level 1")
                .font(.aiqoLabel(14))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "2AA88E"), Color(hex: "5ECDB7")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )

            Image(systemName: isArabic ? "arrow.left" : "arrow.right")
                .font(.system(size: 9))
                .foregroundStyle(AuthFlowTheme.mint.opacity(0.5))

            Text(isArabic ? "٣٠٠ نقطة" : "300 pts")
                .font(.aiqoCaption(12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AuthFlowTheme.mint.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AuthFlowTheme.mint.opacity(0.15), lineWidth: 1)
                )
        )
    }
}

#Preview {
    OnboardingWalkthroughView {
        print("Done")
    }
}
