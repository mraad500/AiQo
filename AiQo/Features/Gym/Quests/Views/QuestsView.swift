import SwiftUI
import UIKit
internal import Combine

// NEW: Enum for the right-side vertical tab bar in قِمَم
enum QimamSubTab: String, CaseIterable {
    case challenges = "التحديات"
    case records = "الأرقام"
}

struct QuestsView: View {
    @ObservedObject var engine: QuestEngine

    // ADDED: Legendary Challenges ViewModel
    @StateObject private var legendaryVM = LegendaryChallengesViewModel()

    @State private var selectedStageID = 1
    @State private var selectedQuest: QuestDefinition?
    @State private var questSheetDetent: PresentationDetent = .fraction(0.5)
    @State private var currentTime = Date()
    @State private var stageOneCentersByQuestID: [String: Int] = [:]
    @State private var hasCenterBaseline = false
    @State private var centerToastMessage: String?
    @State private var centerToastHideTask: Task<Void, Never>?
    @State private var completedQuestForCelebration: QuestDefinition?

    // NEW: State for the right-side sub-tab picker (التحديات / الأرقام)
    @State private var selectedQimamTab: QimamSubTab = .records

    private let minuteTicker = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    // Padding adjusted so cards sit between the two sidebars with spacing
    private let contentLeadingPadding: CGFloat = 50   // space for left rail (32pt) + gap
    private let contentTrailingPadding: CGFloat = 70   // space for right tab bar (56pt) + gap
    private let questCardWidthReduction: CGFloat = 4

    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            // CHANGED: Main content area — switches between challenges and records
            if selectedQimamTab == .challenges {
                challengesContent
            } else {
                recordsContent
            }

            // CHANGED: Stage side rail — now positioned on the LEFT side, only visible for challenges tab
            if selectedQimamTab == .challenges {
                leftStageSelector
                    .transition(.opacity)
            }

