import SwiftUI

struct TribeHubView: View {
    let tribe: Tribe?
    let members: [TribeMember]
    let missions: [TribeMission]
    let currentMemberId: String?
    @Binding var privacyMode: PrivacyMode
    let presentationMode: Bool
    let onOpenGalaxy: () -> Void
    let onSpark: (TribeMember) -> Void

    private var visibleMembers: [TribeMember] {
        Array(members.prefix(presentationMode ? 5 : 8))
    }

    private var energyCurrent: Int {
        members.reduce(0) { $0 + $1.auraEnergyToday }
    }

    private var energyTarget: Int {
        max(missions.first?.targetValue ?? 500, 1)
    }

    private var energyStatusLine: String {
        let remaining = max(energyTarget - energyCurrent, 0)
        if remaining == 0 {
            return "tribe.hub.energy.complete".localized
        }

        return String(
            format: "tribe.hub.energy.remaining".localized,
            locale: Locale.current,
            remaining
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TribeEnergyCoreCard(
                progressValue: energyCurrent,
                targetValue: energyTarget,
                headline: "tribe.hub.energy.title".localized,
                statusLine: energyStatusLine
            )

            TribeGlassCard(cornerRadius: 28, padding: 16, tint: TribePalette.surfaceMint) {
                HStack(spacing: 14) {
                    CircularTribeButtonView(onTap: onOpenGalaxy)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("tribe.hub.enterGalaxy".localized)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(TribePalette.textPrimary)

                        Text("tribe.hub.enterGalaxy.subtitle".localized)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(TribePalette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
            }
            .onTapGesture(perform: onOpenGalaxy)

            TribeGlassCard(cornerRadius: 28, padding: 16, tint: TribePalette.surfaceSand) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(tribe?.name ?? "tribe.mock.name".localized)
                                .font(.system(size: 21, weight: .bold, design: .rounded))
                                .foregroundStyle(TribePalette.textPrimary)

                            Text(
                                String(
                                    format: "tribe.hub.inviteCode".localized,
                                    locale: Locale.current,
                                    tribe?.inviteCode ?? "AIQO30"
                                )
                            )
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(TribePalette.textSecondary)
                        }

                        Spacer(minLength: 0)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("tribe.hub.privacy".localized)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(TribePalette.textSecondary)

                        TribeSegmentedPill(
                            options: PrivacyMode.allCases,
                            selection: $privacyMode,
                            title: { $0.title }
                        )
                    }
                }
            }

            if !missions.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("tribe.hub.missions".localized)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(TribePalette.textPrimary)

                    ForEach(Array(missions.prefix(2))) { mission in
                        TribeGlassCard(cornerRadius: 24, padding: 14, tint: TribePalette.surfaceSand) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(mission.title)
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundStyle(TribePalette.textPrimary)

                                ProgressView(
                                    value: Double(min(mission.progressValue, mission.targetValue)),
                                    total: Double(max(mission.targetValue, 1))
                                )
                                .tint(TribePalette.progressFill)

                                HStack {
                                    Text("\(mission.progressValue.formatted())/\(mission.targetValue.formatted())")
                                    Spacer()
                                    Text(mission.endsAt, style: .relative)
                                }
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(TribePalette.textSecondary)
                            }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("tribe.hub.members".localized)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(TribePalette.textPrimary)

                ForEach(visibleMembers) { member in
                    TribeGlassCard(cornerRadius: 24, padding: 14, tint: TribePalette.surfaceMint) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(TribePalette.iconBadge)
                                    .frame(width: 46, height: 46)

                                if member.visibility == .public {
                                    Text(member.resolvedInitials)
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundStyle(TribePalette.textPrimary)
                                } else {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(TribePalette.textSecondary)
                                }
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(member.visibility == .public ? member.visibleDisplayName : "tribe.member.anonymous".localized)
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundStyle(TribePalette.textPrimary)

                                Text(
                                    String(
                                        format: "tribe.member.level".localized,
                                        locale: Locale.current,
                                        member.level
                                    )
                                )
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(TribePalette.textSecondary)
                            }

                            Spacer(minLength: 10)

                            if member.visibility == .public {
                                Text("+\(member.auraEnergyToday)")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(TribePalette.textPrimary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(TribePalette.chip))
                            }

                            Button {
                                onSpark(member)
                            } label: {
                                Text("tribe.action.spark".localized)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(TribePalette.textPrimary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Capsule().fill(TribePalette.actionPrimary))
                            }
                            .buttonStyle(.plain)
                            .disabled(member.id == currentMemberId)
                            .opacity(member.id == currentMemberId ? 0.45 : 1)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        String(
                            format: "tribe.member.accessibility".localized,
                            locale: Locale.current,
                            member.visibleDisplayName,
                            member.level
                        )
                    )
                }
            }
        }
    }
}
