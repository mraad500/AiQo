import SwiftUI
import UIKit

// MARK: - Theme

enum AuthFlowTheme {
    static let mint = Color(hex: "B7E5D2")
    static let sand = Color(hex: "EBCF97")

    static let bgTop = Color(hex: "FAFAF8")
    static let bgBottom = Color(hex: "F5F0E8")
    static let fieldBorder = Color.black.opacity(0.08)
    static let cardShadow = Color.black.opacity(0.04)
}

// MARK: - Fonts (system rounded Arabic-first)

extension Font {
    static func aiqoDisplay(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black, design: .rounded)
    }

    static func aiqoHeading(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    static func aiqoBody(_ size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
    }

    static func aiqoLabel(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    static func aiqoCaption(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .rounded)
    }
}

// MARK: - Background

struct AuthFlowBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AuthFlowTheme.bgTop, Color.white.opacity(0.96), AuthFlowTheme.bgBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            Circle()
                .fill(AuthFlowTheme.mint.opacity(0.18))
                .frame(width: 320, height: 320)
                .blur(radius: 100)
                .offset(x: 130, y: -220)

            Circle()
                .fill(AuthFlowTheme.sand.opacity(0.16))
                .frame(width: 280, height: 280)
                .blur(radius: 90)
                .offset(x: -120, y: 260)

            Circle()
                .fill(Color.white.opacity(0.7))
                .frame(width: 220, height: 220)
                .blur(radius: 70)
                .offset(x: 0, y: -30)
        }
    }
}

// MARK: - Brand Header (small, top-right for inner screens)

struct AuthFlowBrandHeader: View {
    var subtitle: String? = nil

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .foregroundStyle(AuthFlowTheme.mint)
                .font(.system(size: 16, weight: .medium, design: .rounded))
            Text("AiQo")
                .font(.aiqoDisplay(24))
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }
}

// MARK: - Glassmorphism Card

struct AuthFlowCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(28)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.ultraThinMaterial)

                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.92), .white.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(.white.opacity(0.72), lineWidth: 1)
                }
            )
            .shadow(color: AuthFlowTheme.cardShadow, radius: 18, x: 0, y: 10)
            .shadow(color: .white.opacity(0.48), radius: 8, x: 0, y: -2)
    }
}

// MARK: - Glassmorphism Card Modifier (for inline use)

struct GlassmorphismCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 24

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)

                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.92), .white.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(.white.opacity(0.72), lineWidth: 1)
                }
            )
            .shadow(color: AuthFlowTheme.cardShadow, radius: 18, x: 0, y: 10)
            .shadow(color: .white.opacity(0.48), radius: 8, x: 0, y: -2)
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 24) -> some View {
        modifier(GlassmorphismCardModifier(cornerRadius: cornerRadius))
    }
}

// MARK: - Text Field

struct AuthFlowTextField: View {
    let title: String
    @Binding var text: String
    var icon: String? = nil
    var prefix: String? = nil
    var suffix: String? = nil
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        HStack(spacing: 12) {
            if let suffix = suffix {
                Text(suffix)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            TextField(title, text: $text)
                .keyboardType(keyboardType)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
            if let prefix = prefix {
                Text(prefix)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundStyle(AuthFlowTheme.sand)
                    .font(.system(size: 16))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.95), .white.opacity(0.88)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

// MARK: - Field Panel

struct AuthFlowFieldPanel<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        HStack {
            content
            Spacer()
            Text(title)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

// MARK: - Primary Button

struct AuthPrimaryButton: View {
    let title: String
    let isEnabled: Bool
    let action: () -> Void
    var icon: String? = "arrow.left"

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                }
                Text(title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [AuthFlowTheme.mint, AuthFlowTheme.mint.opacity(0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
    }
}

// MARK: - Secondary Button

struct AuthSecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(.primary.opacity(0.6))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(AuthFlowTheme.sand.opacity(0.22))
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Metric Row

struct AuthMetricRow: View {
    let symbol: String
    let title: String
    let value: String
    let points: Int
    var color: Color = AuthFlowTheme.mint

    var body: some View {
        HStack {
            Text("+\(points.formatted())")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .frame(width: 80, alignment: .leading)

            Text(value)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            Spacer()

            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                Image(systemName: symbol)
                    .foregroundStyle(color)
                    .font(.system(size: 14))
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.08))
        )
    }
}

// MARK: - Gender Button

struct GenderButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? AuthFlowTheme.mint : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Analysis Loading View

struct AnalysisLoadingView: View {
    let title: String
    let subtitle: String
    @State private var rotation: Double = 0
    @State private var appeared = false
    @State private var barOffset: CGFloat = -100

    init(
        title: String = "جاري التحليل",
        subtitle: String = "نحضّر مستواك اعتماداً على Apple Health"
    ) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(spacing: 26) {
            ZStack {
                Circle()
                    .fill(AuthFlowTheme.mint.opacity(0.12))
                    .frame(width: 86, height: 86)

                Circle()
                    .stroke(AuthFlowTheme.mint.opacity(0.12), lineWidth: 8)
                    .frame(width: 74, height: 74)

                Circle()
                    .trim(from: 0.18, to: 0.92)
                    .stroke(
                        LinearGradient(
                            colors: [AuthFlowTheme.mint, AuthFlowTheme.sand],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .frame(width: 74, height: 74)
                    .rotationEffect(.degrees(rotation))

                Image(systemName: "sparkles")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(AuthFlowTheme.mint)
            }

            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 28, weight: .black, design: .rounded))

                Text(subtitle)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            RoundedRectangle(cornerRadius: 999)
                .fill(Color.white.opacity(0.58))
                .frame(width: 220, height: 10)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 999)
                        .fill(
                            LinearGradient(
                                colors: [AuthFlowTheme.mint, AuthFlowTheme.sand],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 120, height: 10)
                        .offset(x: barOffset)
                }
                .clipped()
        }
        .padding(40)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.94), .white.opacity(0.82)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(.white.opacity(0.72), lineWidth: 1)
            }
        )
        .shadow(color: AuthFlowTheme.cardShadow, radius: 18, y: 10)
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.9)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                appeared = true
            }
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
                barOffset = 100
            }
        }
    }
}
