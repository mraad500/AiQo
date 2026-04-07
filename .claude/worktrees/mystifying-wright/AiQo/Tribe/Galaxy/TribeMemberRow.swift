import SwiftUI

struct TribeMemberRow: View {
    let member: ArenaTribeMember
    let memberIndex: Int
    let points: Int
    let level: Int
    let username: String

    var body: some View {
        HStack(spacing: 12) {
            // نقطة لون الحلقة
            Circle()
                .fill(ringColor)
                .frame(width: 8, height: 8)

            // Avatar
            ZStack {
                Circle()
                    .fill(ringColor.opacity(0.2))
                    .frame(width: 48, height: 48)
                Text(member.initials)
                    .font(.system(.callout, design: .rounded, weight: .semibold))
                    .foregroundStyle(TribePalette.textPrimary)
            }
            .overlay(
                Circle()
                    .stroke(ringColor.opacity(0.5), lineWidth: 1.5)
            )

            // المعلومات
            VStack(alignment: .trailing, spacing: 3) {
                HStack(spacing: 6) {
                    Text(member.displayName)
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(TribePalette.textPrimary)
                    if member.isCreator {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 10))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Color.aiqoSand)
                    }
                }
                Text("@\(username)")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(TribePalette.textSecondary)
            }

            Spacer(minLength: 0)

            // النقاط والمستوى
            VStack(alignment: .trailing, spacing: 3) {
                HStack(spacing: 4) {
                    Text(points.arabicFormatted)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 10))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.aiqoSand)
                }
                .foregroundStyle(TribePalette.textPrimary)

                Text("المستوى \(level.arabicFormatted)")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(TribePalette.textTertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                )
        )
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }

    private var ringColor: Color {
        if memberIndex < TribeRingView.memberColors.count {
            return TribeRingView.memberColors[memberIndex]
        }
        return Color.gray.opacity(0.3)
    }
}
