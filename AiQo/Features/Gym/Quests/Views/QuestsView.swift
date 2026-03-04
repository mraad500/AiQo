import SwiftUI
import UIKit
internal import Combine

struct QuestsView: View {
    @ObservedObject var engine: QuestEngine

    @Environment(\.layoutDirection) private var layoutDirection

    @State private var selectedStageID = 1
    @State private var selectedQuest: QuestDefinition?
    @State private var questSheetDetent: PresentationDetent = .fraction(0.5)
    @State private var currentTime = Date()
    @State private var stageOneCentersByQuestID: [String: Int] = [:]
    @State private var hasCenterBaseline = false
    @State private var centerToastMessage: String?
    @State private var centerToastHideTask: Task<Void, Never>?
    @State private var isRailCollapsed = true
    @State private var isRailHidden = false
    @State private var previousScrollOffset: CGFloat = 0

    private let minuteTicker = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    private let scrollOffsetSpaceName = "QuestsRailScroll"

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
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
                    .padding(.bottom, 120)
                    .background(alignment: .top) {
                        RailScrollOffsetReader(coordinateSpaceName: scrollOffsetSpaceName)
                    }
                }
                .coordinateSpace(name: scrollOffsetSpaceName)
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .clubPhysicalRightContentInset(layoutDirection: layoutDirection)
            .animation(.spring(response: 0.34, dampingFraction: 0.84), value: selectedStageID)
        }
        .clubRightRailOverlay {
            RightSideVerticalRail(
                items: stageRailItems,
                selection: stageRailSelection,
                isCollapsed: $isRailCollapsed,
                isHidden: $isRailHidden
            )
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
        .onPreferenceChange(RailScrollOffsetPreferenceKey.self) { offset in
            handleRailScroll(offset: offset)
        }
        .onDisappear {
            centerToastHideTask?.cancel()
        }
    }

    private var selectedStage: QuestStageViewModel {
        visibleStages.first(where: { $0.id == selectedStageID }) ?? visibleStages[0]
    }

    private var visibleStages: [QuestStageViewModel] {
        Array(engine.stages.prefix(4))
    }

    private var stageRailItems: [RailItem] {
        visibleStages.enumerated().map { index, stage in
            RailItem(
                id: "\(stage.id)",
                title: questLocalizedText(stage.tabTitleKey),
                icon: stageRailIcon(for: stage),
                tint: index.isMultiple(of: 2) ? AiQoColors.mint : AiQoColors.beige,
                isLocked: !engine.isStageUnlocked(stage.id)
            )
        }
    }

    private var stageRailSelection: Binding<Int> {
        Binding(
            get: {
                visibleStages.firstIndex(where: { $0.id == selectedStageID }) ?? 0
            },
            set: { newValue in
                guard visibleStages.indices.contains(newValue) else { return }
                let nextStage = visibleStages[newValue]
                guard engine.isStageUnlocked(nextStage.id) else { return }
                selectedStageID = nextStage.id
            }
        )
    }

    private func stageRailIcon(for stage: QuestStageViewModel) -> String {
        switch stage.id {
        case 1:
            return "flag"
        case 2:
            return "flag.fill"
        case 3:
            return engine.isStageUnlocked(stage.id) ? "flag.checkered" : "lock.fill"
        default:
            return "crown"
        }
    }

    private func handleRailScroll(offset: CGFloat) {
        let delta = offset - previousScrollOffset

        if delta <= -15 {
            withAnimation(.easeOut(duration: 0.25)) {
                isRailHidden = true
            }
        } else if delta >= 15 || offset >= -8 {
            withAnimation(.easeOut(duration: 0.25)) {
                isRailHidden = false
            }
        }

        if offset <= -180, !isRailCollapsed {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                isRailCollapsed = true
            }
        }

        previousScrollOffset = offset
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
