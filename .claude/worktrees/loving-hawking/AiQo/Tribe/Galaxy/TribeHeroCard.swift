import SwiftUI

struct TribeHeroCard: View {
    let tribe: ArenaTribe
    @State private var showEditName = false

    var body: some View {
        VStack(spacing: 18) {
            // حلقة القبيلة — اسم القبيلة داخلها
            TribeRingView(
                tribeName: tribe.name,
                memberCount: tribe.members.count
            )

            // زر تعديل الاسم فقط (الاسم بالحلقة)
            Button { showEditName = true } label: {
                Image(systemName: "pencil.line")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(TribePalette.textTertiary)
            }

            // إحصائيات سريعة
            HStack(spacing: 0) {
                TribeStatColumn(title: "الأعضاء", value: "\(tribe.members.count)/5", icon: "person.2.fill")
                Divider().frame(height: 30)
                TribeStatColumn(title: "الترتيب", value: "#2", icon: "chart.bar.fill")
                Divider().frame(height: 30)
                TribeStatColumn(title: "التحديات", value: "12", icon: "trophy.fill")
            }
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                    )
            )
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.aiqoSand.opacity(0.12), Color.aiqoMint.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                )
        )
        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
        .sheet(isPresented: $showEditName) {
            EditTribeNameSheet(currentName: tribe.name) { newName in
                tribe.name = newName
            }
            .presentationDetents([.height(250)])
        }
    }
}

// MARK: - رمز الدعوة (كارت منفصل)

struct TribeInviteCodeCard: View {
    let tribe: ArenaTribe
    @State private var didCopyCode = false
    @State private var showInviteShare = false

    var body: some View {
        HStack {
            Text("رمز الدعوة:")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(TribePalette.textSecondary)

            Text(tribe.inviteCode)
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(TribePalette.textPrimary)

            Spacer()

            Button {
                UIPasteboard.general.string = tribe.inviteCode
                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) { didCopyCode = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { didCopyCode = false }
                }
            } label: {
                Image(systemName: didCopyCode ? "checkmark" : "doc.on.doc")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Color(hex: "2D6B4A"))
            }

            Button { showInviteShare = true } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Color(hex: "2D6B4A"))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.aiqoMint.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                )
        )
        .sheet(isPresented: $showInviteShare) {
            TribeInviteView(tribe: tribe)
        }
    }
}

// MARK: - عمود إحصائية

private struct TribeStatColumn: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.aiqoSand)

            Text(value)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(TribePalette.textPrimary)

            Text(title)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(TribePalette.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}
