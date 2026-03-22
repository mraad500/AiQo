import SwiftUI

struct TribeInviteView: View {
    let tribe: ArenaTribe
    @Environment(\.dismiss) private var dismiss
    @State private var didCopy = false
    @State private var isRenderingCard = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "link.circle.fill")
                        .font(.system(size: 44))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.aiqoMint)
                        .padding(.top, 16)

                    Text("دعوة أعضاء جدد")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(TribePalette.textPrimary)

                    Text("\(tribe.name) — \(tribe.members.count)/٥ أعضاء")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(TribePalette.textSecondary)

                    // رمز الدعوة
                    VStack(spacing: 8) {
                        Text("رمز الدعوة")
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(TribePalette.textTertiary)

                        Text(tribe.inviteCode)
                            .font(.system(size: 36, weight: .heavy, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(TribePalette.textPrimary)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.aiqoSand.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .stroke(Color.aiqoSand.opacity(0.25), lineWidth: 0.5)
                                    )
                            )
                    }

                    // أزرار
                    VStack(spacing: 10) {
                        Button {
                            UIPasteboard.general.string = tribe.inviteCode
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) { didCopy = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation { didCopy = false }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                                Text(didCopy ? "تم النسخ!" : "نسخ الرمز")
                            }
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(Color(hex: "2D6B4A"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.aiqoMint.opacity(0.12))
                            )
                        }

                        Button { shareAsImage() } label: {
                            HStack(spacing: 6) {
                                if isRenderingCard {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: "square.and.arrow.up")
                                }
                                Text("شارك كصورة")
                            }
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color(hex: "2D6B4A"))
                            )
                            .shadow(color: Color(hex: "2D6B4A").opacity(0.2), radius: 8, y: 3)
                        }
                        .disabled(isRenderingCard)
                    }

                    // قائمة الأعضاء
                    VStack(alignment: .leading, spacing: 10) {
                        Text("الأعضاء")
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(TribePalette.textPrimary)

                        ForEach(tribe.members) { member in
                            HStack(spacing: 10) {
                                MemberInitialsCircle(initials: member.initials, size: 34)

                                Text(member.displayName)
                                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                                    .foregroundStyle(TribePalette.textPrimary)

                                if member.isCreator {
                                    HStack(spacing: 3) {
                                        Image(systemName: "crown.fill")
                                            .font(.system(size: 9))
                                            .symbolRenderingMode(.hierarchical)
                                        Text("المؤسس")
                                    }
                                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                                    .foregroundStyle(Color.aiqoSand)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(Color.aiqoSand.opacity(0.12))
                                    )
                                }

                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                            )
                    )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(
                LinearGradient(
                    colors: [TribePalette.backgroundTop, TribePalette.backgroundBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("إغلاق") { dismiss() }
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Color(hex: "2D6B4A"))
                }
            }
            .environment(\.layoutDirection, .rightToLeft)
        }
    }

    private func shareAsImage() {
        isRenderingCard = true

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ar")
        formatter.dateStyle = .long
        let validUntil = formatter.string(from: Date().addingTimeInterval(7 * 24 * 60 * 60))

        let creatorName = tribe.members.first(where: \.isCreator)?.displayName ?? "عضو"

        Task {
            guard let image = await ShareCardRenderer.renderInviteCard(
                tribeName: tribe.name,
                inviterName: creatorName,
                inviteCode: tribe.inviteCode,
                validUntil: validUntil,
                memberCount: tribe.members.count
            ) else {
                isRenderingCard = false
                return
            }

            let shareText = String(format: NSLocalizedString("tribe.invite.shareText", value: "انضم لقبيلتي في AiQo! 💪\nالكود: %@\nhttps://aiqo.app/tribe/%@", comment: ""), tribe.inviteCode, tribe.inviteCode)
            ShareCardRenderer.presentShareSheet(
                image: image,
                text: shareText
            )
            isRenderingCard = false
        }
    }
}
