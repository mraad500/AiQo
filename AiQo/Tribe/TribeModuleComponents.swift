import SwiftUI

private enum TribeAuraPalette {
    static let canvas = Color.white
    static let mint = Color(hex: "BCE2C6")
    static let beige = Color(hex: "EEDCB2")
    static let azure = Color(hex: "D4EAF7")
    static let textPrimary = Color(hex: "17262B")
    static let textSecondary = Color.black.opacity(0.34)
    static let textTertiary = Color.black.opacity(0.20)
    static let materialBorder = Color.white.opacity(0.82)
    static let materialHairline = Color.black.opacity(0.05)
    static let cardShadow = Color.black.opacity(0.04)
    static let controlShadow = Color.black.opacity(0.05)
    static let activeGreen = Color(hex: "79D49E")
}

private extension View {
    func sfProRounded(size: CGFloat, weight: Font.Weight = .regular) -> some View {
        font(.system(size: size, weight: weight, design: .rounded))
    }
}

struct TribeScreenBackground: View {
    var body: some View {
        ZStack {
            TribeAuraPalette.canvas

            Circle()
                .fill(TribeAuraPalette.mint.opacity(0.18))
                .frame(width: 280, height: 280)
                .blur(radius: 90)
                .offset(x: -118, y: -250)

            Circle()
                .fill(TribeAuraPalette.beige.opacity(0.18))
                .frame(width: 320, height: 320)
                .blur(radius: 92)
                .offset(x: 132, y: -110)

            Circle()
                .fill(TribeAuraPalette.azure.opacity(0.20))
                .frame(width: 360, height: 360)
                .blur(radius: 100)
                .offset(x: 40, y: 280)
        }
        .ignoresSafeArea()
    }
}

struct TribeTopSegmentedControl: View {
    @Binding var selection: TribeDashboardTab

    var body: some View {
        HStack(spacing: 6) {
            ForEach(TribeDashboardTab.allCases) { tab in
                let isSelected = selection == tab

                Button {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        selection = tab
                    }
                } label: {
                    Text(tab.title)
                        .sfProRounded(size: 13, weight: isSelected ? .medium : .light)
                        .foregroundStyle(isSelected ? TribeAuraPalette.textPrimary : TribeAuraPalette.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background {
                            Capsule(style: .continuous)
                                .fill(isSelected ? Color.white.opacity(0.72) : Color.clear)
                                .overlay {
                                    Capsule(style: .continuous)
                                        .stroke(isSelected ? TribeAuraPalette.materialBorder : .clear, lineWidth: 0.8)
                                }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .background {
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(TribeAuraPalette.materialBorder, lineWidth: 0.8)
                }
        }
        .shadow(color: TribeAuraPalette.controlShadow, radius: 10, x: 0, y: 5)
        .sensoryFeedback(.selection, trigger: selection)
    }
}

struct LegacyTribeView: View {
    let heroSummary: TribeSummary
    let featuredMembers: [TribeRingMember]
    let onRefresh: @Sendable () async -> Void

    @State private var selectedMemberID: String?

    private var ringLayers: [TribeAtomRingLayer] {
        featuredMembers.atomRingLayers(selectedMemberID: selectedMemberID)
    }

    private var featuredMemberKeys: [String] {
        featuredMembers.map(selectionKey(for:))
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 24) {
                TribeHeroSummaryCard(
                    summary: heroSummary,
                    ringLayers: ringLayers
                )

                TribeMembersSection(
                    featuredMembers: featuredMembers,
                    selectedMemberID: selectedMemberID,
                    onSelectMember: selectMember
                )
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .contentMargins(.top, 0, for: .scrollContent)
        .contentMargins(.top, 0, for: .scrollIndicators)
        .refreshable {
            await onRefresh()
        }
        .onChange(of: featuredMemberKeys, initial: false) { _, memberKeys in
            guard let selectedMemberID, memberKeys.contains(selectedMemberID) == false else { return }
            self.selectedMemberID = nil
        }
    }

    private func selectMember(_ member: TribeRingMember) {
        guard member.isVacant == false else { return }

        let memberKey = selectionKey(for: member)
        withAnimation(.spring(response: 0.36, dampingFraction: 0.84)) {
            selectedMemberID = selectedMemberID == memberKey ? nil : memberKey
        }
    }

    private func selectionKey(for member: TribeRingMember) -> String {
        member.memberId ?? member.id
    }
}

private struct TribeHeroSummaryCard: View {
    let summary: TribeSummary
    let ringLayers: [TribeAtomRingLayer]

    private var selectedLayer: TribeAtomRingLayer? {
        ringLayers.first(where: \.isSelected)
    }

    private var progressValue: String {
        summary.progressValue.isEmpty ? "84%" : summary.progressValue
    }

    private var selectionBadgeText: String? {
        guard let selectedLayer, selectedLayer.isVacant == false else { return nil }
        return "\(selectedLayer.memberName) • \(selectedLayer.layerName)"
    }

    var body: some View {
        TribeSurfaceCard(
            accent: selectedLayer?.accentColor ?? TribeModernPalette.mint,
            padding: 20,
            cornerRadius: 34
        ) {
            HStack(alignment: .center, spacing: 18) {
                TribeAtomRingView(layers: ringLayers, size: 132)
                    .frame(width: 132, height: 132)

                VStack(alignment: .trailing, spacing: 14) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(summary.eyebrow)
                                .sfProRounded(size: 11, weight: .medium)
                                .foregroundStyle(TribeModernPalette.textSecondary)

                            Text(summary.title)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(TribeModernPalette.textPrimary)
                                .multilineTextAlignment(.trailing)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(progressValue)
                                .font(.system(size: 31, weight: .bold, design: .rounded))
                                .foregroundStyle(TribeModernPalette.textPrimary)
                                .monospacedDigit()
                                .minimumScaleFactor(0.8)

                            Text(summary.progressLabel)
                                .sfProRounded(size: 11, weight: .medium)
                                .foregroundStyle(TribeModernPalette.textTertiary)
                        }
                    }

                    Text(summary.summary)
                        .sfProRounded(size: 12, weight: .light)
                        .foregroundStyle(TribeModernPalette.textSecondary)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(3)

                    HStack(spacing: 8) {
                        Spacer(minLength: 0)

                        TribeHeroBadge(text: summary.memberBadge, tint: TribeModernPalette.mint)

                        if let selectionBadgeText {
                            TribeHeroBadge(
                                text: selectionBadgeText,
                                tint: selectedLayer?.accentColor ?? TribeModernPalette.sky
                            )
                        }
                    }
                }
            }
            .environment(\.layoutDirection, .leftToRight)
        }
    }
}