            // NEW: Right-side vertical tab bar (التحديات / الأرقام) — always visible
            rightQimamTabBar
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.84), value: selectedQimamTab)
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
        // ADDED: Navigation destination for Legendary Challenges flow
        .navigationDestination(for: LegendaryRecord.self) { record in
            RecordDetailView(record: record, viewModel: legendaryVM)
        }
        .sheet(item: $selectedQuest) { quest in
            QuestDetailSheet(quest: quest, engine: engine) { completedQuest in
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

    // MARK: - NEW: Challenges Content (التحديات)
    // CHANGED: Extracted the existing challenge cards into their own view.
    // REMOVED: The LegendaryChallengesSection horizontal scroll that was at the bottom.

    private var challengesContent: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 16) {
                stageHeader

                if engine.isStageUnlocked(selectedStageID) {
                    ForEach(Array(selectedStage.quests.enumerated()), id: \.element.id) { index, quest in
                        QuestCard(
                            quest: quest,
                            progress: engine.cardProgress(for: quest),
                            isLocked: false,
                            referenceDate: currentTime
                        )
                        .padding(.horizontal, 0)
                        .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                        .onTapGesture {
                            questSheetDetent = .fraction(0.5)
                            selectedQuest = quest
                        }
                    }
                } else {
                    lockedStageMessage
                }

                if selectedStage.quests.isEmpty, engine.isStageUnlocked(selectedStageID) {
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

                // REMOVED: LegendaryChallengesSection was here — now lives in the "الأرقام" tab
            }
            .padding(.top, 12)
            .padding(.leading, 60) // مساحة للشريط الجانبي الأيسر (مراحل)
            .padding(.trailing, 70) // مساحة للشريط الجانبي الأيمن
            .padding(.bottom, 120)
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.84), value: selectedStageID)
    }

    // MARK: - NEW: Records Content (الأرقام)
    // Shows legendary record cards in a vertical scrollable list

    private var recordsContent: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .trailing, spacing: 14) {
                Text("الأرقام القياسية")
                    .font(.system(size: 32, weight: .black))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.bottom, 4)

                // Vertical list of record cards
                ForEach(Array(legendaryVM.records.enumerated()), id: \.element.id) { index, record in
                    NavigationLink(value: record) {
                        RecordCardVertical(record: record, index: index)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 12)
            .padding(.leading, 20) // records don't need left rail space
            .padding(.trailing, contentTrailingPadding)
            .padding(.bottom, 120)
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    // MARK: - CHANGED: Stage Selector — Now on the LEFT side, slim, 3 visible, centered

    // CHANGED: Custom slim config for left rail — narrower (26pt), only 3 visible, smaller items
    private var leftRailConfig: SlimRightSideRailConfiguration {
        SlimRightSideRailConfiguration(
            maxVisibleItems: 5,
            railWidth: 32,
            itemHeight: 40,
            titleFontSize: 8,
            titleLineCount: 2,
            symbolPointSize: 12,
            stackSpacing: 8,
            contentInsets: NSDirectionalEdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0),
            horizontalPositionOffset: 0,
            verticalCenterRatio: 0.50
        )
    }

    private var leftStageSelector: some View {
        GeometryReader { proxy in
            let config = leftRailConfig
            let startY: CGFloat = 120 // تحت العنوان

            AppleLeftSideRailWrapper(
                items: stageRailItems,
                selection: selectedStageIndex,
                configuration: config
            )
            .frame(width: config.railWidth)
            .position(
                x: 8 + (config.railWidth / 2), // 8pt leading
                y: startY + calculatedRailHeight(itemCount: stageRailItems.count, config: config) / 2
            )
        }
        .accessibilityLabel(Text("مراحل القمم"))
    }

    // Helper to calculate rail height
    private func calculatedRailHeight(itemCount: Int, config: SlimRightSideRailConfiguration) -> CGFloat {
        let visibleItemCount = max(1, min(itemCount, config.maxVisibleItems ?? itemCount))
        let spacing = config.stackSpacing * CGFloat(max(visibleItemCount - 1, 0))
        return (CGFloat(visibleItemCount) * config.itemHeight) + spacing + 12
    }

    // MARK: - Right-Side Vertical Tab Bar — narrow, tall, raised

    private var rightQimamTabBar: some View {
        GeometryReader { proxy in
            let centerY = proxy.size.height * 0.50

            RightQimamRailView(
                tabs: QimamSubTab.allCases,
                selection: $selectedQimamTab
            )
            .frame(width: 56)
            .position(
                x: proxy.size.width - 8 - 28, // 8pt trailing + half of 56pt
                y: centerY
            )
        }
        .allowsHitTesting(true)
    }

    // MARK: - Locked Stage Message

    private var lockedStageMessage: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 36))
                .foregroundColor(Color(hex: "CCCCCC"))

            Text("المرحلة مقفلة")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundColor(Color(hex: "999999"))

            Text("أكمل جميع تحديات المرحلة السابقة لفتح هذه المرحلة")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: "AAAAAA"))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color(hex: "F5F5F5"))
        )
    }

    // MARK: - Completion Handling

    private func handleQuestCompletion(_ quest: QuestDefinition) {
        // Small delay to let the sheet dismiss
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

    // MARK: - Existing Logic (preserved)

    private var selectedStage: QuestStageViewModel {
        visibleStages.first(where: { $0.id == selectedStageID }) ?? visibleStages[0]
    }

    private var visibleStages: [QuestStageViewModel] {
        engine.stages
    }

    private var stageHeader: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("المرحلة \(selectedStageID)")
                .font(.system(size: 14))
                .foregroundColor(.secondary)

            Text(stageDisplayTitle)
                .font(.system(size: 32, weight: .black))
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.horizontal, 20)
        .padding(.bottom, 4)
    }

    private var stageRailItems: [RailItem] {
        visibleStages.map { stage in
            let isLocked = !engine.isStageUnlocked(stage.id)
            return RailItem(
                id: "quest_stage_\(stage.id)",
                title: questLocalizedText(stage.tabTitleKey),
                icon: isLocked ? "lock.fill" : "\(stage.id).circle.fill",
                tint: isLocked ? Color(hex: "CCCCCC") : stageRailTint(for: stage.id),
                isLocked: isLocked
            )
        }
    }

    private var selectedStageIndex: Binding<Int> {
        Binding(
            get: {
                visibleStages.firstIndex(where: { $0.id == selectedStageID }) ?? 0
            },
            set: { newValue in
                guard visibleStages.indices.contains(newValue) else { return }
                withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                    selectedStageID = visibleStages[newValue].id
                }
            }
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

    private func stageRailTint(for stageID: Int) -> Color {
        switch stageID % 3 {
        case 1:
            return AiQoColors.mint
        case 2:
            return AiQoColors.beige
        default:
            return AiQoColors.mint.opacity(0.88)
        }
    }
}

