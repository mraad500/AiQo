import SwiftUI

struct HallOfFameFullView: View {
    let entries: [ArenaHallOfFameEntry]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(entries) { entry in
                        HStack(spacing: 14) {
                            // رقم الأسبوع
                            VStack(spacing: 2) {
                                Text(NSLocalizedString("hallOfFame.week", comment: ""))
                                    .font(.system(.caption2, design: .rounded))
                                    .foregroundStyle(TribePalette.textTertiary)
                                Text("\(entry.weekNumber)")
                                    .font(.system(.title2, design: .rounded, weight: .bold))
                                    .monospacedDigit()
                                    .foregroundStyle(TribePalette.textPrimary)
                            }
                            .frame(width: 60)

                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 5) {
                                    Image(systemName: "trophy.fill")
                                        .font(.system(size: 13))
                                        .symbolRenderingMode(.hierarchical)
                                        .foregroundStyle(Color.aiqoSand)
                                    Text(entry.tribeName)
                                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                                        .foregroundStyle(TribePalette.textPrimary)
                                }

                                Text(entry.challengeTitle)
                                    .font(.system(.caption, design: .rounded, weight: .medium))
                                    .foregroundStyle(TribePalette.textSecondary)
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                                )
                        )
                        .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
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
            .navigationTitle(NSLocalizedString("hallOfFame.title", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(NSLocalizedString("hallOfFame.close", comment: "")) { dismiss() }
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Color(hex: "2D6B4A"))
                }
            }
            .environment(\.layoutDirection, .rightToLeft)
        }
    }
}
