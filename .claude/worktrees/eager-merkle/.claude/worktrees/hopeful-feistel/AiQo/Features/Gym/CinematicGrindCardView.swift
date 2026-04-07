import SwiftUI

struct CinematicGrindCardView: View {
    var title: String = "Cinematic Grind"
    var description: String = "Lock into a story-first Zone 2 session where Captain Hammoudi keeps your cadence smooth and your focus glued to the screen."
    var buttonTitle: String = "Start Netflix Flow"
    var onStart: () -> Void = {}

    @State private var isButtonPressed = false

    var body: some View {
        GeometryReader { geometry in
            let cardWidth = min(geometry.size.width, 420)
            let imageSize = max(168, min(236, cardWidth * 0.56))
            let horizontalPadding = max(22, min(30, cardWidth * 0.07))

            ZStack(alignment: .top) {
                cardShell(horizontalPadding: horizontalPadding)
                    .padding(.top, imageSize * 0.34)

                breakoutArtwork(size: imageSize)
                    .offset(y: -40)
                    .zIndex(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(minHeight: 420, idealHeight: 470, maxHeight: 520)
    }

    private func cardShell(horizontalPadding: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer(minLength: 120)

            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.96))
                    .fixedSize(horizontal: false, vertical: true)

                Text(description)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.74))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                    isButtonPressed = true
                }

                onStart()

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                        isButtonPressed = false
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 14, weight: .bold))

                    Text(buttonTitle)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }
                .foregroundStyle(Color(hex: "0D2A2C"))
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.92),
                                    Color(hex: "D9FFF5").opacity(0.94),
                                    Color.mint.opacity(0.86)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(0.52), lineWidth: 1)
                )
                .shadow(color: .mint.opacity(0.32), radius: 16, x: 0, y: 10)
            }
            .buttonStyle(.plain)
            .scaleEffect(isButtonPressed ? 0.97 : 1)
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, 16)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(.ultraThinMaterial)

                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Color(hex: "E0F7FA").opacity(0.1))

                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.16),
                                Color.clear,
                                Color.mint.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30)
                .stroke(
                    LinearGradient(
                        colors: [.mint.opacity(0.6), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .overlay(alignment: .topLeading) {
            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.44),
                            Color.mint.opacity(0.26),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 120, height: 1.5)
                .padding(.top, 12)
                .padding(.leading, 22)
        }
        .shadow(color: .mint.opacity(0.2), radius: 20, x: 0, y: 10)
    }

    @ViewBuilder
    private func breakoutArtwork(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.mint.opacity(0.36),
                            Color(hex: "E0F7FA").opacity(0.18),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 6,
                        endRadius: size * 0.56
                    )
                )
                .frame(width: size * 1.05, height: size * 1.05)
                .blur(radius: 12)

            if UIImage(named: "Hammoudi5") != nil {
                Image("Hammoudi5")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
            } else {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.86),
                                    Color(hex: "CFF7F2").opacity(0.58)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    Image(systemName: "figure.run.circle.fill")
                        .font(.system(size: size * 0.38, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(hex: "3D8F82"),
                                    Color(hex: "18373A")
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .frame(width: size * 0.82, height: size * 0.82)
            }
        }
        .shadow(color: .mint.opacity(0.22), radius: 24, x: 0, y: 18)
        .shadow(color: Color.white.opacity(0.18), radius: 8, x: 0, y: -4)
    }
}

#Preview {
    ZStack {
        LinearGradient(
            colors: [
                Color(hex: "091418"),
                Color(hex: "10242A"),
                Color(hex: "16313A")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        CinematicGrindCardView()
            .padding(24)
    }
}
