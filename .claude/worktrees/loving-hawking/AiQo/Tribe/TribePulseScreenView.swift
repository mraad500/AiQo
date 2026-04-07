import SwiftUI

private extension View {
    func tribeRoundedFont(size: CGFloat, weight: Font.Weight = .regular) -> some View {
        font(.system(size: size, weight: weight, design: .rounded))
    }
}

struct TribePulseScreenView: View {
    let heroSummary: TribeSummary
    let featuredMembers: [TribeRingMember]
    let onRefresh: @Sendable () async -> Void

    @State private var selectedMemberID: String?

    private var listMembers: [TribeRingMember] {
        featuredMembers.filter { $0.isVacant == false }
    }

    private var activeMemberCount: Int {
        listMembers.filter { $0.energyToday > 0 }.count
    }

    private var totalEnergyText: String {
        listMembers.reduce(0) { $0 + $1.energyToday }.formatted(.number.grouping(.automatic))
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 18) {
                TribePulseHeroCard(
                    summary: heroSummary,
                    members: featuredMembers,
                    selectedMemberID: selectedMemberID,
                    onSelectMember: selectMember
                )

                HStack(spacing: 10) {
                    TribeMetricPill(
                        title: NSLocalizedString("pulse.harmony", comment: ""),
                        value: resolvedProgressValue,
                        tint: TribeModernPalette.mint
                    )

                    TribeMetricPill(
                        title: NSLocalizedString("pulse.members", comment: ""),
                        value: "\(activeMemberCount)",
                        tint: TribeModernPalette.sand
                    )

                    TribeMetricPill(
                        title: NSLocalizedString("pulse.energy", comment: ""),
                        value: totalEnergyText,
                        tint: TribeModernPalette.lavender
                    )
                }

                TribePulseMembersSection(
                    members: listMembers,
                    selectedMemberID: selectedMemberID,
                    onSelectMember: selectMember
                )
            }
            .padding(.horizontal, TribePremiumTokens.horizontalPadding)
            .padding(.top, 14)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .contentMargins(.top, 0, for: .scrollContent)
        .contentMargins(.top, 0, for: .scrollIndicators)
        .refreshable {
            await onRefresh()
        }
        .onChange(of: listMembers.map(selectionKey(for:))) { _, memberKeys in
            guard let selectedMemberID, memberKeys.contains(selectedMemberID) == false else { return }
            self.selectedMemberID = nil
        }
    }

    private var resolvedProgressValue: String {
        heroSummary.progressValue.isEmpty ? "84%" : heroSummary.progressValue
    }

    private func selectMember(_ member: TribeRingMember) {
        guard member.isVacant == false else { return }

        let memberKey = selectionKey(for: member)
        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
            selectedMemberID = selectedMemberID == memberKey ? nil : memberKey
        }
    }

    private func selectionKey(for member: TribeRingMember) -> String {
        member.memberId ?? member.id
    }
}

struct TribePulseHeroCard: View {
    let summary: TribeSummary
    let members: [TribeRingMember]
    let selectedMemberID: String?
    let onSelectMember: (TribeRingMember) -> Void

    private var selectedMember: TribeRingMember? {
        members.first(where: { selectionKey(for: $0) == selectedMemberID })
    }

    private var activeMemberCount: Int {
        members.filter { $0.isVacant == false && $0.energyToday > 0 }.count
    }

    private var progressValue: String {
        summary.progressValue.isEmpty ? "84%" : summary.progressValue
    }

    private var heroAccent: Color {
        selectedMember?.accentColor ?? TribeModernPalette.mintDeep
    }

