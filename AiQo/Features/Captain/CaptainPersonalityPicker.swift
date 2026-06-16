import SwiftUI

/// Captain personality customization — a Max/Pro feature.
///   • Free  → a single locked card that opens the paywall (no style picking).
///   • Max   → pick from the preset personalities; the custom slot is Pro-locked.
///   • Pro   → presets + a free-text "describe your Captain" field.
struct CaptainPersonalityPicker: View {
    @Binding var tone: CaptainTone
    @Binding var customStyle: String
    let isPaid: Bool
    let isPro: Bool
    let isArabic: Bool
    let onUpgrade: () -> Void

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        VStack(alignment: isArabic ? .trailing : .leading, spacing: 12) {
            HStack(spacing: 6) {
                Text(isArabic ? "شخصية الكابتن" : "Captain's personality")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                if !isPaid {
                    proBadge(text: "Max")
                }
            }
            .frame(maxWidth: .infinity, alignment: isArabic ? .trailing : .leading)

            if isPaid {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(CaptainTone.allCases, id: \.self) { style in
                        styleCard(style)
                    }
                }
                customSection
            } else {
                lockedCard
            }
        }
        .environment(\.layoutDirection, isArabic ? .rightToLeft : .leftToRight)
    }

    // MARK: - Paid: preset cards

    private func styleCard(_ style: CaptainTone) -> some View {
        let selected = (tone == style && customStyle.trimmingCharacters(in: .whitespaces).isEmpty)
        return Button {
            tone = style
            // Selecting a preset clears any custom persona so the choice is unambiguous.
            customStyle = ""
        } label: {
            VStack(alignment: isArabic ? .trailing : .leading, spacing: 4) {
                Text(style.emoji).font(.system(size: 22))
                Text(style.displayName)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)
                Text(style.blurb)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.5))
                    .lineLimit(2)
                    .multilineTextAlignment(isArabic ? .trailing : .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 84, alignment: isArabic ? .topTrailing : .topLeading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(selected ? GymTheme.mint.opacity(0.16) : Color.primary.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(selected ? GymTheme.mint : Color.primary.opacity(0.08),
                                    lineWidth: selected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Custom (Pro)

    @ViewBuilder
    private var customSection: some View {
        if isPro {
            VStack(alignment: isArabic ? .trailing : .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("✍️ \(isArabic ? "نمط مخصّص" : "Custom")")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.primary)
                    proBadge(text: "Pro")
                }
                .frame(maxWidth: .infinity, alignment: isArabic ? .trailing : .leading)

                TextField(
                    isArabic ? "اكتب شخصية كابتنك بكلماتك…" : "Describe your Captain in your own words…",
                    text: $customStyle,
                    axis: .vertical
                )
                .lineLimit(2...4)
                .font(.system(size: 13))
                .multilineTextAlignment(isArabic ? .trailing : .leading)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                )

                Text(isArabic ? "اذا كتبت شخصية، تتغلّب على النمط المختار." : "A custom persona overrides the selected preset.")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.4))
            }
        } else {
            Button(action: onUpgrade) {
                HStack(spacing: 10) {
                    Text("✍️")
                    VStack(alignment: isArabic ? .trailing : .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(isArabic ? "نمط مخصّص" : "Custom persona")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.primary)
                            proBadge(text: "Pro")
                        }
                        Text(isArabic ? "اكتب شخصية كابتنك بكلماتك" : "Write your Captain in your own words")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.primary.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity, alignment: isArabic ? .trailing : .leading)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.primary.opacity(0.35))
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Free: locked

    private var lockedCard: some View {
        Button(action: onUpgrade) {
            HStack(spacing: 12) {
                Text("✨").font(.system(size: 24))
                VStack(alignment: isArabic ? .trailing : .leading, spacing: 3) {
                    Text(isArabic ? "خصّص شخصية كابتنك" : "Customize your Captain")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.primary)
                    Text(isArabic
                         ? "اختر من ٦ شخصيات — أو اكتب وحدة بنفسك. متاح مع AiQo Max."
                         : "Pick from 6 personalities — or write your own. Available with AiQo Max.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.55))
                        .multilineTextAlignment(isArabic ? .trailing : .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: isArabic ? .trailing : .leading)
                Image(systemName: isArabic ? "chevron.left" : "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(GymTheme.mint)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(GymTheme.mint.opacity(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(GymTheme.mint.opacity(0.30), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func proBadge(text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(GymTheme.mint))
    }
}