// MARK: - NEW: AppleLeftSideRailWrapper
// A thin wrapper that reuses the SlimRightSideRail's UIKit control but we position it on the left.
// We just use the same AppleVerticalRailControl via SlimRightSideRail's underlying rendering.

private struct AppleLeftSideRailWrapper: View {
    let items: [RailItem]
    @Binding var selection: Int
    let configuration: SlimRightSideRailConfiguration

    var body: some View {
        // Reuse the same SlimRightSideRail rendering component
        SlimLeftSideRailControl(
            items: items,
            selection: $selection,
            configuration: configuration
        )
    }
}

// MARK: - NEW: SlimLeftSideRailControl
// A SwiftUI wrapper that creates the same UIKit-based rail control used on the right side,
// but intended for left-side positioning (the parent handles positioning).

struct SlimLeftSideRailControl: UIViewRepresentable {
    let items: [RailItem]
    @Binding var selection: Int
    let configuration: SlimRightSideRailConfiguration

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection)
    }

    func makeUIView(context: Context) -> LeftSideRailControlView {
        let view = LeftSideRailControlView(configuration: configuration)
        view.onSelectionChanged = { index in
            guard context.coordinator.selection != index else { return }
            DispatchQueue.main.async {
                guard context.coordinator.selection != index else { return }
                UISelectionFeedbackGenerator().selectionChanged()
                context.coordinator.selection = index
            }
        }
        return view
    }

    func updateUIView(_ uiView: LeftSideRailControlView, context: Context) {
        uiView.onSelectionChanged = { index in
            guard context.coordinator.selection != index else { return }
            DispatchQueue.main.async {
                guard context.coordinator.selection != index else { return }
                UISelectionFeedbackGenerator().selectionChanged()
                context.coordinator.selection = index
            }
        }
        uiView.update(items: items, selection: selection, configuration: configuration)
    }

    final class Coordinator {
        @Binding var selection: Int
        init(selection: Binding<Int>) {
            _selection = selection
        }
    }
}

// MARK: - NEW: LeftSideRailControlView (UIKit)
// Identical to AppleVerticalRailControlView but for left-side use.

