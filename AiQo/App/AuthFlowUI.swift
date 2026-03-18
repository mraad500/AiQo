import SwiftUI
import UIKit

// MARK: - Theme

enum AuthFlowTheme {
    // Brand colors
    static let mint = Color(hex: "B7E5D2")
    static let sand = Color(hex: "EBCF97")

    // Background gradient
    static let bgTop = Color(hex: "FDFCFA")
    static let bgMid = Color(hex: "F7F2EA")
    static let bgBottom = Color(hex: "F2EDE4")

    // Text
    static let text = Color.primary
    static let subtext = Color.secondary

    // Card
    static let cardFill = Color.white.opacity(0.65)

    // Field
    static let fieldBorder = Color.black.opacity(0.08)
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
                colors: [AuthFlowTheme.bgTop, AuthFlowTheme.bgMid, AuthFlowTheme.bgBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Decorative background circles for depth
            Circle()
                .fill(Color(hex: "B7E5D2").opacity(0.08))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: -100, y: -200)

            Circle()
                .fill(Color(hex: "EBCF97").opacity(0.06))
                .frame(width: 250, height: 250)
                .blur(radius: 50)
                .offset(x: 120, y: 300)
        }
    }
}

// MARK: - Brand Header (small, top-right for inner screens)

struct AuthFlowBrandHeader: View {
    var subtitle: String? = nil

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .foregroundColor(AuthFlowTheme.mint)
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
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(.ultraThinMaterial)

                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(.white.opacity(0.65))

                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.8), .white.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
            .shadow(color: .black.opacity(0.06), radius: 20, x: 0, y: 8)
            .shadow(color: .black.opacity(0.02), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Glassmorphism Card Modifier (for inline use)

struct GlassmorphismCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 28

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)

                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.white.opacity(0.65))

                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.8), .white.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
            .shadow(color: .black.opacity(0.06), radius: 20, x: 0, y: 8)
            .shadow(color: .black.opacity(0.02), radius: 4, x: 0, y: 2)
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 28) -> some View {
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
                    .foregroundColor(.secondary)
            }
            TextField(title, text: $text)
                .keyboardType(keyboardType)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
            if let prefix = prefix {
                Text(prefix)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
            }
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundColor(AuthFlowTheme.sand)
                    .font(.system(size: 16))
            }
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
                .foregroundColor(.secondary)
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
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AuthFlowTheme.mint)
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
                .foregroundColor(.primary.opacity(0.6))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(AuthFlowTheme.sand.opacity(0.3))
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
                .foregroundColor(color)
                .frame(width: 80, alignment: .leading)

            Text(value)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)

            Spacer()

            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                Image(systemName: symbol)
                    .foregroundColor(color)
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
                .foregroundColor(isSelected ? .white : .primary)
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
    @State private var rotation: Double = 0
    @State private var appeared = false
    @State private var progressText = "نقرأ بياناتك..."

    private let progressMessages = [
        "نقرأ بياناتك...",
        "نحسب خطواتك...",
        "نحلّل نومك...",
        "نجمع سعراتك...",
        "نحسب المسافة...",
        "نحدد مستواك..."
    ]

    var body: some View {
        VStack(spacing: 24) {
            // Custom spinner
            ZStack {
                Circle()
                    .stroke(Color(hex: "EBCF97").opacity(0.2), lineWidth: 3)
                    .frame(width: 64, height: 64)

                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(
                        Color(hex: "B7E5D2"),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 64, height: 64)
                    .rotationEffect(.degrees(rotation))

                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: "B7E5D2"))
            }

            VStack(spacing: 8) {
                Text("جاري التحليل")
                    .font(.system(size: 24, weight: .black, design: .rounded))

                Text(progressText)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .animation(.easeInOut(duration: 0.3), value: progressText)
            }
        }
        .padding(40)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.white.opacity(0.65))
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.8), .white.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
        .shadow(color: .black.opacity(0.06), radius: 20, y: 8)
        .shadow(color: .black.opacity(0.02), radius: 4, y: 2)
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.9)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                appeared = true
            }
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            startProgressMessages()
        }
    }

    private func startProgressMessages() {
        for (index, message) in progressMessages.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 2.0) {
                withAnimation { progressText = message }
            }
        }
    }
}