private struct TribeHeroBadge: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .sfProRounded(size: 11, weight: .medium)
            .foregroundStyle(TribeModernPalette.textPrimary)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                tint.opacity(0.18),
                                TribeModernPalette.surfaceTop.opacity(0.92)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(tint.opacity(0.24), lineWidth: 0.8)
                    }
            }
    }
}

struct TribeMembersSection: View {
    let featuredMembers: [TribeRingMember]
    let selectedMemberID: String?
    let onSelectMember: (TribeRingMember) -> Void

    var body: some View {
        VStack(alignment: .trailing, spacing: 14) {
            Text("الحضور")
                .sfProRounded(size: 11, weight: .light)
                .foregroundStyle(TribeAuraPalette.textTertiary)
                .frame(maxWidth: .infinity, alignment: .trailing)

            LazyVStack(spacing: 12) {
                ForEach(featuredMembers) { featuredMember in
                    TribeMemberCardCompact(
                        featuredMember: featuredMember,
                        isSelected: selectedMemberID == (featuredMember.memberId ?? featuredMember.id),
                        onTap: {
                            onSelectMember(featuredMember)
                        }
                    )
                }
            }
        }
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
        TribeMemberCardMaterial {
            VStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.large)
                    .tint(TribeAuraPalette.mint)

                Text("جارٍ تهيئة توهج القبيلة")
                    .sfProRounded(size: 17, weight: .medium)
                    .foregroundStyle(TribeAuraPalette.textPrimary)

                Text("نرتب الحضور بهدوء قبل ظهور المشهد.")
                    .sfProRounded(size: 13, weight: .light)
                    .foregroundStyle(TribeAuraPalette.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct TribeMemberCardCompact: View {
    let featuredMember: TribeRingMember
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            TribeMemberCardMaterial(
                accent: featuredMember.accentColor,
                isSelected: isSelected
            ) {
                HStack(spacing: 16) {
                    VStack(alignment: .trailing, spacing: 9) {
                        Text(featuredMember.displayName)
                            .sfProRounded(size: 16, weight: .medium)
                            .foregroundStyle(TribeAuraPalette.textPrimary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .trailing)

                        HStack(spacing: 6) {
                            Text(featuredMember.roleTitle)
                            if featuredMember.isVacant == false {
                                Text("•")
                                Text(featuredMember.levelText)
                            }
                        }
                        .sfProRounded(size: 12, weight: .light)
                        .foregroundStyle(TribeAuraPalette.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                        HStack(spacing: 8) {
                            TribeMemberMetaBadge(
                                text: featuredMember.segmentLabel,
                                tint: featuredMember.accentColor,
                                emphasized: true
                            )

                            TribeMemberMetaBadge(
                                text: featuredMember.isVacant
                                    ? featuredMember.contributionLabel
                                    : "\(featuredMember.contributionValue) طاقة",
                                tint: featuredMember.accentColor,
                                emphasized: false
                            )
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }

                    Spacer(minLength: 14)

                    TribeMemberEnergyAvatar(
                        featuredMember: featuredMember,
                        tint: featuredMember.accentColor,
                        isActive: featuredMember.energyToday > 0
                    )
                }
                .environment(\.layoutDirection, .leftToRight)
                .accessibilityElement(children: .combine)
            }
        }
        .buttonStyle(.plain)
        .disabled(featuredMember.isVacant)
    }
}

private struct TribeMemberCardMaterial<Content: View>: View {
    private let accent: Color?
    private let isSelected: Bool
    private let content: Content

    init(
        accent: Color? = nil,
        isSelected: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.accent = accent
        self.isSelected = isSelected
        self.content = content()
    }

    var body: some View {
        content
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.regularMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(Color.white.opacity(0.56))
                    }
                    .overlay {
                        if let accent {
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            accent.opacity(isSelected ? 0.14 : 0.06),
                                            Color.clear,
                                            accent.opacity(isSelected ? 0.08 : 0.03)
                                        ],
                                        startPoint: .topTrailing,
                                        endPoint: .bottomLeading
                                    )
                                )
                        }
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(
                                (accent?.opacity(isSelected ? 0.34 : 0.12) ?? TribeAuraPalette.materialBorder),
                                lineWidth: isSelected ? 1.1 : 0.8
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(Color.black.opacity(0.03), lineWidth: 0.8)
                            .padding(0.5)
                    }
            }
            .shadow(
                color: (accent?.opacity(isSelected ? 0.14 : 0.06) ?? TribeAuraPalette.cardShadow),
                radius: isSelected ? 16 : 12,
                x: 0,
                y: isSelected ? 10 : 7
            )
            .scaleEffect(isSelected ? 1.01 : 1)
            .animation(.spring(response: 0.34, dampingFraction: 0.84), value: isSelected)
    }
}

