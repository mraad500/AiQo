import SwiftUI

struct TribeScreenBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    TribeModernPalette.backgroundTop,
                    TribeModernPalette.backgroundMiddle,
                    TribeModernPalette.backgroundBottom
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(TribeModernPalette.backgroundMintGlow.opacity(0.34))
                .frame(width: 280, height: 280)
                .blur(radius: 80)
                .offset(x: -110, y: -220)

            Circle()
                .fill(TribeModernPalette.backgroundSandGlow.opacity(0.24))
                .frame(width: 220, height: 220)
                .blur(radius: 70)
                .offset(x: 120, y: -120)

            Circle()
                .fill(TribeModernPalette.backgroundWhiteGlow)
                .frame(width: 320, height: 320)
                .blur(radius: 110)
                .offset(x: 60, y: 180)
        }
        .ignoresSafeArea()
    }
}

struct TribeTopSegmentedControl: View {
    @Binding var selection: TribeDashboardTab

    var body: some View {
        Picker("", selection: $selection) {
            ForEach(TribeDashboardTab.allCases) { tab in
                Text(tab.title)
                    .tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .controlSize(.regular)
        .scaleEffect(y: 1.12)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 2)
        .sensoryFeedback(.selection, trigger: selection)
    }
}

struct TribeView: View {
    let heroSummary: TribeSummary
    let featuredMembers: [TribeRingMember]
    let onRefresh: @Sendable () async -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                TribeHeroCardCompact(
                    summary: heroSummary,
                    featuredMembers: featuredMembers
                )

                TribeMembersSection(featuredMembers: featuredMembers)
            }
            .padding(.horizontal, TribePremiumTokens.horizontalPadding)
            .padding(.top, 0)
            .padding(.bottom, 108)
        }
        .contentMargins(.top, 0, for: .scrollContent)
        .contentMargins(.top, 0, for: .scrollIndicators)
        .refreshable {
            await onRefresh()
        }
    }
}

struct TribeHeroCardCompact: View {
    let summary: TribeSummary
    let featuredMembers: [TribeRingMember]

    var body: some View {
        TribeSurfaceCard(padding: 18, cornerRadius: 30) {
            HStack(alignment: .center, spacing: 18) {
                VStack(spacing: 4) {
                    TribeRingView(
                        size: 138,
                        members: featuredMembers,
                        segmentTarget: summary.ringSegmentTarget
                    )

                    Text(summary.progressValue)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(TribeModernPalette.textSecondary)
                }
                .frame(width: 138)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(summary.title)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(TribeModernPalette.textPrimary)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(minHeight: 156)
            .environment(\.layoutDirection, .leftToRight)
        }
    }
}

struct TribeMembersSection: View {
    let featuredMembers: [TribeRingMember]

    var body: some View {
        VStack(spacing: 12) {
            TribeSectionHeader(
                title: "أعضاء القبيلة",
                subtitle: "كل عضو مرتبط بلون قطاع داخل الحلقة، مع حضور هادئ ومقاييس مختصرة."
            )

            VStack(spacing: 8) {
                ForEach(featuredMembers) { featuredMember in
                    TribeMemberCardCompact(featuredMember: featuredMember)
                }
            }
        }
    }
}

struct TribePhasePlaceholderPage: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        VStack {
            Spacer(minLength: 16)