    var body: some View {
        TribeSurfaceCard(accent: heroAccent, padding: 22, cornerRadius: 36) {
            HStack(alignment: .center, spacing: 18) {
                OrbitalHaloView(
                    members: members,
                    selectedMemberID: selectedMemberID,
                    onSelectMember: onSelectMember
                )
                .frame(width: 150, height: 168)

                VStack(alignment: .trailing, spacing: 12) {
                    HStack(spacing: 8) {
                        if let selectedMember, selectedMember.isVacant == false {
                            TribePulseTag(text: selectedMember.compactSectorLabel, tint: selectedMember.accentColor)
                        }

                        TribePulseTag(text: NSLocalizedString("pulse.tribePulse", comment: ""), tint: TribeModernPalette.mint)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)

                    Text(summary.title)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(TribeModernPalette.textPrimary)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    Text(String(format: NSLocalizedString("pulse.todayHarmony", comment: ""), progressValue))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(TribeModernPalette.textPrimary)
                        .monospacedDigit()
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    if activeMemberCount > 0 {
                        Text(String(format: NSLocalizedString("pulse.activeMembers", comment: ""), activeMemberCount))
                            .tribeRoundedFont(size: 12, weight: .medium)
                            .foregroundStyle(TribeModernPalette.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: 150, alignment: .trailing)
            }
            .environment(\.layoutDirection, .leftToRight)
        }
    }

    private func selectionKey(for member: TribeRingMember) -> String {
        member.memberId ?? member.id
    }
}

struct OrbitalHaloView: View {
    let members: [TribeRingMember]
    let selectedMemberID: String?
    let onSelectMember: (TribeRingMember) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAnimating = false

    private let centerAngles: [Double] = [-142, -74, -4, 84, 154]
    private let baseLengths: [Double] = [38, 34, 42, 36, 40]
    private let radiusRatios: [CGFloat] = [0.84, 0.71, 0.92, 0.78, 0.64]
    private let thicknesses: [CGFloat] = [9, 11, 8, 10, 9]

    private var resolvedMembers: [TribeRingMember] {
        let membersBySector = Dictionary(uniqueKeysWithValues: members.map { ($0.sectorColor, $0) })
        return TribeSectorColor.memberDisplayOrder.enumerated().map { index, sectorColor in
            membersBySector[sectorColor] ?? TribeRingMember(slot: index + 1, sectorColor: sectorColor)
        }
    }

    private var segments: [OrbitalHaloSegment] {
        let maxEnergy = max(resolvedMembers.map(\.energyToday).max() ?? 1, 1)

        return resolvedMembers.enumerated().map { index, member in
            let normalizedEnergy = member.isVacant ? 0.18 : CGFloat(member.energyToday) / CGFloat(maxEnergy)
            let length = baseLengths[index] + Double(normalizedEnergy) * 18
            let centerAngle = centerAngles[index]

            return OrbitalHaloSegment(
                member: member,
                startAngle: .degrees(centerAngle - (length / 2)),
                endAngle: .degrees(centerAngle + (length / 2)),
                radiusRatio: radiusRatios[index],
                lineWidth: thicknesses[index] + (selectionKey(for: member) == selectedMemberID ? 1.3 : 0),
                interactionAngle: .degrees(centerAngle)
            )
        }
    }

    private var hasSelection: Bool {
        selectedMemberID != nil
    }

    private var selectedAccent: Color {
        segments.first(where: { selectionKey(for: $0.member) == selectedMemberID })?.member.accentColor ?? TribeModernPalette.mint
    }

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)

            ZStack {
                ambientGlow(size: size)

                ForEach(segments) { segment in
                    haloSegment(segment, size: size)
                }

                calmCore(size: size)

                ForEach(segments) { segment in
                    haloTapTarget(segment, size: size)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .scaleEffect(reduceMotion ? 1 : (isAnimating ? 1.012 : 0.988))
            .offset(
                x: reduceMotion ? 0 : (isAnimating ? 1.4 : -1.1),
                y: reduceMotion ? 0 : (isAnimating ? -1.2 : 1.0)
            )
        }
        .drawingGroup(opaque: false, colorMode: .extendedLinear)
        .onAppear {
            guard reduceMotion == false, isAnimating == false else { return }
            withAnimation(.easeInOut(duration: 7.0).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("نبض القبيلة")
    }

    private func ambientGlow(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(selectedAccent.opacity(0.12))
                .frame(width: size * 0.64, height: size * 0.64)
                .blur(radius: size * 0.12)

            Circle()
                .fill(TribeModernPalette.sand.opacity(0.10))
                .frame(width: size * 0.34, height: size * 0.34)
                .offset(x: size * 0.10, y: size * 0.12)
                .blur(radius: size * 0.07)

            Circle()
                .fill(TribeModernPalette.lavender.opacity(0.08))
                .frame(width: size * 0.24, height: size * 0.24)
                .offset(x: -size * 0.14, y: -size * 0.10)
                .blur(radius: size * 0.06)
        }
    }

    private func calmCore(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(selectedAccent.opacity(0.16))
                .frame(width: size * 0.30, height: size * 0.30)
                .blur(radius: size * 0.08)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.98),
                            TribeModernPalette.surfaceBottom
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size * 0.34, height: size * 0.34)
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.78), lineWidth: 1)
                }
                .overlay {
                    Circle()
                        .stroke(selectedAccent.opacity(hasSelection ? 0.22 : 0.14), lineWidth: size * 0.05)
                        .blur(radius: size * 0.05)
                }

            Circle()
                .fill(TribeModernPalette.backgroundWhiteGlow)
                .frame(width: size * 0.07, height: size * 0.07)
        }
    }

    private func haloSegment(_ segment: OrbitalHaloSegment, size: CGFloat) -> some View {
        let isSelected = selectionKey(for: segment.member) == selectedMemberID
        let accent = segment.member.accentColor
        let opacity = segment.member.isVacant
            ? 0.20
            : (hasSelection ? (isSelected ? 0.84 : 0.24) : 0.54)
        let glowOpacity = segment.member.isVacant
            ? 0.04
            : (isSelected ? 0.24 : 0.10)

        return ZStack {
            OrbitalArcShape(
                startAngle: segment.startAngle,
                endAngle: segment.endAngle,
                radiusRatio: segment.radiusRatio
            )
            .stroke(
                accent.opacity(glowOpacity),
                style: StrokeStyle(lineWidth: segment.lineWidth + 8, lineCap: .round)
            )
            .blur(radius: 8)

            OrbitalArcShape(
                startAngle: segment.startAngle,
                endAngle: segment.endAngle,
                radiusRatio: segment.radiusRatio
            )
            .stroke(
                LinearGradient(
                    colors: [
                        Color.white.opacity(segment.member.isVacant ? 0.14 : 0.22),
                        accent.opacity(opacity),
                        accent.opacity(opacity * 0.78)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                style: StrokeStyle(lineWidth: segment.lineWidth, lineCap: .round)
            )
        }
        .frame(width: size, height: size)
    }

    private func haloTapTarget(_ segment: OrbitalHaloSegment, size: CGFloat) -> some View {
        let point = interactionPoint(for: segment, size: size)

        return Button {
            onSelectMember(segment.member)
        } label: {
            Circle()
                .fill(Color.white.opacity(0.001))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .disabled(segment.member.isVacant)
        .position(point)
        .accessibilityLabel(segment.member.displayName)
    }

    private func interactionPoint(for segment: OrbitalHaloSegment, size: CGFloat) -> CGPoint {
        let radians = Double(segment.interactionAngle.radians)
        let radius = (size * segment.radiusRatio) * 0.5

        return CGPoint(
            x: (size * 0.5) + (CGFloat(cos(radians)) * radius),
            y: (size * 0.5) + (CGFloat(sin(radians)) * radius)
        )
    }

    private func selectionKey(for member: TribeRingMember) -> String {
        member.memberId ?? member.id
    }
}

struct TribeMetricPill: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(title)
                .tribeRoundedFont(size: 11, weight: .medium)
                .foregroundStyle(TribeModernPalette.textSecondary)

            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(TribeModernPalette.textPrimary)
                .monospacedDigit()
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.thinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.white.opacity(0.56))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    tint.opacity(0.10),
                                    Color.clear
                                ],
                                startPoint: .topTrailing,
                                endPoint: .bottomLeading
                            )
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(tint.opacity(0.16), lineWidth: 0.9)
                }
        }
    }
}

