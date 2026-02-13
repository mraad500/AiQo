import SwiftUI
import UIKit

enum AuthFlowTheme {
    static let darkBackground = Color(red: 0.03, green: 0.05, blue: 0.09)
    static let deepBlue = Color(red: 0.07, green: 0.13, blue: 0.22)
    static let mint = Color(red: 0.54, green: 0.92, blue: 0.86)
    static let beige = Color(red: 0.99, green: 0.87, blue: 0.66)
    static let gold = Color(red: 0.98, green: 0.83, blue: 0.56)

    static let cardTop = Color(red: 0.10, green: 0.17, blue: 0.29).opacity(0.94)
    static let cardBottom = Color(red: 0.05, green: 0.09, blue: 0.17).opacity(0.94)

    static let text = Color(red: 0.95, green: 0.98, blue: 1.00)
    static let subtext = Color(red: 0.76, green: 0.82, blue: 0.90)
}

extension Font {
    static func aiqoDisplay(_ size: CGFloat) -> Font {
        .custom("AvenirNext-Heavy", size: size)
    }

    static func aiqoHeading(_ size: CGFloat) -> Font {
        .custom("AvenirNext-DemiBold", size: size)
    }

    static func aiqoBody(_ size: CGFloat) -> Font {
        .custom("AvenirNext-Medium", size: size)
    }

    static func aiqoLabel(_ size: CGFloat) -> Font {
        .custom("AvenirNext-Bold", size: size)
    }
}

struct AuthFlowBackground: View {
    @State private var animateGlow = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    AuthFlowTheme.darkBackground,
                    AuthFlowTheme.deepBlue,
                    AuthFlowTheme.darkBackground
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(AuthFlowTheme.mint.opacity(0.24))
                .frame(width: 360, height: 360)
                .blur(radius: 90)
                .offset(x: animateGlow ? -170 : -40, y: animateGlow ? -280 : -160)

            Circle()
                .fill(AuthFlowTheme.gold.opacity(0.18))
                .frame(width: 320, height: 320)
                .blur(radius: 95)
                .offset(x: animateGlow ? 160 : 60, y: animateGlow ? 260 : 180)

            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 220, height: 220)
                .blur(radius: 110)
                .offset(x: animateGlow ? 30 : -70, y: animateGlow ? -30 : 120)

            VStack {
                Spacer()
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.clear, Color.black.opacity(0.38)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 240)
                    .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                animateGlow = true
            }
        }
    }
}

struct AuthFlowBrandHeader: View {
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("AiQo")
                    .font(.aiqoDisplay(44))
                    .foregroundStyle(AuthFlowTheme.text)

                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AuthFlowTheme.mint)
            }

            Text(subtitle.uppercased())
                .font(.aiqoLabel(11))
                .tracking(1.8)
                .foregroundStyle(AuthFlowTheme.subtext)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AuthFlowCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(22)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [AuthFlowTheme.cardTop, AuthFlowTheme.cardBottom],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                AuthFlowTheme.mint.opacity(0.55),
                                Color.white.opacity(0.14),
                                AuthFlowTheme.gold.opacity(0.50)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            )
            .shadow(color: Color.black.opacity(0.46), radius: 24, x: 0, y: 16)
    }
}

struct AuthFlowTextField: View {
    let title: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.aiqoLabel(12))
                .tracking(0.7)
                .foregroundStyle(AuthFlowTheme.subtext)

            TextField("", text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .keyboardType(keyboardType)
                .font(.aiqoHeading(17))
                .foregroundStyle(AuthFlowTheme.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
        }
    }
}

struct AuthFlowFieldPanel<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.aiqoLabel(12))
                .tracking(0.7)
                .foregroundStyle(AuthFlowTheme.subtext)

            content
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
        }
    }
}

struct AuthPrimaryButton: View {
    let title: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.aiqoHeading(18))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(Color.black.opacity(0.86))
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [AuthFlowTheme.gold, AuthFlowTheme.mint],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: AuthFlowTheme.mint.opacity(0.22), radius: 14, x: 0, y: 8)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
    }
}

struct AuthMetricRow: View {
    let symbol: String
    let title: String
    let value: String
    let points: Int

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(AuthFlowTheme.mint)
                .frame(width: 22)

            Text(title)
                .font(.aiqoHeading(14))
                .foregroundStyle(AuthFlowTheme.text)

            Spacer(minLength: 8)

            Text(value)
                .font(.aiqoBody(13))
                .foregroundStyle(AuthFlowTheme.subtext)

            Text("+\(points)")
                .font(.aiqoLabel(13))
                .foregroundStyle(Color.black.opacity(0.88))
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(
                    Capsule(style: .continuous)
                        .fill(AuthFlowTheme.mint)
                )
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color.white.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

extension UIApplication {
    static func activeSceneDelegate() -> SceneDelegate? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let activeScene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        return activeScene?.delegate as? SceneDelegate
    }
}
