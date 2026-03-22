import SwiftUI
import UIKit
import Combine

// MARK: - PeaksRecordsView (قِمَم — الأرقام القياسية فقط)

struct PeaksRecordsView: View {
    @StateObject private var legendaryVM = LegendaryChallengesViewModel()

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .trailing, spacing: 10) {
                Text("الأرقام القياسية")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 4)
                    .padding(.bottom, 4)

                ForEach(Array(legendaryVM.records.enumerated()), id: \.element.id) { index, record in
                    NavigationLink(value: record) {
                        RecordCardVertical(record: record, index: index)
                    }
                    .buttonStyle(.plain)
                    .aiQoPressEffect()
                }
            }
            .padding(.top, 4)
            .padding(.horizontal, 16)
            .padding(.bottom, 120)
        }
        .environment(\.layoutDirection, .rightToLeft)
        .navigationDestination(for: LegendaryRecord.self) { record in
            RecordDetailView(record: record, viewModel: legendaryVM)
        }
    }
}

// MARK: - BattleChallengesView (معركة — التحديات فقط)

struct BattleChallengesView: View {
    @ObservedObject var questEngine: QuestEngine

    @State private var selectedStageID = 1
    @State private var selectedQuest: QuestDefinition?
    @State private var questSheetDetent: PresentationDetent = .fraction(0.5)
    @State private var currentTime = Date()
    @State private var stageOneCentersByQuestID: [String: Int] = [:]
    @State private var hasCenterBaseline = false
    @State private var centerToastMessage: String?
    @State private var centerToastHideTask: Task<Void, Never>?
    @State private var completedQuestForCelebration: QuestDefinition?

    private let minuteTicker = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Left stage selector
            stageSelector
                .padding(.top, 8)
                .padding(.leading, 6)

