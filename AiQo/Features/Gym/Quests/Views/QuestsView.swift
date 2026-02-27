import SwiftUI
import UIKit
internal import Combine

struct QuestsView: View {
    @ObservedObject var engine: QuestEngine

    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedStageID = 1
    @State private var selectedQuest: QuestDefinition?
    @State private var questSheetDetent: PresentationDetent = .fraction(0.5)
    @State private var currentTime = Date()
    @State private var stageOneCentersByQuestID: [String: Int] = [:]
    @State private var hasCenterBaseline = false
    @State private var centerToastMessage: String?
    @State private var centerToastHideTask: Task<Void, Never>?

    private let minuteTicker = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                stageSelector

                Text(questLocalizedText(selectedStage.titleKey))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 16) {
                        ForEach(selectedStage.quests) { quest in
                            let stageLocked = !engine.isStageUnlocked(quest.stageIndex)
                            QuestCard(
                                quest: quest,
                                progress: engine.cardProgress(for: quest),
                                isLocked: stageLocked,
                                referenceDate: currentTime
                            )
                            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .onTapGesture {
                                guard !stageLocked else { return }
                                questSheetDetent = .fraction(0.5)
                                selectedQuest = quest
                            }
                        }
                    }
                    .padding(.bottom, 120)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 0)
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
            if quest.stageIndex == 1 {
                StageOneQuestSheet(quest: quest, engine: engine)
                    .presentationDetents([.fraction(0.5), .large], selection: $questSheetDetent)
                    .presentationDragIndicator(.visible)
                    .presentationBackground(.ultraThinMaterial)
            } else {
                QuestDetailView(quest: quest, engine: engine)
                    .presentationDetents([.fraction(0.5), .large], selection: $questSheetDetent)
                    .presentationDragIndicator(.visible)
                    .presentationBackground(.ultraThinMaterial)
            }
        }
        .onAppear {
            selectedStageID = max(1, min(selectedStageID, 10))
            engine.refreshAllProgress(reason: .manualPull)
            syncStageOneCenterBaseline()
        }
        .onReceive(minuteTicker) { value in
            currentTime = value
        }
        .onChange(of: engine.progressByQuestId) { _, _ in
            handleStageOneCenterUpgrades()
        }
        .onDisappear {
            centerToastHideTask?.cancel()
        }
    }

    private var selectedStage: QuestStageViewModel {
        engine.stages.first(where: { $0.id == selectedStageID }) ?? engine.stages[0]
    }

    private var displayedStages: [QuestStageViewModel] {
        if layoutDirection == .rightToLeft {
            return Array(engine.stages.reversed())
        }

        return engine.stages
    }

    private var stageSelector: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(displayedStages) { stage in
                        let isLocked = !engine.isStageUnlocked(stage.id)
                        Button {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                selectedStageID = stage.id
                                proxy.scrollTo(stage.id, anchor: .center)
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Text(questLocalizedText(stage.tabTitleKey))
                                    .font(.system(size: 14, weight: .bold, design: .rounded))

                                if isLocked {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 11, weight: .bold))
                                }
                            }
                            .foregroundStyle(
                                stage.id == selectedStageID
                                    ? Color.black.opacity(0.82)
                                    : Color.primary.opacity(0.78)
                            )
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(stageCapsuleBackground(isSelected: stage.id == selectedStageID))
                            .overlay(stageCapsuleOverlay(isSelected: stage.id == selectedStageID))
                        }
                        .buttonStyle(.plain)
                        .id(stage.id)
                    }
                }
                .padding(.vertical, 2)
            }
            .onAppear {
                proxy.scrollTo(selectedStageID, anchor: .center)
            }
            .onChange(of: selectedStageID) { _, newValue in
                withAnimation(.easeInOut(duration: 0.22)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private func stageCapsuleBackground(isSelected: Bool) -> some View {
        Capsule()
            .fill(
                isSelected
                    ? LinearGradient(
                        colors: [
                            Color(uiColor: .systemYellow),
                            Color(red: 0.98, green: 0.86, blue: 0.45)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    : LinearGradient(
                        colors: [
                            Color(uiColor: .systemBackground),
                            Color(uiColor: .systemBackground)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
            )
            .shadow(
                color: isSelected ? Color(uiColor: .systemYellow).opacity(0.34) : .clear,
                radius: 6,
                x: 0,
                y: 3
            )
    }

    private func stageCapsuleOverlay(isSelected: Bool) -> some View {
        Capsule()
            .stroke(
                isSelected
                    ? Color.white.opacity(0.6)
                    : (colorScheme == .dark ? Color.white.opacity(0.16) : Color.black.opacity(0.12)),
                lineWidth: 1
            )
    }

    private func syncStageOneCenterBaseline() {
        let quests = engine.definitions(for: 1)
        stageOneCentersByQuestID = Dictionary(
            uniqueKeysWithValues: quests.map { quest in
                let tier = engine.getProgress(for: quest).currentTier
                return (quest.id, questStageOneCenter(fromTier: tier))
            }
        )
        hasCenterBaseline = true
    }

    private func handleStageOneCenterUpgrades() {
        let quests = engine.definitions(for: 1)
        let nextCenters = Dictionary(
            uniqueKeysWithValues: quests.map { quest in
                let tier = engine.getProgress(for: quest).currentTier
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
            centerToastMessage = "ترقيت إلى مركز \(center)"
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