final class LeftSideRailControlView: UIView {
    private let glassView: UIVisualEffectView = {
        let effect: UIVisualEffect
        if #available(iOS 26.0, *) {
            effect = UIGlassEffect()
        } else {
            effect = UIBlurEffect(style: .systemUltraThinMaterial)
        }
        return UIVisualEffectView(effect: effect)
    }()
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()

    private var buttons: [UIButton] = []
    private var currentItems: [RailItem] = []
    private var itemHeightConstraints: [NSLayoutConstraint] = []
    private var railConfiguration: SlimRightSideRailConfiguration
    private var lastAppliedSelection: Int?

    var onSelectionChanged: ((Int) -> Void)?

    init(configuration: SlimRightSideRailConfiguration) {
        railConfiguration = configuration
        super.init(frame: .zero)

        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false

        glassView.translatesAutoresizingMaskIntoConstraints = false
        glassView.clipsToBounds = true
        addSubview(glassView)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = false
        scrollView.contentInsetAdjustmentBehavior = .never
        glassView.contentView.addSubview(scrollView)

        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.distribution = .fill
        scrollView.addSubview(stackView)

        NSLayoutConstraint.activate([
            glassView.leadingAnchor.constraint(equalTo: leadingAnchor),
            glassView.trailingAnchor.constraint(equalTo: trailingAnchor),
            glassView.topAnchor.constraint(equalTo: topAnchor),
            glassView.bottomAnchor.constraint(equalTo: bottomAnchor),

            scrollView.leadingAnchor.constraint(equalTo: glassView.contentView.leadingAnchor, constant: 6),
            scrollView.trailingAnchor.constraint(equalTo: glassView.contentView.trailingAnchor, constant: -6),
            scrollView.topAnchor.constraint(equalTo: glassView.contentView.topAnchor, constant: 6),
            scrollView.bottomAnchor.constraint(equalTo: glassView.contentView.bottomAnchor, constant: -6),

            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])

        applyConfiguration(configuration)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        let visibleCount = visibleItemCount
        let spacing = stackView.spacing * CGFloat(max(visibleCount - 1, 0))
        let height = CGFloat(visibleCount) * railConfiguration.itemHeight + spacing + 12
        return CGSize(width: railConfiguration.railWidth, height: height)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let cornerRadius = bounds.width / 2
        glassView.layer.cornerCurve = .continuous
        glassView.layer.cornerRadius = cornerRadius
        glassView.layer.borderWidth = 1
        glassView.layer.borderColor = UIColor.white.withAlphaComponent(0.20).cgColor

        layer.shadowColor = UIColor.black.withAlphaComponent(0.035).cgColor
        layer.shadowOpacity = 1
        layer.shadowRadius = 8
        layer.shadowOffset = CGSize(width: 0, height: 5)
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius).cgPath
    }

    func update(items: [RailItem], selection: Int, configuration: SlimRightSideRailConfiguration) {
        if railConfiguration != configuration {
            railConfiguration = configuration
            applyConfiguration(configuration)
            updateButtonMetrics()
            invalidateIntrinsicContentSize()
        }

        if needsRebuild(for: items) {
            rebuildButtons(with: items)
        }

        currentItems = items
        scrollView.isScrollEnabled = shouldEnableScrolling(for: items.count)
        scrollView.alwaysBounceVertical = scrollView.isScrollEnabled
        invalidateIntrinsicContentSize()
        applySelectionState(selection: selection)
        centerSelectedButtonIfNeeded(selection: selection, animated: lastAppliedSelection != nil && lastAppliedSelection != selection)
        lastAppliedSelection = selection
    }

    @objc
    private func buttonTapped(_ sender: UIButton) {
        let index = sender.tag
        guard currentItems.indices.contains(index), !currentItems[index].isLocked else { return }
        onSelectionChanged?(index)
    }

    private func needsRebuild(for items: [RailItem]) -> Bool {
        guard items.count == currentItems.count else { return true }
        for (lhs, rhs) in zip(items, currentItems) {
            if lhs.id != rhs.id || lhs.title != rhs.title || lhs.icon != rhs.icon {
                return true
            }
        }
        return false
    }

    private func rebuildButtons(with items: [RailItem]) {
        buttons.forEach {
            stackView.removeArrangedSubview($0)
            $0.removeTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
            $0.removeFromSuperview()
        }
        buttons.removeAll()
        itemHeightConstraints.forEach { $0.isActive = false }
        itemHeightConstraints.removeAll()

        for (index, item) in items.enumerated() {
            let button = makeButton(for: item, index: index)
            buttons.append(button)
            stackView.addArrangedSubview(button)
        }

        updateButtonMetrics()
    }

    private func makeButton(for item: RailItem, index: Int) -> UIButton {
        let button = UIButton(type: .system)
        button.tag = index
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)

        var configuration = UIButton.Configuration.glass()
        configuration.image = UIImage(systemName: item.icon)
        configuration.title = item.title
        configuration.imagePlacement = .top
        configuration.imagePadding = 5
        configuration.baseForegroundColor = UIColor.black.withAlphaComponent(0.82)
        configuration.contentInsets = railConfiguration.contentInsets
        configuration.titleAlignment = .center
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(
            pointSize: railConfiguration.symbolPointSize,
            weight: .semibold
        )
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.systemFont(ofSize: self.railConfiguration.titleFontSize, weight: .medium)
            return outgoing
        }

        button.configuration = configuration
        button.clipsToBounds = true
        button.layer.cornerCurve = .continuous
        button.layer.cornerRadius = 20
        button.titleLabel?.numberOfLines = railConfiguration.titleLineCount
        button.titleLabel?.textAlignment = .center
        button.titleLabel?.adjustsFontSizeToFitWidth = false
        button.titleLabel?.lineBreakMode = .byWordWrapping

        let heightConstraint = button.heightAnchor.constraint(equalToConstant: railConfiguration.itemHeight)
        heightConstraint.isActive = true
        itemHeightConstraints.append(heightConstraint)

        return button
    }

    private func applySelectionState(selection: Int) {
        for (index, button) in buttons.enumerated() {
            guard currentItems.indices.contains(index) else { continue }

            let item = currentItems[index]
            let isSelected = index == selection
            let foreground = UIColor.black.withAlphaComponent(isSelected ? 0.90 : 0.82)

            var configuration = isSelected ? UIButton.Configuration.prominentGlass() : UIButton.Configuration.glass()
            configuration.image = UIImage(systemName: item.icon)
            configuration.title = item.title
            configuration.imagePlacement = .top
            configuration.imagePadding = 5
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 2, bottom: 8, trailing: 2)
            configuration.titleAlignment = .center
            configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(
                pointSize: railConfiguration.symbolPointSize,
                weight: isSelected ? .bold : .semibold
            )
            configuration.baseForegroundColor = foreground
            configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var outgoing = incoming
                outgoing.font = UIFont.systemFont(
                    ofSize: self.railConfiguration.titleFontSize,
                    weight: isSelected ? .semibold : .medium
                )
                return outgoing
            }
            configuration.contentInsets = railConfiguration.contentInsets
            if isSelected {
                configuration.baseBackgroundColor = UIColor(red: 1.0, green: 0.902, blue: 0.549, alpha: 0.85) // #FFE68C
            }

            button.configuration = configuration
            button.isEnabled = !item.isLocked
            button.alpha = item.isLocked ? 0.45 : 1
            button.titleLabel?.numberOfLines = railConfiguration.titleLineCount
            button.titleLabel?.textAlignment = .center
            button.titleLabel?.adjustsFontSizeToFitWidth = false
            button.titleLabel?.lineBreakMode = .byWordWrapping
        }
    }

    private var visibleItemCount: Int {
        let maxVisibleItems = railConfiguration.maxVisibleItems ?? currentItems.count
        return max(1, min(currentItems.count, maxVisibleItems))
    }

    private func shouldEnableScrolling(for itemCount: Int) -> Bool {
        guard let maxVisibleItems = railConfiguration.maxVisibleItems else { return false }
        return itemCount > maxVisibleItems
    }

    private func applyConfiguration(_ configuration: SlimRightSideRailConfiguration) {
        stackView.spacing = configuration.stackSpacing
    }

    private func updateButtonMetrics() {
        for constraint in itemHeightConstraints {
            constraint.constant = railConfiguration.itemHeight
        }
    }

    private func centerSelectedButtonIfNeeded(selection: Int, animated: Bool) {
        guard scrollView.isScrollEnabled, buttons.indices.contains(selection) else { return }

        layoutIfNeeded()

        let selectedButton = buttons[selection]
        let targetOffsetY = max(
            0,
            min(
                selectedButton.frame.midY - (scrollView.bounds.height / 2),
                scrollView.contentSize.height - scrollView.bounds.height
            )
        )

        scrollView.setContentOffset(CGPoint(x: 0, y: targetOffsetY), animated: animated)
    }
}