            TribeSurfaceCard(accent: TribeModernPalette.sand, padding: 28) {
                VStack(spacing: 16) {
                    Circle()
                        .fill(TribeModernPalette.sandSoft.opacity(0.72))
                        .frame(width: 72, height: 72)
                        .overlay {
                            Image(systemName: systemImage)
                                .font(.system(size: 26, weight: .medium))
                                .foregroundStyle(TribeModernPalette.textSecondary)
                        }

                    VStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(TribeModernPalette.textPrimary)

                        Text(subtitle)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(TribeModernPalette.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, TribePremiumTokens.horizontalPadding)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct TribeSectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text(title)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(TribeModernPalette.textPrimary)
                .multilineTextAlignment(.trailing)

            Text(subtitle)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(TribeModernPalette.textSecondary)
                .multilineTextAlignment(.trailing)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

struct TribeSurfaceCard<Content: View>: View {
    private let accent: Color?
    private let padding: CGFloat
    private let cornerRadius: CGFloat
    private let content: Content

    init(
        accent: Color? = nil,
        padding: CGFloat = TribePremiumTokens.cardPadding,
        cornerRadius: CGFloat = TribePremiumTokens.cardRadius,
        @ViewBuilder content: () -> Content
    ) {
        self.accent = accent
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        TribeModernPalette.surfaceTop,
                                        TribeModernPalette.surfaceBottom
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay {
                        if let accent {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            accent.opacity(0.07),
                                            Color.clear,
                                            TribeModernPalette.accentFlash
                                        ],
                                        startPoint: .topTrailing,
                                        endPoint: .bottomLeading
                                    )
                                )
                        }
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(TribeModernPalette.border, lineWidth: 1)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(TribeModernPalette.surfaceHighlight, lineWidth: 0.8)
                            .padding(1.2)
                    }
            }
            .shadow(color: TribeModernPalette.shadow.opacity(0.05), radius: 16, x: 0, y: 10)
    }
}

struct TribeLoadingView: View {
    var body: some View {
        TribeSurfaceCard(accent: TribeModernPalette.mint, padding: 26) {
            VStack(spacing: 14) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.large)
                    .tint(TribeModernPalette.mintDeep)

                Text("جارٍ تجهيز حلقة القبيلة")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(TribeModernPalette.textPrimary)

                Text("نحضر لك نبض اليوم والأعضاء المرتبطين بكل قطاع.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(TribeModernPalette.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct TribeMemberCardCompact: View {
    let featuredMember: TribeRingMember

    var body: some View {
        TribeSurfaceCard(padding: 0, cornerRadius: 28) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(featuredMember.displayName)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(TribeModernPalette.textPrimary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    Text(featuredMember.isVacant ? "مساحة جاهزة لعضو جديد" : featuredMember.roleTitle)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(TribeModernPalette.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    HStack(spacing: 6) {
                        TribeMetadataChip(
                            text: featuredMember.levelText,
                            tint: featuredMember.sectorColor.accent,
                            usesMutedStyle: true
                        )

                        TribeMetadataChip(
                            text: featuredMember.segmentLabel,
                            tint: featuredMember.sectorColor.accent,
                            usesMutedStyle: true
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }

                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(featuredMember.sectorColor.accent.opacity(0.92))
                    .frame(width: 4, height: 78)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(featuredMember.contributionValue)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(TribeModernPalette.textPrimary)

                    Text(featuredMember.contributionLabel)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(TribeModernPalette.textSecondary)
                }
                .frame(minWidth: 62, alignment: .trailing)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(minHeight: 96)
            .environment(\.layoutDirection, .leftToRight)
        }
    }
}

struct TribeMetadataChip: View {
    let text: String
    let tint: Color
    let usesMutedStyle: Bool

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(usesMutedStyle ? TribeModernPalette.textSecondary : TribeModernPalette.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                Capsule(style: .continuous)
                    .fill(usesMutedStyle ? tint.opacity(0.10) : tint.opacity(0.22))
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(usesMutedStyle ? tint.opacity(0.14) : tint.opacity(0.26), lineWidth: 0.8)
                    }
            }
    }
}

private enum ArenaLayoutMetrics {
    static let screenSpacing: CGFloat = 12
    static let challengeStackSpacing: CGFloat = 10
    static let challengePadding: CGFloat = 15
    static let challengeCornerRadius: CGFloat = 26
    static let challengeContentSpacing: CGFloat = 11
    static let challengeMetadataSpacing: CGFloat = 10
    static let progressHeight: CGFloat = 9
}

struct ArenaView: View {
    let heroSummary: ArenaHeroSummary
    let challenges: [ArenaCompactChallenge]
    let onRefresh: @Sendable () async -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: ArenaLayoutMetrics.screenSpacing) {
                ArenaHeaderCard(summary: heroSummary)

                VStack(spacing: ArenaLayoutMetrics.challengeStackSpacing) {
                    ForEach(Array(challenges.prefix(4))) { challenge in
                        ArenaChallengeCard(challenge: challenge)
                    }
                }
            }
            .padding(.horizontal, TribePremiumTokens.horizontalPadding)
            .padding(.top, 0)
            .padding(.bottom, 108)
            .background(alignment: .top) {
                ArenaAmbientBackdrop()
                    .offset(y: -72)
            }
        }
        .contentMargins(.top, 0, for: .scrollContent)
        .contentMargins(.top, 0, for: .scrollIndicators)
        .refreshable {
            await onRefresh()
        }
    }
}

