import SwiftUI

struct TribeArenaView: View {
    @ObservedObject var store: ArenaStore
    let members: [TribeMember]
    let presentationMode: Bool
    let onContribute: (TribeChallenge) -> Void

    @State private var isComposerPresented = false

    private var activeChallenge: TribeChallenge? {
        store.challenges.first(where: { $0.id == store.activeChallengeId }) ??
        store.featuredGalaxyChallenges(for: store.selectedCadence).first
    }

    private var sectionScopes: [ChallengeScope] {
        [.personal, .tribe, .galaxy]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("tribe.arena.title".localized)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(TribePalette.textPrimary)

                    Text("tribe.arena.subtitle".localized)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(TribePalette.textSecondary)
                }

                Spacer(minLength: 12)

                Button {
                    isComposerPresented = true
                } label: {
                    Text("tribe.arena.newChallenge".localized)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(TribePalette.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(TribePalette.actionPrimary))
                }
                .buttonStyle(.plain)
            }

            TribeSegmentedPill(
                options: ChallengeCadence.allCases,
                selection: $store.selectedCadence,
                title: { $0.title }
            )

            Toggle(isOn: $store.showOnlyMyTribe) {
                Text("tribe.arena.filter.myTribe".localized)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(TribePalette.textSecondary)
            }
            .tint(TribePalette.progressFill)

            featuredChallenges

            if let activeChallenge {
                leaderboardCard(for: activeChallenge)
            }

            ForEach(sectionScopes) { scope in
                let challenges = store.challenges(for: store.selectedCadence, scope: scope)
                VStack(alignment: .leading, spacing: 10) {
                    Text(scope.title)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(TribePalette.textPrimary)

                    if challenges.isEmpty {
                        TribeGlassCard(cornerRadius: 22, padding: 14, tint: TribePalette.surfaceMint) {
                            Text(
                                scope == .galaxy && store.showOnlyMyTribe
                                ? "tribe.arena.empty.filteredGalaxy".localized
                                : "tribe.arena.empty".localized
                            )
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(TribePalette.textSecondary)
                        }
                    } else {
                        ForEach(challenges.prefix(presentationMode ? 2 : 4)) { challenge in
                            challengeCard(for: challenge)
                        }
                    }
                }
            }

            if !store.pendingSuggestions.isEmpty {
                TribeGlassCard(cornerRadius: 24, padding: 14, tint: TribePalette.surfaceSand) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("tribe.arena.suggestions".localized)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(TribePalette.textPrimary)

                        ForEach(store.pendingSuggestions.prefix(3)) { suggestion in
                            Text("• \(suggestion.title) • \(suggestion.cadence.title)")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(TribePalette.textSecondary)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $isComposerPresented) {
            ArenaComposerSheet(store: store)
                .presentationDetents([.medium, .large])
        }
    }

    private var featuredChallenges: some View {
        let curated = store.featuredGalaxyChallenges(for: store.selectedCadence)

        return VStack(alignment: .leading, spacing: 10) {
            Text(store.selectedCadence.sectionTitle)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(TribePalette.textPrimary)

            ForEach(curated.prefix(presentationMode ? 2 : 3)) { challenge in
                challengeCard(for: challenge, isFeatured: true)
            }
        }
    }

    private func challengeCard(for challenge: TribeChallenge, isFeatured: Bool = false) -> some View {
        let isActive = challenge.id == store.activeChallengeId

        return TribeGlassCard(
            cornerRadius: 24,
            padding: 14,
            tint: isActive || isFeatured ? TribePalette.surfaceSand : TribePalette.surfaceMint
        ) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(challenge.title)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(TribePalette.textPrimary)

                        if !challenge.subtitle.isEmpty {
                            Text(challenge.subtitle)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(TribePalette.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Spacer(minLength: 10)

                    Text(challenge.scope.title)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(TribePalette.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(TribePalette.chip))
                }

                ProgressView(value: challenge.progress)
                    .tint(TribePalette.progressFill)

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(challenge.progressSummary.valueText)
                        Text(challenge.remainingText)
                    }
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(TribePalette.textSecondary)

                    Spacer(minLength: 10)

                    Text(challenge.timeRemainingText())
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(TribePalette.textSecondary)
                }

                HStack(spacing: 10) {
                    Button {
                        store.setActiveChallenge(challenge)
                    } label: {
                        Text("tribe.action.view".localized)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(TribePalette.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(TribePalette.actionSecondary)
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        store.contribute(to: challenge)
                        onContribute(challenge)
                    } label: {
                        Text(challenge.progressValue == 0 ? "tribe.action.start".localized : "tribe.action.contribute".localized)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(TribePalette.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(TribePalette.actionPrimary)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func leaderboardCard(for challenge: TribeChallenge) -> some View {
        let entries = store.leaderboard(for: challenge, members: members)

        return TribeGlassCard(cornerRadius: 24, padding: 14, tint: TribePalette.surface) {
            VStack(alignment: .leading, spacing: 10) {
                Text("tribe.arena.leaderboard".localized)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(TribePalette.textPrimary)

                ForEach(Array(entries.prefix(3).enumerated()), id: \.element.id) { index, entry in
                    HStack {
                        Text("#\(index + 1)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(TribePalette.textSecondary)
                            .frame(width: 28, alignment: .leading)

                        Text(entry.member.visibility == .public ? entry.member.visibleDisplayName : "tribe.member.anonymous".localized)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(TribePalette.textPrimary)

                        Spacer(minLength: 10)

                        Text("\(entry.score.formatted())")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(TribePalette.textSecondary)
                    }
                }
            }
        }
    }
}

private struct ArenaComposerSheet: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var store: ArenaStore

    @State private var scope: ChallengeScope = .personal
    @State private var cadence: ChallengeCadence = .daily
    @State private var metricType: TribeChallengeMetricType = .steps
    @State private var title = ""
    @State private var subtitle = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("tribe.arena.composer.scope".localized) {
                    Picker("tribe.arena.composer.scope".localized, selection: $scope) {
                        ForEach(ChallengeScope.allCases) { currentScope in
                            Text(currentScope.title).tag(currentScope)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("tribe.arena.composer.cadence".localized) {
                    Picker("tribe.arena.composer.cadence".localized, selection: $cadence) {
                        ForEach(ChallengeCadence.allCases) { currentCadence in
                            Text(currentCadence.title).tag(currentCadence)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("tribe.arena.composer.type".localized) {
                    Picker("tribe.arena.composer.type".localized, selection: $metricType) {
                        ForEach(TribeChallengeMetricType.allCases) { type in
                            Text(type.title).tag(type)
                        }
                    }
                }

                Section("tribe.arena.composer.content".localized) {
                    TextField("tribe.arena.composer.title".localized, text: $title)
                    TextField("tribe.arena.composer.subtitle".localized, text: $subtitle)
                }

                Section {
                    Button("tribe.action.create".localized) {
                        store.createChallenge(
                            scope: scope,
                            cadence: cadence,
                            metricType: metricType,
                            title: title,
                            subtitle: subtitle
                        )
                        dismiss()
                    }

                    Button("tribe.action.suggestGalaxy".localized) {
                        store.suggestGalaxyChallenge(
                            title: title.isEmpty ? "tribe.arena.composer.suggestionFallback".localized : title,
                            metricType: metricType,
                            cadence: cadence
                        )
                        dismiss()
                    }
                }
            }
            .navigationTitle("tribe.arena.newChallenge".localized)
            .navigationBarTitleDisplayMode(.inline)
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
}
