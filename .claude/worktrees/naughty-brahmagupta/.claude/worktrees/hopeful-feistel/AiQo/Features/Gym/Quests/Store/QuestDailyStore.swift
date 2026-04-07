internal import Combine
import Foundation
import UIKit

private struct DailyChallengeCompletion: Codable, Hashable {
    let challengeId: String
    let completedDayKey: String
    let proofValue: String
}

private struct QuestDailyStateV3: Codable {
    var dayKey: String
    var trackingChallengeIDs: [String]
    var completionRecords: [DailyChallengeCompletion]
    var manualProgress: [String: Double]
    var pushupUndoStacks: [String: [Int]]
}

private struct QuestDailyStateV2: Codable {
    var dayKey: String
    var trackingChallengeIDs: [String]
    var completionRecords: [DailyChallengeCompletion]
    var manualProgress: [String: Double]
    var pushupUndoStack: [Int]
}

private struct LegacyQuestDailyStateV1: Codable {
    var dayKey: String
    var trackingChallengeIDs: [String]
    var completedChallengeIDs: [String]
    var manualProgress: [String: Double]
    var pushupUndoStack: [Int]
}

enum QuestCardState {
    case locked
    case ready
    case tracking
    case completed
}

@MainActor
final class QuestDailyStore: ObservableObject {
    @Published private(set) var progressByChallengeID: [String: Double] = [:]
    @Published private(set) var trackingChallengeIDs: Set<String> = []
    @Published private(set) var completedChallengeIDs: Set<String> = []
    @Published private(set) var activeReward: PendingChallengeReward?

    @Published private(set) var isPlankTimerRunning = false
    @Published private(set) var currentPlankSetSeconds = 0
    @Published var selectedPlankPresetSeconds = 30

    private let winsStore: WinsStore
    private let healthService: HealthKitService
    private let defaults: UserDefaults

    private let challenges = Challenge.all

    private var questByID: [String: Challenge] {
        Dictionary(uniqueKeysWithValues: challenges.map { ($0.id, $0) })
    }

    private var manualChallengeIDs: [String] {
        challenges.filter { $0.type == .manual }.map(\.id)
    }

    private var rewardQueue: [PendingChallengeReward] = []
    private var pushupUndoStacks: [String: [Int]] = [:]
    private var completionRecords: [DailyChallengeCompletion] = []

    private let stateKeyV3 = "aiqo.gym.quests.daily-state.v3"
    private let stateKeyV2 = "aiqo.gym.quests.daily-state.v2"
    private let stateKeyV1 = "aiqo.gym.quests.daily-state.v1"
    private var activeDayKey: String

    private var activePlankChallengeID: String?
    private var plankTicker: AnyCancellable?
    private var refreshTicker: AnyCancellable?
    private var foregroundObserver: AnyCancellable?

    init(
        winsStore: WinsStore,
        defaults: UserDefaults = .standard,
        healthService: HealthKitService = .shared
    ) {
        self.winsStore = winsStore
        self.defaults = defaults
        self.healthService = healthService
        self.activeDayKey = Self.dayKey(for: Date())

        loadDailyState()
        startObserversIfNeeded()
    }

    func challenges(forStage stageNumber: Int) -> [Challenge] {
        Challenge.forStage(stageNumber)
    }

    var availableStageNumbers: [Int] {
        Challenge.availableStageNumbers
    }

    func refreshOnAppear() {
        normalizeForCurrentDayIfNeeded()
        refreshBossProgress()
        refreshAutoChallenges()
    }

    func progress(for challenge: Challenge) -> Double {
        progressByChallengeID[challenge.id] ?? 0
    }

    func progressFraction(for challenge: Challenge) -> Double {
        guard challenge.goalValue > 0 else { return 0 }
        return min(progress(for: challenge) / challenge.goalValue, 1)
    }