            // Challenge cards
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .trailing, spacing: 12) {
                    stageHeader

                    if questEngine.isStageUnlocked(selectedStageID) {
                        ForEach(Array(selectedStage.quests.enumerated()), id: \.element.id) { index, quest in
                            QuestCard(
                                quest: quest,
                                progress: questEngine.cardProgress(for: quest),
                                isLocked: false,
                                referenceDate: currentTime
                            )
                            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .onTapGesture {
                                questSheetDetent = .fraction(0.5)
                                selectedQuest = quest
                            }
                            .aiQoPressEffect()
                        }
                    } else {
                        lockedStageMessage
                    }

                    if selectedStage.quests.isEmpty, questEngine.isStageUnlocked(selectedStageID) {
                        Text("محتوى هذه المرحلة سيظهر هنا قريباً.")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.primary.opacity(0.62))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(24)
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Color(hex: "B7E5D2").opacity(0.1))
                            )
                    }
                }
                .padding(.top, 4)
                .padding(.horizontal, 12)
                .padding(.bottom, 120)
            }
            .environment(\.layoutDirection, .rightToLeft)
        }
        .overlay(alignment: .top) {
            if let centerToastMessage {
                Text(centerToastMessage)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(uiColor: .systemBackground).opacity(0.92))
                            .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
                    )
                    .padding(.top, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .sheet(item: $selectedQuest) { quest in
            QuestDetailSheet(quest: quest, engine: questEngine) { completedQuest in
                selectedQuest = nil
                handleQuestCompletion(completedQuest)
            }
            .presentationDetents([.medium, .large], selection: $questSheetDetent)
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
            .presentationBackground(.ultraThinMaterial)
        }
        .fullScreenCover(item: $completedQuestForCelebration) { quest in
            QuestCompletionCelebration(quest: quest) {
                let completedQuest = quest
                completedQuestForCelebration = nil
                saveQuestAchievement(completedQuest)
            }
            .background(ClearBackground())
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.84), value: selectedStageID)
        .onAppear {
            selectedStageID = visibleStages.first(where: { $0.id == selectedStageID })?.id ?? (visibleStages.first?.id ?? 1)
            questEngine.refreshAllProgress(reason: .manualPull)
            syncStageOneCenterBaseline()
        }
        .onReceive(minuteTicker) { value in
            currentTime = value
        }
        .onChange(of: questEngine.progressByQuestId) { _, _ in
            handleStageOneCenterUpgrades()
        }
        .onDisappear {
            centerToastHideTask?.cancel()
        }
    }

    // MARK: - Stage Selector

    private var stageSelector: some View {
        VStack(spacing: 8) {
            ForEach(visibleStages, id: \.id) { stage in
                let isLocked = !questEngine.isStageUnlocked(stage.id)
                let isSelected = stage.id == selectedStageID

                Button {
                    guard !isLocked else { return }
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                        selectedStageID = stage.id
                    }
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    VStack(spacing: 3) {
                        ZStack {
                            Circle()
                                .fill(stageCircleColor(isSelected: isSelected, isLocked: isLocked))
                                .frame(width: 32, height: 32)

                            if isLocked {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.gray.opacity(0.4))
                            } else {
                                Text(stage.id.arabicFormatted)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(isSelected ? .white : .gray.opacity(0.7))
                            }
                        }

                        Text(questLocalizedText(stage.tabTitleKey))
                            .font(.system(size: 7, weight: .medium, design: .rounded))
                            .foregroundStyle(isSelected ? Color.primary : Color.secondary.opacity(0.6))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                    .frame(width: 44)
                    .opacity(isLocked ? 0.5 : 1)
                }
                .disabled(isLocked)
                .accessibilityLabel("المرحلة \(stage.id.arabicFormatted)")
            }
        }
        .padding(.vertical, 8)
        .accessibilityLabel(Text("مراحل القمم"))
    }

    private func stageCircleColor(isSelected: Bool, isLocked: Bool) -> Color {
        if isSelected {
            return Color(hex: "EBCF97")
        } else if isLocked {
            return Color.gray.opacity(0.1)
        } else {
            return Color.gray.opacity(0.12)
        }
    }

    // MARK: - Stage Header

    private var stageHeader: some View {
        VStack(spacing: 4) {
            Text("المرحلة \(selectedStageID.arabicFormatted)")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            Text(stageDisplayTitle)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.bottom, 4)
    }

    // MARK: - Locked Stage Message

    private var lockedStageMessage: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 36, design: .rounded))
                .foregroundStyle(Color(hex: "CCCCCC"))

            Text("المرحلة مقفلة")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(hex: "999999"))

            Text("أكمل جميع تحديات المرحلة السابقة لفتح هذه المرحلة")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color(hex: "AAAAAA"))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(hex: "F5F5F5"))
        )
    }

    // MARK: - Helpers

    private func handleQuestCompletion(_ quest: QuestDefinition) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            completedQuestForCelebration = quest
        }
    }

    private func saveQuestAchievement(_ quest: QuestDefinition) {
        let achievement = QuestEarnedAchievement(
            id: UUID(),
            questId: quest.id,
            questName: quest.title,
            badgeImageName: quest.rewardImageName,
            stageNumber: quest.stageIndex,
            earnedDate: Date()
        )

        var achievements = QuestAchievementStore.load()
        guard !achievements.contains(where: { $0.questId == quest.id }) else { return }
        achievements.append(achievement)
        QuestAchievementStore.save(achievements)
    }

    private var selectedStage: QuestStageViewModel {
        visibleStages.first(where: { $0.id == selectedStageID }) ?? visibleStages[0]
    }

    private var visibleStages: [QuestStageViewModel] {
        questEngine.stages
    }

    private var stageDisplayTitle: String {
        let localizedTitle = questLocalizedText(selectedStage.titleKey)

        for separator in [": ", ":", "："] {
            if let range = localizedTitle.range(of: separator) {
                let trailingTitle = localizedTitle[range.upperBound...]
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !trailingTitle.isEmpty {
                    return trailingTitle
                }
            }
        }

        return localizedTitle
    }

    private func syncStageOneCenterBaseline() {
        let quests = questEngine.definitions(for: 1)
        stageOneCentersByQuestID = Dictionary(
            uniqueKeysWithValues: quests.map { quest in
                let tier = questEngine.getProgress(for: quest).currentTier
                return (quest.id, questStageOneCenter(fromTier: tier))
            }
        )
        hasCenterBaseline = true
    }

    private func handleStageOneCenterUpgrades() {
        let quests = questEngine.definitions(for: 1)
        let nextCenters = Dictionary(
            uniqueKeysWithValues: quests.map { quest in
                let tier = questEngine.getProgress(for: quest).currentTier
                return (quest.id, questStageOneCenter(fromTier: tier))
            }
        )

        guard hasCenterBaseline else {
            stageOneCentersByQuestID = nextCenters
            hasCenterBaseline = true
            return
        }

        for quest in quests {
            let previous = stageOneCentersByQuestID[quest.id] ?? 0
            let current = nextCenters[quest.id] ?? 0
            let improved = current > 0 && (previous == 0 || current < previous)
            if improved {
                showCenterUpgradeToast(center: current)
                break
            }
        }

        stageOneCentersByQuestID = nextCenters
    }

    private func showCenterUpgradeToast(center: Int) {
        guard center > 0 else { return }
        centerToastHideTask?.cancel()
        withAnimation(.easeInOut(duration: 0.22)) {
            centerToastMessage = "ترقيت إلى مركز \(center.arabicFormatted)"
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        centerToastHideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            withAnimation(.easeInOut(duration: 0.22)) {
                centerToastMessage = nil
            }
        }
    }
}

// MARK: - RecordCardVertical

struct RecordCardVertical: View {
    let record: LegendaryRecord
    let index: Int

    private var cardBackground: Color {
        index.isMultiple(of: 2) ? Color(hex: "B7E5D2") : Color(hex: "EBCF97")
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // المحتوى النصي
            VStack(alignment: .trailing, spacing: 4) {
                Text(record.category.rawValue)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.7))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.08))
                    .clipShape(Capsule())

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(record.unit)
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text(record.formattedTarget)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                }

                Text(record.titleAr)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.85))

                HStack(spacing: 4) {
                    Text("•••")
                        .font(.system(size: 9, design: .rounded))
                        .foregroundStyle(.secondary.opacity(0.4))
                    Text("صاحب الرقم: \(record.recordHolderAr)")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text(record.country)
                        .font(.system(size: 13))
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)

            Spacer()

            // أيقونة التمرين
            Image(systemName: record.iconName)
                .font(.system(size: 20, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.5))
                .clipShape(Circle())
                .flipsForRightToLeftLayoutDirection(false)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(cardBackground.opacity(0.86))
        )
        .environment(\.layoutDirection, .rightToLeft)
    }
}