struct ArenaAmbientBackdrop: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(TribeModernPalette.mint.opacity(0.16))
                .frame(width: 240, height: 240)
                .blur(radius: 90)
                .offset(x: -120, y: -20)

            Circle()
                .fill(TribeModernPalette.sky.opacity(0.14))
                .frame(width: 210, height: 210)
                .blur(radius: 90)
                .offset(x: 124, y: 88)

            Circle()
                .fill(TribeModernPalette.lavender.opacity(0.10))
                .frame(width: 200, height: 200)
                .blur(radius: 95)
                .offset(x: -28, y: 240)
        }
        .frame(maxWidth: .infinity, minHeight: 520)
        .allowsHitTesting(false)
    }
}

struct ArenaFilterSegment<Option: Identifiable & Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    let title: (Option) -> String

    init(
        options: [Option],
        selection: Binding<Option>,
        title: @escaping (Option) -> String = { "\($0.id)" }
    ) {
        self.options = options
        self._selection = selection
        self.title = title
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options) { option in
                let isSelected = option == selection

                Button {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
                        selection = option
                    }
                } label: {
                    Text(title(option))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(isSelected ? TribeModernPalette.textPrimary : TribeModernPalette.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background {
                            Capsule(style: .continuous)
                                .fill(isSelected ? TribeModernPalette.controlSelectedFill : Color.clear)
                                .overlay {
                                    Capsule(style: .continuous)
                                        .stroke(
                                            isSelected ? TribeModernPalette.borderStrong.opacity(0.85) : Color.clear,
                                            lineWidth: 0.8
                                        )
                                }
                                .shadow(color: isSelected ? TribeModernPalette.shadow.opacity(0.05) : .clear, radius: 10, x: 0, y: 6)
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(TribeModernPalette.controlFill)
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(TribeModernPalette.border.opacity(0.82), lineWidth: 1)
                }
        }
    }
}

struct ArenaHeaderCard: View {
    let summary: ArenaHeroSummary