    func progressText(for challenge: Challenge) -> String {
        let current = progress(for: challenge)
        switch challenge.metricType {
        case .sleepHours:
            return String(
                format: "%.1f/%.1f %@",
                locale: Locale.current,
                current,
                challenge.goalValue,
                L10n.t("quests.unit.h")
            )
        case .distanceKilometers:
            return String(
                format: "%.1f/%.1f %@",
                locale: Locale.current,
                current,
                challenge.goalValue,
                L10n.t("quests.unit.km")
            )
        case .questCompletions:
            return "\(Int(current.rounded()))/\(questCompletionsTargetCount(for: challenge)) \(L10n.t("quests.unit.quests"))"
        case .steps:
            return "\(Int(current.rounded()))/\(Int(challenge.goalValue)) \(L10n.t("quests.unit.steps"))"
        case .activeCalories:
            return "\(Int(current.rounded()))/\(Int(challenge.goalValue)) \(L10n.t("quests.unit.kcal"))"
        case .plankSeconds:
            return "\(Int(current.rounded()))/\(Int(challenge.goalValue)) \(L10n.t("quests.unit.sec"))"
        case .pushups:
            return "\(Int(current.rounded()))/\(Int(challenge.goalValue)) \(L10n.t("quests.unit.reps"))"
        case .kindnessActs:
            return "\(Int(current.rounded()))/\(Int(challenge.goalValue)) \(L10n.t("quests.unit.helps"))"
        case .zone2Minutes:
            return "\(Int(current.rounded()))/\(Int(challenge.goalValue)) \(L10n.t("quests.unit.min"))"
        case .mindfulnessSessions:
            return "\(Int(current.rounded()))/\(Int(challenge.goalValue)) \(L10n.t("quests.unit.sessions"))"
        case .sleepStreakDays:
            return "\(Int(current.rounded()))/\(Int(challenge.goalValue)) \(L10n.t("quests.unit.days"))"
        }
    }

    func isTracking(_ challenge: Challenge) -> Bool {
        trackingChallengeIDs.contains(challenge.id)
    }

    func isCompleted(_ challenge: Challenge) -> Bool {
        completedChallengeIDs.contains(challenge.id)
    }

    func cardState(for challenge: Challenge) -> QuestCardState {
        if !isChallengeUnlocked(challenge) {
            return .locked
        }
        if isCompleted(challenge) {
            return .completed
        }
        if isTracking(challenge) {
            return .tracking
        }
        return .ready
    }

    func isChallengeUnlocked(_ challenge: Challenge) -> Bool {
        isStageUnlocked(challenge.stageNumber)
    }

    func isStageUnlocked(_ stageNumber: Int) -> Bool {
        guard let previousStage = Challenge.previousStage(before: stageNumber) else {
            return true
        }

        let previousStageChallenges = Challenge.nonBossChallenges(forStage: previousStage)
        guard !previousStageChallenges.isEmpty else {
            return true
        }

        return previousStageChallenges.allSatisfy { challenge in
            hasRecordedCompletion(forChallengeID: challenge.id)
        }
    }

    func isPlankTimerRunning(for challenge: Challenge) -> Bool {
        isPlankTimerRunning && activePlankChallengeID == challenge.id
    }

    func startChallenge(_ challenge: Challenge) {
        guard isChallengeUnlocked(challenge) else { return }

        normalizeForCurrentDayIfNeeded()
        trackingChallengeIDs.insert(challenge.id)

        if challenge.metricType == .questCompletions {
            refreshBossProgress()
        } else if challenge.isHealthKitBacked {
            refreshAutoChallenges()
        }

        saveDailyState()
    }

    func startPlankTimer(for challenge: Challenge) {
        guard challenge.metricType == .plankSeconds else { return }
        guard isChallengeUnlocked(challenge) else { return }

        normalizeForCurrentDayIfNeeded()
        startChallengeIfNeeded(challenge.id)

        guard !isPlankTimerRunning else { return }

        activePlankChallengeID = challenge.id
        isPlankTimerRunning = true
        currentPlankSetSeconds = 0

        plankTicker = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                self.currentPlankSetSeconds += 1
            }

