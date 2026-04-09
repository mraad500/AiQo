import SwiftUI

struct LanguageSelectionView: View {
    let onContinue: () -> Void

    @State private var selectedLanguage: AppLanguage = .arabic
    @State private var appeared = true

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

                // Overlaid controls — anchored from bottom
                VStack(spacing: 0) {
                    Spacer()

                    // Language picker card — compact with native segmented control
                    VStack(spacing: 12) {
                        Text(NSLocalizedString("lang.systemAr", comment: ""))
                            .font(.aiqoHeading(16))

                        Text(NSLocalizedString("lang.systemEn", comment: ""))
                            .font(.aiqoBody(13))
                            .foregroundStyle(.secondary)

                        Picker("", selection: $selectedLanguage) {
                            Text(NSLocalizedString("lang.arabic", comment: "")).tag(AppLanguage.arabic)
                            Text(NSLocalizedString("lang.english", comment: "")).tag(AppLanguage.english)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: selectedLanguage) { _, _ in
                            HapticEngine.selection()
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .fill(.ultraThinMaterial)

                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [.white.opacity(0.92), .white.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )

                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .stroke(.white.opacity(0.72), lineWidth: 1)
                        }
                    )
                    .shadow(color: AuthFlowTheme.cardShadow, radius: 18, x: 0, y: 10)
                    .shadow(color: .white.opacity(0.48), radius: 8, x: 0, y: -2)
                    .padding(.horizontal, 40)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)

                    Spacer()
                        .frame(height: 16)

                    // Continue button
                    Button {
                        HapticEngine.selection()
                        LocalizationManager.shared.setLanguage(selectedLanguage)
                        onContinue()
                    } label: {
                        VStack(spacing: 4) {
                            Text(NSLocalizedString("lang.explore", comment: ""))
                                .font(.aiqoHeading(18))
                                .foregroundStyle(.white)

                            Text(NSLocalizedString("lang.exploreSubtitle", comment: ""))
                                .font(.aiqoCaption(13))
                                .foregroundStyle(.white.opacity(0.7))
                                .tracking(1)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 72)
                        .background(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
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
                        .frame(height: geo.size.height * 0.10)
                }
            }
        }
        .ignoresSafeArea()
        .onAppear { }
    }

}
