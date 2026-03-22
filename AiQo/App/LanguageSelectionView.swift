import SwiftUI

struct LanguageSelectionView: View {
    let onContinue: () -> Void

    @State private var selectedLanguage: AppLanguage = .arabic
    @State private var appeared = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Full-screen design image as background
                Image("11")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .ignoresSafeArea()

                // Overlaid controls
                VStack(spacing: 0) {
                    Spacer()

                    // Language picker card — positioned over "System language" area
                    AuthFlowCard {
                        VStack(spacing: 16) {
                            Text("لغة النظام")
                                .font(.aiqoHeading(18))

                            Text("System language")
                                .font(.aiqoBody(14))
                                .foregroundStyle(.secondary)

                            // Segmented tabs
                            HStack(spacing: 0) {
                                languageTab(.arabic, title: "عربي")
                                languageTab(.english, title: "English")
                            }
                            .padding(4)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.black.opacity(0.05))
                            )
                        }
                    }
                    .padding(.horizontal, 32)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)

                    Spacer()
                        .frame(height: 28)

                    // Continue button
                    Button {
                        HapticEngine.selection()
                        LocalizationManager.shared.setLanguage(selectedLanguage)
                        onContinue()
                    } label: {
                        VStack(spacing: 4) {
                            Text(selectedLanguage == .arabic ? "استكشف مستواك الحقيقي" : "Explore your real level")
                                .font(.aiqoHeading(18))
                                .foregroundStyle(.white)

                            Text(selectedLanguage == .arabic ? "EXPLORE YOUR REAL LEVEL" : "استكشف مستواك الحقيقي")
                                .font(.aiqoCaption(13))
                                .foregroundStyle(.white.opacity(0.7))
                                .tracking(1)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 72)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "5ECDB7"), Color(hex: "2AA88E")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: Color(hex: "2AA88E").opacity(0.35), radius: 12, y: 6)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 32)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 15)

                    Spacer()
                        .frame(height: geo.safeAreaInsets.bottom + 40)
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.2)) {
                appeared = true
            }
        }
    }

    // MARK: - Language Tab

    @ViewBuilder
    private func languageTab(_ language: AppLanguage, title: String) -> some View {
        let isSelected = selectedLanguage == language

        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                selectedLanguage = language
            }
            HapticEngine.selection()
        } label: {
            Text(title)
                .font(.aiqoLabel(16))
                .foregroundStyle(isSelected ? .white : .primary.opacity(0.6))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    Group {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [AuthFlowTheme.mint, AuthFlowTheme.mint.opacity(0.85)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: AuthFlowTheme.mint.opacity(0.3), radius: 6, y: 3)
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }
}