struct TribeMemberCard: View {
    let featuredMember: TribeRingMember
    let isSelected: Bool
    let isMuted: Bool
    let appearIndex: Int
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 18) {
                energyColumn

                VStack(alignment: .trailing, spacing: 12) {
                    VStack(alignment: .trailing, spacing: 6) {
                        Text(featuredMember.displayName)
                            .font(.system(size: 19, weight: .bold, design: .rounded))
                            .foregroundStyle(TribeModernPalette.textPrimary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .trailing)

                        Text(featuredMember.roleTitle)
                            .tribeRoundedFont(size: 12, weight: .medium)
                            .foregroundStyle(TribeModernPalette.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }

                    HStack(spacing: 8) {
                        TribeMemberChip(
                            text: featuredMember.compactSectorLabel,
                            tint: featuredMember.accentColor,
                            emphasized: true
                        )

                        TribeMemberChip(
                            text: featuredMember.compactLevelLabel,
                            tint: TribeModernPalette.sand,
                            emphasized: false
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .environment(\.layoutDirection, .leftToRight)
                .accessibilityElement(children: .combine)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(.regularMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .fill(Color.white.opacity(0.72))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        featuredMember.accentColor.opacity(isSelected ? 0.12 : 0.05),
                                        Color.clear,
                                        TribeModernPalette.accentFlash
                                    ],
                                    startPoint: .topTrailing,
                                    endPoint: .bottomLeading
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .stroke(
                                featuredMember.accentColor.opacity(isSelected ? 0.24 : 0.11),
                                lineWidth: isSelected ? 1.1 : 0.9
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .stroke(Color.white.opacity(0.56), lineWidth: 0.8)
                            .padding(1)
                    }
            }
            .overlay(alignment: .trailing) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(featuredMember.accentColor.opacity(isSelected ? 0.76 : 0.42))
                    .frame(width: 5)
                    .padding(.vertical, 16)
                    .padding(.trailing, 11)
            }
            .shadow(
                color: featuredMember.accentColor.opacity(isSelected ? 0.12 : 0.05),
                radius: isSelected ? 16 : 12,
                x: 0,
                y: isSelected ? 10 : 8
            )
        }
        .buttonStyle(.plain)
        .opacity(hasAppeared ? (isMuted ? 0.56 : 1) : 0)
        .scaleEffect(hasAppeared ? (isSelected ? 1.01 : 1) : 0.985)
        .offset(y: hasAppeared ? 0 : 14)
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: isSelected)
        .animation(.easeInOut(duration: 0.22), value: isMuted)
        .onAppear {
            guard hasAppeared == false else { return }

            if reduceMotion {
                hasAppeared = true
            } else {
                withAnimation(.spring(response: 0.56, dampingFraction: 0.88).delay(Double(appearIndex) * 0.045)) {
                    hasAppeared = true
                }
            }
        }
    }

    private var energyColumn: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(featuredMember.energyValueText)
                .font(.system(size: 31, weight: .bold, design: .rounded))
                .foregroundStyle(TribeModernPalette.textPrimary)
                .monospacedDigit()
                .minimumScaleFactor(0.8)

            Text(NSLocalizedString("pulse.energy", comment: ""))
                .tribeRoundedFont(size: 11, weight: .medium)
                .foregroundStyle(TribeModernPalette.textSecondary)
        }
        .frame(minWidth: 82, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(featuredMember.accentColor.opacity(isSelected ? 0.15 : 0.09))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(featuredMember.accentColor.opacity(isSelected ? 0.22 : 0.12), lineWidth: 0.9)
                }
        }
    }
}

