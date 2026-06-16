import SwiftUI

/// Makes the Captain's paid upgrade *legible* to free users without nagging:
/// a slim, dismissible banner → a visual "your Captain levels up" sheet → the
/// paywall. Honest + tasteful, matching AiQo's "depth not caps, no resentment"
/// stance (the banner is capped + dismissible; nothing is blocked).

// MARK: - Dismiss cap

/// Cross-session cooldown for the upgrade banner. Shown again only after the
/// cooldown elapses, so a free user who dismisses it isn't pestered.
enum CaptainUpgradeNudge {
    static let dismissEpochKey = "captain.growsBanner.dismissedAtEpoch"
    static let cooldown: TimeInterval = 3 * 24 * 60 * 60 // 3 days

    static func shouldShow(dismissedAtEpoch: Double, now: Date = Date()) -> Bool {
        guard dismissedAtEpoch > 0 else { return true }
        return now.timeIntervalSince1970 - dismissedAtEpoch > cooldown
    }
}

// MARK: - Slim banner

/// One-line teaser placed under the chat header for free users. Tapping it opens
/// the full sheet; the ✕ snoozes it for the cooldown.
struct CaptainUpgradeBanner: View {
    let isArabic: Bool
    let onOpen: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(GymTheme.mint.opacity(0.18))
                    .frame(width: 34, height: 34)
                Image("Hammoudi5")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 30, height: 30)
                    .clipShape(Circle())
            }
            .overlay(alignment: .topTrailing) {
                Image(systemName: "sparkles")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(GymTheme.mint)
                    .offset(x: 3, y: -2)
            }

            VStack(alignment: isArabic ? .trailing : .leading, spacing: 1) {
                Text(isArabic ? "الكابتن يكبر وية Max" : "Your Captain levels up with Max")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)
                Text(isArabic ? "يتذكّرك دائماً ويدرّبك أعمق" : "Remembers you for good, coaches deeper")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.5))
            }
            .frame(maxWidth: .infinity, alignment: isArabic ? .trailing : .leading)

            Image(systemName: isArabic ? "chevron.left" : "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.primary.opacity(0.35))

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.primary.opacity(0.4))
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Color.primary.opacity(0.06)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isArabic ? "إخفاء" : "Dismiss")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(GymTheme.mint.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(GymTheme.mint.opacity(0.22), lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
        .environment(\.layoutDirection, isArabic ? .rightToLeft : .leftToRight)
    }
}

// MARK: - "Captain grows" sheet

/// The visual payoff: the evolved Captain with a soft aura + the concrete things
/// a subscription unlocks, then a single CTA into the paywall.
struct CaptainGrowsSheet: View {
    let isArabic: Bool
    let onUpgrade: () -> Void
    @Environment(\.dismiss) private var dismiss

    private struct Perk: Identifiable {
        let id = UUID()
        let icon: String
        let titleAr: String, titleEn: String
        let descAr: String, descEn: String
    }

    private let perks: [Perk] = [
        .init(icon: "brain.head.profile",
              titleAr: "ذاكرة دائمة", titleEn: "Lasting memory",
              descAr: "يتذكّرك عبر كل الأيام — مو بس هاي المحادثة", descEn: "Remembers you across the days — not just this chat"),
        .init(icon: "list.bullet.clipboard.fill",
              titleAr: "خطط كاملة", titleEn: "Full plans",
              descAr: "خطط تمرين ووجبات يتابعها وياك", descEn: "Workout & meal plans he tracks with you"),
        .init(icon: "waveform",
              titleAr: "صوت بريميوم", titleEn: "Premium voice",
              descAr: "صوت طبيعي محسّن وأقرب لحمودي", descEn: "A richer, more natural voice"),
        .init(icon: "chart.line.uptrend.xyaxis",
              titleAr: "تحليل أعمق", titleEn: "Deeper analysis",
              descAr: "قراءة أعمق لتقدّمك — والقمم بـ Pro", descEn: "Deeper reading of your progress — plus Peaks on Pro")
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                avatar
                    .padding(.top, 28)

                VStack(spacing: 6) {
                    Text(isArabic ? "الكابتن يكبر وياك" : "Your Captain levels up")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.primary)
                    Text(isArabic
                         ? "نفس حمودي — بس يتذكّرك دائماً، يخطّط أعمق، ويحجي بصوت بريميوم وية AiQo Max."
                         : "Same Hamoudi — he just remembers you for good, plans deeper, and speaks in a premium voice with AiQo Max.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                VStack(spacing: 12) {
                    ForEach(perks) { perk in
                        perkRow(perk)
                    }
                }
                .padding(.horizontal, 20)

                upgradeButton
                    .padding(.horizontal, 20)
                    .padding(.top, 4)

                Text(isArabic ? "الكابتن المجاني يبقى وياك دائماً — هاي بس ترقية." : "The free Captain stays with you — this is just an upgrade.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.4))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity)
        }
        .background(Color(UIColor.systemBackground))
        .environment(\.layoutDirection, isArabic ? .rightToLeft : .leftToRight)
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.primary.opacity(0.5))
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.primary.opacity(0.06)))
            }
            .buttonStyle(.plain)
            .padding(16)
        }
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [GymTheme.mint.opacity(0.45), .clear],
                        center: .center, startRadius: 6, endRadius: 130
                    )
                )
                .frame(width: 240, height: 240)
                .blur(radius: 14)

            Image("Hammoudi5")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 180)
                .shadow(color: .black.opacity(0.15), radius: 16, y: 10)
        }
    }

    private func perkRow(_ perk: Perk) -> some View {
        HStack(spacing: 14) {
            Image(systemName: perk.icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(GymTheme.mint)
                .frame(width: 38, height: 38)
                .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(GymTheme.mint.opacity(0.12)))

            VStack(alignment: isArabic ? .trailing : .leading, spacing: 2) {
                Text(isArabic ? perk.titleAr : perk.titleEn)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)
                Text(isArabic ? perk.descAr : perk.descEn)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.5))
                    .multilineTextAlignment(isArabic ? .trailing : .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: isArabic ? .trailing : .leading)
        }
    }

    private var upgradeButton: some View {
        Button(action: onUpgrade) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                Text(isArabic ? "شوف الباقات" : "See plans")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LinearGradient(
                        colors: [GymTheme.mint, GymTheme.mint.opacity(0.82)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
            )
        }
        .buttonStyle(.plain)
    }
}
