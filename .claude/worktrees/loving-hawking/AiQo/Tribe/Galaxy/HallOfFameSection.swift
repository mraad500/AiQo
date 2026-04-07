import SwiftUI

struct HallOfFameSection: View {
    let entries: [ArenaHallOfFameEntry]
    var onShowAll: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // العنوان
            HStack(spacing: 6) {
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 16))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.aiqoSand)
                Text("سجل الأمجاد")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(TribePalette.textPrimary)
            }

            if entries.isEmpty {
                VStack(spacing: 8) {
                    Text("سجل الأمجاد ينتظر أبطاله الأوائل")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(TribePalette.textTertiary)
                    Text("🏆")
                        .font(.system(size: 28))
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 16)
            } else {
                VStack(spacing: 6) {
                    ForEach(entries) { entry in
                        HallOfFameRow(entry: entry)
                    }
                }

                Button(action: onShowAll) {
                    HStack(spacing: 4) {
                        Text("عرض الكل")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(Color(hex: "2D6B4A"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.white.opacity(0.3))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                )
        }
        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
    }
}

// MARK: - صف واحد بسجل الأمجاد — upgraded

private struct HallOfFameRow: View {
    let entry: ArenaHallOfFameEntry

    var body: some View {
        HStack(spacing: 10) {
            Text("الأسبوع \(entry.weekNumber)")
                .font(.system(.caption, design: .rounded, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(TribePalette.textTertiary)
                .frame(width: 68, alignment: .trailing)

            Spacer(minLength: 0)

            // اسم القبيلة — pill badge
            Text(entry.tribeName)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(TribePalette.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(Color.aiqoSand.opacity(0.18))
                )

            Text(entry.challengeTitle)
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(TribePalette.textSecondary)
                .lineLimit(1)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.15))
        )
    }
}