private struct TribeMemberMetaBadge: View {
    let text: String
    let tint: Color
    let emphasized: Bool

    var body: some View {
        Text(text)
            .sfProRounded(size: 11, weight: emphasized ? .medium : .light)
            .foregroundStyle(emphasized ? TribeModernPalette.textPrimary : TribeModernPalette.textSecondary)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                Capsule(style: .continuous)
                    .fill(emphasized ? tint.opacity(0.16) : Color.white.opacity(0.56))
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(
                                emphasized ? tint.opacity(0.24) : TribeModernPalette.border.opacity(0.72),
                                lineWidth: 0.8
                            )
                    }
            }
    }
}

private struct TribeMemberEnergyAvatar: View {
    let featuredMember: TribeRingMember
    let tint: Color
    let isActive: Bool

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            ZStack {
                Circle()
                    .fill(Color.white)

                Text(featuredMember.isVacant ? "+" : featuredMember.displayName.tribeDisplayInitials)
                    .sfProRounded(size: 16, weight: .light)
                    .foregroundStyle(TribeAuraPalette.textPrimary)
            }
            .frame(width: 58, height: 58)
            .overlay {
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                tint.opacity(0.96),
                                tint.opacity(0.40)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.8
                    )
            }
            .overlay {
                Circle()
                    .strokeBorder(tint.opacity(0.30), lineWidth: 8)
                    .blur(radius: 9)
            }
            .shadow(color: tint.opacity(0.16), radius: 10, x: 0, y: 5)

            if isActive {
                TribeActivePulseDot()
                    .offset(x: -2, y: -2)
            }
        }
    }
}

private struct TribeActivePulseDot: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            Circle()
                .fill(TribeAuraPalette.activeGreen.opacity(0.20))
                .frame(width: 18, height: 18)
                .scaleEffect(reduceMotion ? 1 : (isAnimating ? 1.20 : 0.76))
                .opacity(reduceMotion ? 0.45 : (isAnimating ? 0.18 : 0.42))

            Circle()
                .fill(TribeAuraPalette.activeGreen)
                .frame(width: 8, height: 8)
                .overlay {
                    Circle()
                        .stroke(Color.white, lineWidth: 2.4)
                }
        }
        .onAppear {
            guard reduceMotion == false, isAnimating == false else { return }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                isAnimating = true
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