private struct TribePulseMembersSection: View {
    let members: [TribeRingMember]
    let selectedMemberID: String?
    let onSelectMember: (TribeRingMember) -> Void

    var body: some View {
        VStack(alignment: .trailing, spacing: 14) {
            HStack(spacing: 8) {
                Text("\(members.count)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(TribeModernPalette.textPrimary)
                    .monospacedDigit()
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.72), in: Capsule(style: .continuous))

                Text(NSLocalizedString("pulse.members", comment: ""))
                    .tribeRoundedFont(size: 12, weight: .medium)
                    .foregroundStyle(TribeModernPalette.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)

            LazyVStack(spacing: 14) {
                ForEach(Array(members.enumerated()), id: \.element.id) { index, member in
                    let memberKey = member.memberId ?? member.id

                    TribeMemberCard(
                        featuredMember: member,
                        isSelected: selectedMemberID == memberKey,
                        isMuted: selectedMemberID != nil && selectedMemberID != memberKey,
                        appearIndex: index,
                        onTap: {
                            onSelectMember(member)
                        }
                    )
                }
            }
        }
    }
}

private struct TribePulseTag: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .tribeRoundedFont(size: 11, weight: .semibold)
            .foregroundStyle(TribeModernPalette.textPrimary)
            .lineLimit(1)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background {
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.14))
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(tint.opacity(0.20), lineWidth: 0.8)
                    }
            }
    }
}

private struct TribeMemberChip: View {
    let text: String
    let tint: Color
    let emphasized: Bool

    var body: some View {
        Text(text)
            .tribeRoundedFont(size: 11, weight: emphasized ? .semibold : .medium)
            .foregroundStyle(TribeModernPalette.textPrimary)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                Capsule(style: .continuous)
                    .fill(emphasized ? tint.opacity(0.14) : Color.white.opacity(0.64))
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(
                                emphasized ? tint.opacity(0.18) : TribeModernPalette.border.opacity(0.90),
                                lineWidth: 0.8
                            )
                    }
            }
    }
}

private struct OrbitalHaloSegment: Identifiable {
    let member: TribeRingMember
    let startAngle: Angle
    let endAngle: Angle
    let radiusRatio: CGFloat
    let lineWidth: CGFloat
    let interactionAngle: Angle

    var id: String {
        member.id
    }
}

private struct OrbitalArcShape: Shape {
    let startAngle: Angle
    let endAngle: Angle
    let radiusRatio: CGFloat

    func path(in rect: CGRect) -> Path {
        let size = min(rect.width, rect.height)
        let radius = (size * radiusRatio) * 0.5
        let center = CGPoint(x: rect.midX, y: rect.midY)

        var path = Path()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        return path
    }
}

#Preview {
    let members = TribePreviewData.sampleMembers()
        .prefix(5)
        .enumerated()
        .map { index, member in
            TribeRingMember(
                member: member,
                sectorColor: TribeSectorColor.memberDisplayOrder[index],
                isCurrentUser: index == 0
            )
        }

    ZStack {
        TribeScreenBackground()
        TribePulseScreenView(
            heroSummary: TribeSummary(
                eyebrow: "Tribe Pulse",
                title: "قبيلة الهدوء",
                summary: "",
                memberBadge: "5 أعضاء",
                progress: 0.84,
                progressValue: "84%",
                progressLabel: "انسجام",
                ringSegmentTarget: 100
            ),
            featuredMembers: members,
            onRefresh: { }
        )
    }
}