// MARK: - NEW: RecordCardVertical — Full-width vertical card for الأرقام tab

struct RecordCardVertical: View {
    let record: LegendaryRecord
    let index: Int

    private var cardBackground: Color {
        index.isMultiple(of: 2) ? Color(hex: "B7E5D2") : Color(hex: "EBCF97")
    }

    var body: some View {
        HStack(spacing: 16) {
            // أيقونة التمرين (يمين في RTL)
            Circle()
                .fill(Color(hex: "B7E5D2").opacity(0.3))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: record.iconName)
                        .font(.system(size: 20))
                        .foregroundColor(.primary)
                        .flipsForRightToLeftLayoutDirection(false)
                )

            VStack(alignment: .trailing, spacing: 6) {
                // تاغ الفئة
                Text(record.category.rawValue)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: "EBCF97"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(Color(hex: "EBCF97").opacity(0.15))
                    .clipShape(Capsule())

                // الرقم + الوحدة
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(record.unit)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Text(record.formattedTarget)
                        .font(.system(size: 28, weight: .black))
                }

                // وصف الرقم
                Text(record.titleAr)
                    .font(.system(size: 15, weight: .bold))

                // صاحب الرقم
                HStack(spacing: 4) {
                    Text("•••")
                        .foregroundColor(.secondary)
                    Text("صاحب الرقم: \(record.recordHolderAr)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text(record.country)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(cardBackground.opacity(0.2))
        )
        .environment(\.layoutDirection, .rightToLeft)
    }
}