    var body: some View {
        TribeSurfaceCard(accent: TribeModernPalette.mint, padding: 20, cornerRadius: 30) {
            HStack(alignment: .top, spacing: 16) {
                Text(summary.activeCountText)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(TribeModernPalette.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background {
                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        TribeModernPalette.mint.opacity(0.28),
                                        TribeModernPalette.sky.opacity(0.16)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay {
                                Capsule(style: .continuous)
                                    .stroke(TribeModernPalette.borderStrong.opacity(0.72), lineWidth: 0.8)
                            }
                    }

                VStack(alignment: .trailing, spacing: 6) {
                    Text(summary.title)
                        .font(.system(size: 25, weight: .bold, design: .rounded))
                        .foregroundStyle(TribeModernPalette.textPrimary)
                        .multilineTextAlignment(.trailing)

                    Text(summary.subtitle)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(TribeModernPalette.textSecondary)
                        .multilineTextAlignment(.trailing)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .environment(\.layoutDirection, .leftToRight)
        }
    }
}

struct ArenaChallengeCard: View {
    let challenge: ArenaCompactChallenge

    var body: some View {
        TribeSurfaceCard(
            accent: challenge.accentColor,
            padding: ArenaLayoutMetrics.challengePadding,
            cornerRadius: ArenaLayoutMetrics.challengeCornerRadius
        ) {
            VStack(alignment: .trailing, spacing: ArenaLayoutMetrics.challengeContentSpacing) {
                HStack(spacing: 8) {
                    ArenaStatusBadge(status: challenge.status, tint: challenge.accentColor)

                    Spacer(minLength: 10)

                    TribePillLabel(
                        text: challenge.category,
                        tint: challenge.accentColor,
                        textColor: TribeModernPalette.textPrimary
                    )
                }

                Text(challenge.title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(TribeModernPalette.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .multilineTextAlignment(.trailing)

                ArenaProgressBar(progress: challenge.progress, tint: challenge.accentColor)
                    .frame(height: ArenaLayoutMetrics.progressHeight)

                HStack(alignment: .bottom, spacing: ArenaLayoutMetrics.challengeMetadataSpacing) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(challenge.timeLeftLabel)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(TribeModernPalette.textSecondary)

                        Text(challenge.participantLabel)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(TribeModernPalette.textTertiary)
                    }

                    Spacer(minLength: 12)

                    Text(challenge.progressText)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(TribeModernPalette.textPrimary)
                        .monospacedDigit()
                }
            }
            .environment(\.layoutDirection, .leftToRight)
        }
    }
}

struct ArenaStatusBadge: View {
    let status: ArenaChallengeStatus
    let tint: Color

    var body: some View {
        Text(status.title)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(TribeModernPalette.textPrimary)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background {
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: status.isCallToAction
                                ? [tint.opacity(0.30), tint.opacity(0.18)]
                                : [tint.opacity(0.16), TribeModernPalette.subtleSurface],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(
                                status.isCallToAction ? tint.opacity(0.22) : tint.opacity(0.12),
                                lineWidth: 0.9
                            )
                    }
                    .shadow(
                        color: status.isCallToAction ? tint.opacity(0.12) : .clear,
                        radius: 10,
                        x: 0,
                        y: 6
                    )
            }
    }
}

struct ArenaProgressBar: View {
    let progress: Double
    let tint: Color

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let clampedProgress = min(max(progress, 0), 1)

            ZStack(alignment: .trailing) {
                Capsule(style: .continuous)
                    .fill(TribeModernPalette.progressTrack)

                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                tint.opacity(0.40),
                                tint.opacity(0.82)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(width * clampedProgress, 14))
            }
        }
    }
}

struct GlobalView: View {
    @Binding var timeFilter: GlobalTimeFilter
    let topThree: [TribeGlobalRankEntry]
    let selfRankSummary: GlobalSelfRankSummary
    let rankings: [GlobalRankingRowItem]
    let onRefresh: @Sendable () async -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                GlobalPodiumCard(entries: topThree)

                ArenaFilterSegment(options: GlobalTimeFilter.allCases, selection: $timeFilter) {
                    $0.title
                }

                YourGlobalRankCard(summary: selfRankSummary)

                VStack(spacing: 6) {
                    ForEach(rankings) { item in
                        GlobalRankingRow(item: item)
                    }
                }
            }
            .padding(.horizontal, TribePremiumTokens.horizontalPadding)
            .padding(.top, 0)
            .padding(.bottom, 108)
        }
        .contentMargins(.top, 0, for: .scrollContent)
        .contentMargins(.top, 0, for: .scrollIndicators)
        .refreshable {
            await onRefresh()
        }
    }
}

struct GlobalPodiumCard: View {
    let entries: [TribeGlobalRankEntry]

    var body: some View {
        TribeSurfaceCard(accent: TribeModernPalette.sandSoft, padding: 16, cornerRadius: 30) {
            HStack(alignment: .bottom, spacing: 12) {
                podiumItem(for: entries.count > 1 ? entries[1] : nil, emphasized: false)
                podiumItem(for: entries.first, emphasized: true)
                podiumItem(for: entries.count > 2 ? entries[2] : nil, emphasized: false)
            }
            .environment(\.layoutDirection, .leftToRight)
        }
    }

