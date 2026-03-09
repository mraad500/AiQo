import SwiftUI
import UIKit
internal import Combine

struct QuestsView: View {
    @ObservedObject var engine: QuestEngine

    @State private var selectedStageID = 1
    @State private var selectedQuest: QuestDefinition?
    @State private var questSheetDetent: PresentationDetent = .fraction(0.5)
    @State private var currentTime = Date()
    @State private var stageOneCentersByQuestID: [String: Int] = [:]
    @State private var hasCenterBaseline = false
    @State private var centerToastMessage: String?
    @State private var centerToastHideTask: Task<Void, Never>?

    private let minuteTicker = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    private let contentLeadingPadding: CGFloat = 8
    private let contentTrailingPadding: CGFloat = ClubChromeLayout.contentTrailingPadding - 10
    private let questCardWidthReduction: CGFloat = 1.5

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                Text(questLocalizedText(selectedStage.titleKey))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)

                stageSelector

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 16) {
                        ForEach(selectedStage.quests) { quest in
                            QuestCard(
                                quest: quest,
                                progress: engine.cardProgress(for: quest),
                                isLocked: false,
                                referenceDate: currentTime
                            )
                            .padding(.horizontal, questCardWidthReduction)
                            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .onTapGesture {
                                questSheetDetent = .fraction(0.5)
                                selectedQuest = quest
                            }
                        }

                        if selectedStage.quests.isEmpty {
                            Text("محتوى هذه المرحلة سيظهر هنا قريباً.")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.primary.opacity(0.62))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(24)
                                .background(
                                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                                        .fill(.ultraThinMaterial)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                                .fill(AiQoColors.beige.opacity(0.16))
                                        )
                                )
                        }
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 120)
                }
            }
            .padding(.leading, contentLeadingPadding)
            .padding(.trailing, contentTrailingPadding)
            .padding(.top, 18)
            .animation(.spring(response: 0.34, dampingFraction: 0.84), value: selectedStageID)
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
            selectedStageID = visibleStages.first(where: { $0.id == selectedStageID })?.id ?? (visibleStages.first?.id ?? 1)
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
        visibleStages.first(where: { $0.id == selectedStageID }) ?? visibleStages[0]
    }

    private var visibleStages: [QuestStageViewModel] {
        engine.stages
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

    private var stageSelector: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(visibleStages) { stage in
                        let isSelected = stage.id == selectedStageID

                        Button {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                selectedStageID = stage.id
                                proxy.scrollTo(stage.id, anchor: .center)
                            }
                        } label: {
                            Text(questLocalizedText(stage.tabTitleKey))
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(isSelected ? Color.primary : Color.primary.opacity(0.72))
                                .lineLimit(1)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(
                                    Capsule()
                                        .fill(isSelected ? AiQoColors.mint.opacity(0.42) : Color.white.opacity(0.58))
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(isSelected ? 0.46 : 0.28), lineWidth: 0.8)
                                )
                        }
                        .buttonStyle(.plain)
                        .id(stage.id)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 4)
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
        .accessibilityLabel(Text("مراحل القمم"))
    }
}
