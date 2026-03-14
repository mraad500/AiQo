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
                .fill(TribeModernPalette.backgroundMintGlow.opacity(0.55))
                .frame(width: 340, height: 340)
                .blur(radius: 90)
                .offset(x: 155, y: -260)

            Circle()
                .fill(TribeModernPalette.backgroundSandGlow.opacity(0.48))
                .frame(width: 320, height: 320)
                .blur(radius: 92)
                .offset(x: -150, y: 250)

            RoundedRectangle(cornerRadius: 72, style: .continuous)
                .fill(TribeModernPalette.backgroundWhiteGlow.opacity(0.20))
                .frame(width: 290, height: 400)
                .blur(radius: 60)
                .rotationEffect(.degrees(-18))
                .offset(x: 110, y: 140)
        }
        .ignoresSafeArea()
    }
}

struct TribeSegmentedControl: View {
    @Binding var selection: TribeDashboardTab
    @Namespace private var selectionNamespace

    var body: some View {
        HStack(spacing: 6) {
            ForEach(TribeDashboardTab.allCases) { tab in
                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                        selection = tab
                    }
                } label: {
                    Text(tab.title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(selection == tab ? TribeModernPalette.textPrimary : TribeModernPalette.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background {
                            if selection == tab {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(.regularMaterial)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        Color.white.opacity(0.90),
                                                        TribeModernPalette.sandSoft.opacity(0.72)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                    }
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .stroke(TribeModernPalette.borderStrong, lineWidth: 0.8)
                                    }
                                    .shadow(color: TribeModernPalette.shadow.opacity(0.10), radius: 12, x: 0, y: 8)
                                    .matchedGeometryEffect(id: "tribe.segment.selection", in: selectionNamespace)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    TribeModernPalette.surfaceTop.opacity(0.96),
                                    TribeModernPalette.cardTint.opacity(0.92)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(TribeModernPalette.border, lineWidth: 1)
                }
                .shadow(color: TribeModernPalette.shadow.opacity(0.08), radius: 18, x: 0, y: 12)
        }
    }
}

struct TribeOverviewPage: View {
    let heroSummary: TribeHeroSummary
    let stats: [TribeStatCardModel]
    let featuredMembers: [TribeFeaturedMember]
    let onRefresh: @Sendable () async -> Void

    private let metricColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: TribePremiumTokens.sectionSpacing) {
                TribeSurfaceCard(accent: TribeModernPalette.mint, padding: 24) {
                    VStack(alignment: .trailing, spacing: 22) {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .trailing, spacing: 8) {
                                Text("نبض اليوم")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(TribeModernPalette.textTertiary)

                                Text(heroSummary.title)
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundStyle(TribeModernPalette.textPrimary)
                                    .multilineTextAlignment(.trailing)

                                Text(heroSummary.subtitle)
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundStyle(TribeModernPalette.textSecondary)
                                    .multilineTextAlignment(.trailing)
                            }

                            Spacer(minLength: 12)

                            TribeMetadataChip(
                                text: "\(featuredMembers.filter { $0.isVacant == false }.count)/5 أعضاء",
                                tint: TribeModernPalette.sand,
                                usesMutedStyle: true
                            )
                        }

                        TribeRingView(summary: heroSummary, featuredMembers: featuredMembers)
                            .frame(maxWidth: .infinity)
                            .frame(height: 292)

                        LazyVGrid(columns: metricColumns, spacing: 10) {
                            ForEach(Array(stats.prefix(3))) { stat in
                                TribeHeroMetricTile(stat: stat)
                            }
                        }
                    }
                }

                VStack(spacing: 14) {
                    TribeSectionHeader(
                        title: "أعضاء القبيلة",
                        subtitle: "كل عضو مرتبط بلون قطاع داخل الحلقة، مع حضور هادئ ومقاييس مختصرة."
                    )

                    VStack(spacing: 12) {
                        ForEach(featuredMembers) { featuredMember in
                            TribeMemberRow(featuredMember: featuredMember)
                        }
                    }
                }
            }
            .padding(.horizontal, TribePremiumTokens.horizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
        .refreshable {
            await onRefresh()
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
                .font(.system(size: 14, weight: .medium, design: .rounded))
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
                                            accent.opacity(0.10),
                                            Color.clear,
                                            Color.white.opacity(0.08)
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
            .shadow(color: TribeModernPalette.shadow.opacity(0.10), radius: 28, x: 0, y: 18)
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

                Text("نحضر لك ملخص اليوم والأعضاء المرتبطين بالحَلقة.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(TribeModernPalette.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private struct TribeHeroMetricTile: View {
    let stat: TribeStatCardModel

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: stat.symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(stat.accent)

                Spacer(minLength: 0)

                Text(stat.title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(TribeModernPalette.textSecondary)
                    .lineLimit(1)
            }

            Text(stat.value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(TribeModernPalette.textPrimary)
                .frame(maxWidth: .infinity, alignment: .trailing)

            Text(stat.detail)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(TribeModernPalette.textTertiary)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.44))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(stat.accent.opacity(0.06))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.54), lineWidth: 0.8)
                }
        }
    }
}