        saveDailyState()
    }

    func finishPlankSet(for challenge: Challenge) {
        guard challenge.metricType == .plankSeconds else { return }
        guard isPlankTimerRunning, activePlankChallengeID == challenge.id else { return }

        let elapsed = max(currentPlankSetSeconds, 0)

        plankTicker?.cancel()
        plankTicker = nil
        isPlankTimerRunning = false
        currentPlankSetSeconds = 0
        activePlankChallengeID = nil

        guard elapsed > 0 else {
            saveDailyState()
            return
        }

        let current = progressByChallengeID[challenge.id] ?? 0
        let updated = current + Double(elapsed)
        progressByChallengeID[challenge.id] = updated

        evaluateCompletionIfNeeded(forChallengeID: challenge.id, achievedValue: updated)
        saveDailyState()
    }

    func addManualProgress(_ amount: Int, for challenge: Challenge) {
        guard amount > 0 else { return }
        guard challenge.metricType.supportsManualCounter else { return }
        guard isChallengeUnlocked(challenge) else { return }

        normalizeForCurrentDayIfNeeded()
        startChallengeIfNeeded(challenge.id)

        let current = progressByChallengeID[challenge.id] ?? 0
        let updated = current + Double(amount)
        progressByChallengeID[challenge.id] = updated

        pushupUndoStacks[challenge.id, default: []].append(amount)

        evaluateCompletionIfNeeded(forChallengeID: challenge.id, achievedValue: updated)
        saveDailyState()
    }

    func undoLastManualProgress(for challenge: Challenge) {
        guard challenge.metricType.supportsManualCounter else { return }
        guard var stack = pushupUndoStacks[challenge.id], let last = stack.popLast() else { return }

        pushupUndoStacks[challenge.id] = stack

        let current = progressByChallengeID[challenge.id] ?? 0
        let updated = max(0, current - Double(last))
        progressByChallengeID[challenge.id] = updated
        saveDailyState()
    }

    func canUndoManualProgress(for challenge: Challenge) -> Bool {
        guard challenge.metricType.supportsManualCounter else { return false }
        return !(pushupUndoStacks[challenge.id] ?? []).isEmpty
    }

    // Backward-compatible wrappers used by existing push-ups flows.
    func addPushups(_ reps: Int, for challenge: Challenge) {
        addManualProgress(reps, for: challenge)
    }

    func undoPushups(for challenge: Challenge) {
        undoLastManualProgress(for: challenge)
    }

    func canUndoPushups(for challenge: Challenge) -> Bool {
        canUndoManualProgress(for: challenge)
    }

    func claimActiveReward() {
        guard let reward = activeReward else { return }

        winsStore.addWin(
            challenge: reward.challenge,
            completedAt: reward.completedAt,
            completedDayKey: reward.completedDayKey,
            proofValue: reward.proofValue,
            isBoss: reward.isBoss
        )

        showNextRewardIfNeeded()
    }

    private func startChallengeIfNeeded(_ challengeID: String) {
        if !trackingChallengeIDs.contains(challengeID) {
            trackingChallengeIDs.insert(challengeID)
        }
    }

    private func startObserversIfNeeded() {
        if refreshTicker == nil {
            refreshTicker = Timer.publish(every: 180, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in
                    guard let self else { return }
                    self.refreshAutoChallengesIfTrackingActive()
                }
        }

        if foregroundObserver == nil {
            foregroundObserver = NotificationCenter.default
                .publisher(for: UIApplication.willEnterForegroundNotification)
                .sink { [weak self] _ in
                    guard let self else { return }
                    self.refreshAutoChallenges()
                }
        }
    }

    private func refreshAutoChallengesIfTrackingActive() {
        let trackedAutoIDs = trackingChallengeIDs.filter { id in
            guard let challenge = questByID[id] else { return false }
            return challenge.isHealthKitBacked
        }

        guard !trackedAutoIDs.isEmpty else { return }
        refreshAutoChallenges()
    }

    private func refreshAutoChallenges() {
        normalizeForCurrentDayIfNeeded()

        Task { [weak self] in
            guard let self else { return }

            let authorized = (try? await self.healthService.requestAuthorization()) ?? false
            guard authorized else { return }

            guard let summary = try? await self.healthService.fetchTodaySummary() else { return }
            self.apply(summary: summary)
        }
    }

    private func apply(summary: TodaySummary) {
        for challenge in challenges where challenge.isHealthKitBacked {
            guard let achievedValue = healthMetricValue(for: challenge.metricType, summary: summary) else {
                continue
            }

            progressByChallengeID[challenge.id] = achievedValue
            evaluateCompletionIfNeeded(forChallengeID: challenge.id, achievedValue: achievedValue)
        }

        refreshBossProgress()
        saveDailyState()
    }

    private func healthMetricValue(for metricType: ChallengeMetricType, summary: TodaySummary) -> Double? {
        switch metricType {
        case .steps:
            return summary.steps
        case .sleepHours:
            return summary.sleepHours
        case .activeCalories:
            return summary.activeKcal
        case .distanceKilometers:
            return summary.distanceMeters / 1000.0
        case .plankSeconds, .pushups, .questCompletions, .kindnessActs, .zone2Minutes, .mindfulnessSessions, .sleepStreakDays:
            return nil
        }
    }

    private func evaluateCompletionIfNeeded(forChallengeID challengeID: String, achievedValue: Double) {
        guard let challenge = questByID[challengeID] else { return }
        guard trackingChallengeIDs.contains(challengeID) else { return }
        guard !isCompleted(challenge) else { return }
        guard achievedValue >= challenge.goalValue else { return }

        let proof = proofValue(for: challenge, achievedValue: achievedValue)
        completionRecords.removeAll { $0.challengeId == challengeID && $0.completedDayKey == activeDayKey }
        completionRecords.append(
            DailyChallengeCompletion(
                challengeId: challengeID,
                completedDayKey: activeDayKey,
                proofValue: proof
            )
        )
        syncCompletedChallengeIDsForActiveDay()
        trackingChallengeIDs.remove(challengeID)

        if activePlankChallengeID == challengeID {
            plankTicker?.cancel()
            plankTicker = nil
            isPlankTimerRunning = false
            currentPlankSetSeconds = 0
            activePlankChallengeID = nil
        }

        enqueueReward(
            PendingChallengeReward(
                challenge: challenge,
                completedAt: Date(),
                completedDayKey: activeDayKey,
                proofValue: proof,
                isBoss: challenge.isBoss
            )
        )

        if !challenge.isBoss {
            refreshBossProgress()
        }
    }

    private func refreshBossProgress() {
        let bossChallenges = challenges.filter(\.isBoss)

        for boss in bossChallenges {
            let stageDailyChallenges = Challenge.nonBossChallenges(forStage: boss.stageNumber)
            let completedCount = stageDailyChallenges.reduce(0) { partial, challenge in
                partial + (completedChallengeIDs.contains(challenge.id) ? 1 : 0)
            }

            let achievedValue = Double(completedCount)
            progressByChallengeID[boss.id] = achievedValue
            evaluateCompletionIfNeeded(forChallengeID: boss.id, achievedValue: achievedValue)
        }
    }

    private func enqueueReward(_ reward: PendingChallengeReward) {
        if activeReward == nil {
            activeReward = reward
        } else {
            rewardQueue.append(reward)
        }
    }

    private func showNextRewardIfNeeded() {
        if rewardQueue.isEmpty {
            activeReward = nil
        } else {
            activeReward = rewardQueue.removeFirst()
        }
    }

    private func proofValue(for challenge: Challenge, achievedValue: Double) -> String {
        switch challenge.metricType {
        case .sleepHours:
            let rounded = (achievedValue * 10).rounded() / 10
            let display = String(format: "%.1f", locale: Locale.current, rounded)
            return "\(L10n.t("quests.metric.sleep")): \(display) \(L10n.t("quests.unit.h"))"
        case .steps:
            return "\(L10n.t("quests.metric.steps")): \(Int(achievedValue.rounded()))"
        case .plankSeconds:
            return "\(L10n.t("quests.metric.plank")): \(Int(achievedValue.rounded())) \(L10n.t("quests.unit.sec"))"
        case .pushups:
            return "\(L10n.t("quests.metric.pushups")): \(Int(achievedValue.rounded())) \(L10n.t("quests.unit.reps"))"
        case .activeCalories:
            return "\(L10n.t("quests.metric.active")): \(Int(achievedValue.rounded())) \(L10n.t("quests.unit.kcal"))"
        case .distanceKilometers:
            let display = String(format: "%.1f", locale: Locale.current, achievedValue)
            return "\(L10n.t("quests.metric.distance")): \(display) \(L10n.t("quests.unit.km"))"
        case .questCompletions:
            return "\(L10n.t("quests.metric.stage2")): \(Int(achievedValue.rounded()))/\(questCompletionsTargetCount(for: challenge)) \(L10n.t("quests.unit.quests"))"
        case .kindnessActs:
            return "\(L10n.t("quests.metric.kindness")): \(Int(achievedValue.rounded())) \(L10n.t("quests.unit.helps"))"
        case .zone2Minutes:
            return "\(L10n.t("quests.metric.zone2")): \(Int(achievedValue.rounded())) \(L10n.t("quests.unit.min"))"
        case .mindfulnessSessions:
            return "\(L10n.t("quests.metric.mindfulness")): \(Int(achievedValue.rounded())) \(L10n.t("quests.unit.sessions"))"
        case .sleepStreakDays:
            return "\(L10n.t("quests.metric.sleep_streak")): \(Int(achievedValue.rounded()))/\(Int(challenge.goalValue.rounded())) \(L10n.t("quests.unit.days"))"
        }
    }

    private func normalizeForCurrentDayIfNeeded() {
        let today = Self.dayKey(for: Date())
        guard today != activeDayKey else { return }

        activeDayKey = today
        trackingChallengeIDs.removeAll()
        syncCompletedChallengeIDsForActiveDay()

        for challenge in challenges {
            progressByChallengeID[challenge.id] = 0
        }

        pushupUndoStacks.removeAll()
        rewardQueue.removeAll()
        activeReward = nil

        plankTicker?.cancel()
        plankTicker = nil
        isPlankTimerRunning = false
        currentPlankSetSeconds = 0
        activePlankChallengeID = nil

        refreshBossProgress()
        saveDailyState()
    }

    private func loadDailyState() {
        for challenge in challenges {
            progressByChallengeID[challenge.id] = 0
        }

        if let data = defaults.data(forKey: stateKeyV3),
           let state = try? JSONDecoder().decode(QuestDailyStateV3.self, from: data) {
            applyLoadedState(
                dayKey: state.dayKey,
                trackingChallengeIDs: state.trackingChallengeIDs,
                completionRecords: state.completionRecords,
                manualProgress: state.manualProgress,
                pushupUndoStacks: state.pushupUndoStacks
            )
            return
        }

        if let data = defaults.data(forKey: stateKeyV2),
           let state = try? JSONDecoder().decode(QuestDailyStateV2.self, from: data) {
            var migratedUndoStacks: [String: [Int]] = [:]
            if !state.pushupUndoStack.isEmpty {
                migratedUndoStacks["pushups_60"] = state.pushupUndoStack
            }

            applyLoadedState(
                dayKey: state.dayKey,
                trackingChallengeIDs: state.trackingChallengeIDs,
                completionRecords: state.completionRecords,
                manualProgress: state.manualProgress,
                pushupUndoStacks: migratedUndoStacks
            )

            saveDailyState()
            defaults.removeObject(forKey: stateKeyV2)
            return
        }

        if let data = defaults.data(forKey: stateKeyV1),
           let state = try? JSONDecoder().decode(LegacyQuestDailyStateV1.self, from: data) {
            let migratedRecords = state.completedChallengeIDs.map {
                DailyChallengeCompletion(
                    challengeId: $0,
                    completedDayKey: state.dayKey,
                    proofValue: ""
                )
            }

            var migratedUndoStacks: [String: [Int]] = [:]
            if !state.pushupUndoStack.isEmpty {
                migratedUndoStacks["pushups_60"] = state.pushupUndoStack
            }

            applyLoadedState(
                dayKey: state.dayKey,
                trackingChallengeIDs: state.trackingChallengeIDs,
                completionRecords: migratedRecords,
                manualProgress: state.manualProgress,
                pushupUndoStacks: migratedUndoStacks
            )

            saveDailyState()
            defaults.removeObject(forKey: stateKeyV1)
            return
        }

        completionRecords = []
        trackingChallengeIDs = Set()
        pushupUndoStacks = [:]
        syncCompletedChallengeIDsForActiveDay()
        refreshBossProgress()
    }

    private func applyLoadedState(
        dayKey: String,
        trackingChallengeIDs: [String],
        completionRecords: [DailyChallengeCompletion],
        manualProgress: [String: Double],
        pushupUndoStacks: [String: [Int]]
    ) {
        activeDayKey = dayKey
        self.trackingChallengeIDs = Set(trackingChallengeIDs)
        self.completionRecords = completionRecords

        for challengeID in manualChallengeIDs {
            progressByChallengeID[challengeID] = manualProgress[challengeID] ?? 0
        }

        self.pushupUndoStacks = pushupUndoStacks
        syncCompletedChallengeIDsForActiveDay()
        refreshBossProgress()
        normalizeForCurrentDayIfNeeded()
    }

    private func questCompletionsTargetCount(for challenge: Challenge) -> Int {
        let stageDailyCount = Challenge.nonBossChallenges(forStage: challenge.stageNumber).count
        return max(stageDailyCount, Int(challenge.goalValue.rounded()))
    }

    private func hasRecordedCompletion(forChallengeID challengeID: String) -> Bool {
        if completedChallengeIDs.contains(challengeID) {
            return true
        }
        return winsStore.wins.contains { $0.challengeId == challengeID }
    }

    private func saveDailyState() {
        var manualProgress: [String: Double] = [:]
        for challengeID in manualChallengeIDs {
            manualProgress[challengeID] = progressByChallengeID[challengeID] ?? 0
        }

        let state = QuestDailyStateV3(
            dayKey: activeDayKey,
            trackingChallengeIDs: Array(trackingChallengeIDs),
            completionRecords: completionRecords,
            manualProgress: manualProgress,
            pushupUndoStacks: pushupUndoStacks
        )

        do {
            let data = try JSONEncoder().encode(state)
            defaults.set(data, forKey: stateKeyV3)
        } catch {
            // Keep runtime state even if persistence fails.
        }
    }

    private func syncCompletedChallengeIDsForActiveDay() {
        completedChallengeIDs = Set(
            completionRecords
                .filter { $0.completedDayKey == activeDayKey }
                .map(\.challengeId)
        )
    }

    private static func dayKey(for date: Date) -> String {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: startOfDay)
    }
}