    private func podiumItem(for entry: TribeGlobalRankEntry?, emphasized: Bool) -> some View {
        VStack(spacing: 8) {
            if let entry {
                TribeInitialAvatar(name: entry.name, accent: entry.accent, size: emphasized ? 58 : 48)
                    .overlay(alignment: .topTrailing) {
                        if emphasized {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(TribeModernPalette.warm)
                                .padding(5)
                                .background(TribeModernPalette.crownSurface, in: Circle())
                                .offset(x: 6, y: -6)
                        }
                    }

                VStack(spacing: 2) {
                    Text(entry.name)
                        .font(.system(size: emphasized ? 15 : 13, weight: .bold, design: .rounded))
                        .foregroundStyle(TribeModernPalette.textPrimary)
                        .lineLimit(1)

                    Text(entry.formattedScore)
                        .font(.system(size: emphasized ? 13 : 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(TribeModernPalette.textSecondary)
                }

                Text("#\(entry.rank)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(TribeModernPalette.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background {
                        Capsule(style: .continuous)
                            .fill(emphasized ? TribeModernPalette.sand.opacity(0.24) : TribeModernPalette.cardTint.opacity(0.85))
                    }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, emphasized ? 2 : 10)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    emphasized
                    ? TribeModernPalette.sandSoft.opacity(0.46)
                    : TribeModernPalette.subtleSurface
                )
        }
    }
}

struct YourGlobalRankCard: View {
    let summary: GlobalSelfRankSummary

    var body: some View {
        TribeSurfaceCard(accent: TribeModernPalette.sky, padding: 16, cornerRadius: 26) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .trailing, spacing: 3) {
                    Text(summary.title)
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundStyle(TribeModernPalette.textPrimary)

                    Text(summary.percentileText)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(TribeModernPalette.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)

                Text(summary.scoreText)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(TribeModernPalette.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background {
                        Capsule(style: .continuous)
                            .fill(TribeModernPalette.chipBackground)
                    }
            }
        }
    }
}

struct GlobalRankingRow: View {
    let item: GlobalRankingRowItem

    var body: some View {
        TribeSurfaceCard(accent: item.isCurrentUser ? item.accent : nil, padding: 11, cornerRadius: 20) {
            HStack(alignment: .center, spacing: 10) {
                Text("#\(item.rank)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(TribeModernPalette.textSecondary)
                    .frame(minWidth: 34, alignment: .center)

                TribeInitialAvatar(name: item.name, accent: item.accent, size: 34)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(item.name)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(TribeModernPalette.textPrimary)
                        .lineLimit(1)

                    Text(item.caption)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(TribeModernPalette.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Text(item.scoreText)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(TribeModernPalette.textPrimary)

                Image(systemName: item.trend.symbolName)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(item.trend.color)
                    .frame(width: 16)
            }
        }
    }
}

struct TribeMiniProgressBar: View {
    let progress: Double
    let tint: Color

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let clampedProgress = min(max(progress, 0), 1)

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(TribeModernPalette.progressTrack)

                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                tint.opacity(0.78),
                                tint
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(width * clampedProgress, 10))
            }
        }
    }
}

struct TribePillLabel: View {
    let text: String
    let tint: Color
    let textColor: Color

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(textColor)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background {
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.13))
            }
    }
}

struct TribeInitialAvatar: View {
    let name: String
    let accent: Color
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(accent.opacity(0.16))

            Circle()
                .stroke(accent.opacity(0.16), lineWidth: 1)

            Text(name.tribeDisplayInitials)
                .font(.system(size: size * 0.34, weight: .bold, design: .rounded))
                .foregroundStyle(TribeModernPalette.textPrimary)
        }
        .frame(width: size, height: size)
    }
}
