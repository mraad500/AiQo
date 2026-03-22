import SwiftUI

/// Shareable invite card rendered entirely in SwiftUI.
/// Designed for `ImageRenderer` capture at 1080×1920 (Instagram Story / full-screen share).
struct InviteCardView: View {
    let tribeName: String
    let inviterName: String
    let inviteCode: String
    let validUntil: String
    let memberCount: Int

    // MARK: - Layout Constants

    private let cardWidth: CGFloat = 1080
    private let cardHeight: CGFloat = 1920

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                Spacer().frame(height: 200)

                topBadge
                    .padding(.bottom, 48)

                ringSection
                    .padding(.bottom, 40)

                inviterSection
                    .padding(.bottom, 64)

                codeSection
                    .padding(.bottom, 56)

                qrPlaceholder
                    .padding(.bottom, 48)

                validityBadge

                Spacer()

                footer
                    .padding(.bottom, 100)
            }
            .padding(.horizontal, 80)
        }
        .frame(width: cardWidth, height: cardHeight)
        .environment(\.layoutDirection, .rightToLeft)
    }

    // MARK: - Background

    private var background: some View {
        Image("TribeInviteBackground")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .ignoresSafeArea()
    }

    // MARK: - Top Badge

    private var topBadge: some View {
        HStack(spacing: 12) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 28))
                .symbolRenderingMode(.hierarchical)
            Text("دعوة قبيلة")
        }
        .font(.system(size: 32, weight: .semibold, design: .rounded))
        .foregroundStyle(Color(hex: "B7E5D2"))
        .padding(.horizontal, 36)
        .padding(.vertical, 18)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
    }

    // MARK: - Ring Section

    private var ringSection: some View {
        ZStack {
            ForEach(0..<5, id: \.self) { index in
                let gapDegrees: Double = 4
                let startAngle = Double(index) * 72.0 - 90.0 + gapDegrees / 2
                let endAngle = startAngle + 72.0 - gapDegrees

                Circle()
                    .trim(
                        from: CGFloat((startAngle + 90) / 360),
                        to: CGFloat((endAngle + 90) / 360)
                    )
                    .stroke(
                        ringColor(for: index),
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .frame(width: 320, height: 320)
            }

            VStack(spacing: 8) {
                Text(tribeName)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
            }
            .frame(width: 240)
        }
        .frame(width: 360, height: 360)
    }

    private func ringColor(for index: Int) -> Color {
        let colors: [Color] = [
            Color(hex: "8AE3D1"),
            Color(hex: "F5D5A6"),
            Color(hex: "B8C5F2"),
            Color(hex: "F5B5B5"),
            Color(hex: "A8D8EA"),
        ]
        return index < memberCount ? colors[index] : Color.gray.opacity(0.15)
    }

    // MARK: - Inviter Section

    private var inviterSection: some View {
        VStack(spacing: 12) {
            Text("دعوة من")
                .font(.system(size: 26, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))

            Text(inviterName)
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Code Section

    private var codeSection: some View {
        VStack(spacing: 16) {
            Text("رمز الانضمام")
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))

            Text(inviteCode)
                .font(.system(size: 72, weight: .heavy, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.white)
                .tracking(4)
                .padding(.horizontal, 48)
                .padding(.vertical, 28)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1.5)
                        )
                )
        }
    }

    // MARK: - QR Placeholder

    private var qrPlaceholder: some View {
        VStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.10))
                .frame(width: 200, height: 200)
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: "qrcode")
                            .font(.system(size: 80))
                            .foregroundStyle(.white.opacity(0.25))
                        Text("QR")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1.5)
                )
        }
    }

    // MARK: - Validity Badge

    private var validityBadge: some View {
        HStack(spacing: 10) {
            Image(systemName: "clock.fill")
                .font(.system(size: 20))
                .symbolRenderingMode(.hierarchical)

            Text("صالح حتى \(validUntil)")
        }
        .font(.system(size: 24, weight: .medium, design: .rounded))
        .foregroundStyle(.white.opacity(0.7))
        .padding(.horizontal, 28)
        .padding(.vertical, 14)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.12))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Text("AiQo")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: "B7E5D2"))

            Spacer()

            Text("\(memberCount)/5 أعضاء")
                .font(.system(size: 26, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}

// MARK: - Preview (phone scale)

#Preview {
    InviteCardView(
        tribeName: "قبيلة الصقور",
        inviterName: "حمودي",
        inviteCode: "AQ-X9K2",
        validUntil: "٣٠ أبريل ٢٠٢٦",
        memberCount: 3
    )
    .scaleEffect(0.36)
    .frame(width: 390, height: 693)
}
