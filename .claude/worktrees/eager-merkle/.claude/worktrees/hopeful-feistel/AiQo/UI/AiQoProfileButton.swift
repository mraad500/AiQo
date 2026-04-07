import SwiftUI

enum AiQoProfileButtonLayout {
    static let visualDiameter: CGFloat = 65
    static let hitTargetDiameter: CGFloat = 65
    static let symbolPointSize: CGFloat = 30
    static let reservedLaneWidth: CGFloat = 72
    static let shadowRadius: CGFloat = 16
    static let shadowYOffset: CGFloat = 7
}

struct AiQoProfileButton: View {
    var action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var feedbackTrigger = 0

    private var iconTint: Color {
        colorScheme == .dark
        ? Color.white.opacity(0.82)
        : Color.black.opacity(0.48)
    }

    private var borderTint: Color {
        colorScheme == .dark
        ? Color.white.opacity(0.12)
        : Color.white.opacity(0.62)
    }

    private var shadowTint: Color {
        colorScheme == .dark
        ? Color.black.opacity(0.18)
        : Color.black.opacity(0.06)
    }

    var body: some View {
        Button {
            feedbackTrigger += 1
            action()
        } label: {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.08 : 0.70),
                                Color.aiqoMint.opacity(colorScheme == .dark ? 0.06 : 0.12),
                                Color.aiqoSand.opacity(colorScheme == .dark ? 0.03 : 0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Circle()
                    .strokeBorder(borderTint, lineWidth: 0.8)

                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: AiQoProfileButtonLayout.symbolPointSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(iconTint)
            }
            .frame(
                width: AiQoProfileButtonLayout.visualDiameter,
                height: AiQoProfileButtonLayout.visualDiameter
            )
            .shadow(
                color: shadowTint,
                radius: AiQoProfileButtonLayout.shadowRadius,
                x: 0,
                y: AiQoProfileButtonLayout.shadowYOffset
            )
            .frame(
                width: AiQoProfileButtonLayout.hitTargetDiameter,
                height: AiQoProfileButtonLayout.hitTargetDiameter
            )
            .contentShape(Circle())
        }
        .buttonStyle(AiQoProfileButtonPressStyle())
        .sensoryFeedback(.selection, trigger: feedbackTrigger)
        .accessibilityLabel("Profile")
    }
}

private struct AiQoProfileSheetModifier: ViewModifier {
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                NavigationStack {
                    ProfileScreen()
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
            }
    }
}

extension View {
    func aiqoProfileSheet(isPresented: Binding<Bool>) -> some View {
        modifier(AiQoProfileSheetModifier(isPresented: isPresented))
    }
}

private struct AiQoProfileButtonPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.snappy(duration: 0.22, extraBounce: 0.04), value: configuration.isPressed)
    }
}

#Preview {
    ZStack {
        Color(.systemBackground)
            .ignoresSafeArea()

        AiQoProfileButton { }
    }
}