private struct TribeMemberRow: View {
    let featuredMember: TribeFeaturedMember

    var body: some View {
        TribeSurfaceCard(accent: featuredMember.segment.accent, padding: 18, cornerRadius: 28) {
            HStack(alignment: .center, spacing: 14) {
                TribeMemberAvatar(featuredMember: featuredMember)

                VStack(alignment: .trailing, spacing: 10) {
                    HStack(spacing: 8) {
                        Text(featuredMember.displayName)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(TribeModernPalette.textPrimary)
                            .lineLimit(1)

                        if featuredMember.isCurrentUser {
                            TribeMetadataChip(text: "أنت", tint: featuredMember.segment.accent, usesMutedStyle: false)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)

                    Text(featuredMember.isVacant ? "مساحة جاهزة لعضو جديد" : featuredMember.roleTitle)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(TribeModernPalette.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    HStack(spacing: 8) {
                        TribeMetadataChip(
                            text: featuredMember.levelText,
                            tint: featuredMember.segment.accent,
                            usesMutedStyle: true
                        )

                        TribeMetadataChip(
                            text: featuredMember.segment.memberLabel,
                            tint: featuredMember.segment.accent,
                            usesMutedStyle: true
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }

                Spacer(minLength: 8)

                VStack(alignment: .leading, spacing: 4) {
                    Text(featuredMember.contributionValue)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(TribeModernPalette.textPrimary)

                    Text(featuredMember.contributionLabel)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(TribeModernPalette.textSecondary)
                }
            }
            .overlay(alignment: .trailing) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(featuredMember.segment.accent.opacity(0.92))
                    .frame(width: 4, height: 58)
                    .padding(.trailing, 2)
            }
        }
    }
}

private struct TribeMemberAvatar: View {
    let featuredMember: TribeFeaturedMember

    var body: some View {
        ZStack {
            Circle()
                .fill(featuredMember.segment.accent.opacity(0.16))
                .frame(width: 54, height: 54)
                .overlay {
                    Circle()
                        .stroke(featuredMember.segment.accent.opacity(0.22), lineWidth: 1)
                }

            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.92),
                            featuredMember.segment.accent.opacity(featuredMember.isVacant ? 0.10 : 0.22)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 48, height: 48)

            Text(featuredMember.initials)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(TribeModernPalette.textPrimary)
        }
        .shadow(color: featuredMember.segment.accent.opacity(0.16), radius: 10, x: 0, y: 6)
    }
}

private struct TribeMetadataChip: View {
    let text: String
    let tint: Color
    let usesMutedStyle: Bool

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(usesMutedStyle ? TribeModernPalette.textSecondary : TribeModernPalette.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
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