// MARK: - RightQimamRailView — UIKit glass rail matching the left stage selector style

struct RightQimamRailView: UIViewRepresentable {
    let tabs: [QimamSubTab]
    @Binding var selection: QimamSubTab

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection)
    }

    func makeUIView(context: Context) -> RightQimamRailControlView {
        let view = RightQimamRailControlView(tabs: tabs)
        view.onSelectionChanged = { tab in
            UISelectionFeedbackGenerator().selectionChanged()
            context.coordinator.selection = tab
        }
        return view
    }

    func updateUIView(_ uiView: RightQimamRailControlView, context: Context) {
        uiView.onSelectionChanged = { tab in
            UISelectionFeedbackGenerator().selectionChanged()
            context.coordinator.selection = tab
        }
        uiView.updateSelection(selection)
    }

    final class Coordinator {
        @Binding var selection: QimamSubTab
        init(selection: Binding<QimamSubTab>) {
            _selection = selection
        }
    }
}

final class RightQimamRailControlView: UIView {
    private let glassView: UIVisualEffectView = {
        let effect: UIVisualEffect
        if #available(iOS 26.0, *) {
            effect = UIGlassEffect()
        } else {
            effect = UIBlurEffect(style: .systemUltraThinMaterial)
        }
        return UIVisualEffectView(effect: effect)
    }()

    private let stackView = UIStackView()
    private var buttons: [UIButton] = []
    private var tabs: [QimamSubTab] = []
    private var currentSelection: QimamSubTab = .challenges

    private let railWidth: CGFloat = 56
    private let itemHeight: CGFloat = 56

    private static let tabIcons: [QimamSubTab: String] = [
        .challenges: "flame.fill",
        .records: "trophy.fill"
    ]

    var onSelectionChanged: ((QimamSubTab) -> Void)?

    init(tabs: [QimamSubTab]) {
        self.tabs = tabs
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear

        glassView.translatesAutoresizingMaskIntoConstraints = false
        glassView.clipsToBounds = true
        addSubview(glassView)

        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.distribution = .fill
        stackView.spacing = 12
        glassView.contentView.addSubview(stackView)

        NSLayoutConstraint.activate([
            glassView.leadingAnchor.constraint(equalTo: leadingAnchor),
            glassView.trailingAnchor.constraint(equalTo: trailingAnchor),
            glassView.topAnchor.constraint(equalTo: topAnchor),
            glassView.bottomAnchor.constraint(equalTo: bottomAnchor),

            stackView.leadingAnchor.constraint(equalTo: glassView.contentView.leadingAnchor, constant: 6),
            stackView.trailingAnchor.constraint(equalTo: glassView.contentView.trailingAnchor, constant: -6),
            stackView.topAnchor.constraint(equalTo: glassView.contentView.topAnchor, constant: 8),
            stackView.bottomAnchor.constraint(equalTo: glassView.contentView.bottomAnchor, constant: -8),
        ])

        buildButtons()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        let spacing = stackView.spacing * CGFloat(max(tabs.count - 1, 0))
        let height = CGFloat(tabs.count) * itemHeight + spacing + 12
        return CGSize(width: railWidth, height: height)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let cornerRadius = bounds.width / 2
        glassView.layer.cornerCurve = .continuous
        glassView.layer.cornerRadius = cornerRadius
        glassView.layer.borderWidth = 1
        glassView.layer.borderColor = UIColor.white.withAlphaComponent(0.20).cgColor

        layer.shadowColor = UIColor.black.withAlphaComponent(0.035).cgColor
        layer.shadowOpacity = 1
        layer.shadowRadius = 8
        layer.shadowOffset = CGSize(width: 0, height: 5)
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius).cgPath
    }

    private func buildButtons() {
        for (index, tab) in tabs.enumerated() {
            let button = UIButton(type: .system)
            button.tag = index
            button.translatesAutoresizingMaskIntoConstraints = false
            button.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)

            let iconName = Self.tabIcons[tab] ?? "circle.fill"

            var config = UIButton.Configuration.glass()
            config.image = UIImage(systemName: iconName)
            config.title = tab.rawValue
            config.imagePlacement = .top
            config.imagePadding = 4
            config.baseForegroundColor = UIColor.black.withAlphaComponent(0.82)
            config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 2, bottom: 6, trailing: 2)
            config.titleAlignment = .center
            config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(
                pointSize: 18, weight: .semibold
            )
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var outgoing = incoming
                outgoing.font = UIFont.systemFont(ofSize: 10, weight: .bold)
                return outgoing
            }

            button.configuration = config
            button.clipsToBounds = true
            button.layer.cornerCurve = .continuous
            button.layer.cornerRadius = 14
            button.titleLabel?.numberOfLines = 1
            button.titleLabel?.textAlignment = .center
            button.titleLabel?.lineBreakMode = .byWordWrapping

            let heightConstraint = button.heightAnchor.constraint(equalToConstant: itemHeight)
            heightConstraint.isActive = true

            buttons.append(button)
            stackView.addArrangedSubview(button)
        }

        applySelectionState()
    }

    @objc private func buttonTapped(_ sender: UIButton) {
        let index = sender.tag
        guard tabs.indices.contains(index) else { return }
        onSelectionChanged?(tabs[index])
    }

    func updateSelection(_ tab: QimamSubTab) {
        guard currentSelection != tab else { return }
        currentSelection = tab
        applySelectionState()
    }

    private func applySelectionState() {
        for (index, button) in buttons.enumerated() {
            guard tabs.indices.contains(index) else { continue }
            let tab = tabs[index]
            let isSelected = tab == currentSelection
            let iconName = Self.tabIcons[tab] ?? "circle.fill"

            var config = isSelected ? UIButton.Configuration.prominentGlass() : UIButton.Configuration.glass()
            config.image = UIImage(systemName: iconName)
            config.title = tab.rawValue
            config.imagePlacement = .top
            config.imagePadding = 4
            config.baseForegroundColor = isSelected
                ? UIColor(red: 0.922, green: 0.812, blue: 0.592, alpha: 1.0) // Sand #EBCF97
                : UIColor.gray
            config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 2, bottom: 6, trailing: 2)
            config.titleAlignment = .center
            config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(
                pointSize: 18, weight: isSelected ? .bold : .semibold
            )
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var outgoing = incoming
                outgoing.font = UIFont.systemFont(ofSize: 10, weight: isSelected ? .bold : .bold)
                return outgoing
            }
            if isSelected {
                config.baseBackgroundColor = UIColor(red: 0.922, green: 0.812, blue: 0.592, alpha: 0.15) // Sand 15%
            }

            button.configuration = config
            button.titleLabel?.numberOfLines = 1
            button.titleLabel?.textAlignment = .center
            button.titleLabel?.lineBreakMode = .byWordWrapping
        }
    }
}
