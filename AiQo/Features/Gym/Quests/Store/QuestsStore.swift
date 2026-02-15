internal import Combine
import Foundation
import UIKit

private struct QuestsDailyState: Codable {
    var dayKey: String
    var trackingChallengeIDs: [String]
    var completedChallengeIDs: [String]
    var manualProgress: [String: Double]
    var pushupUndoStack: [Int]
}

@MainActor
final class QuestsStore: ObservableObject {
    @Published private(set) var challenges: [Challenge] = Challenge.all
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

    private let stepsChallengeID = "steps_10k"
    private let plankChallengeID = "plank_ladder"
    private let pushupsChallengeID = "pushups_60"
    private let sleepChallengeID = "sleep_8h"
    private let activeKcalChallengeID = "active_kcal_600"

    private var questByID: [String: Challenge] {
        Dictionary(uniqueKeysWithValues: challenges.map { ($0.id, $0) })
    }

    private var rewardQueue: [PendingChallengeReward] = []
    private var pushupUndoStack: [Int] = []

    private let stateKey = "aiqo.gym.quests.daily-state.v1"
    private var activeDayKey: String

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

    func refreshOnAppear() {
        normalizeForCurrentDayIfNeeded()
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
        case .steps:
            return "\(Int(current.rounded()))/\(Int(challenge.goalValue)) \(L10n.t("quests.unit.steps"))"
        case .activeCalories:
            return "\(Int(current.rounded()))/\(Int(challenge.goalValue)) \(L10n.t("quests.unit.kcal"))"
        case .plankSeconds:
            return "\(Int(current.rounded()))/\(Int(challenge.goalValue)) \(L10n.t("quests.unit.sec"))"
        case .pushups:
            return "\(Int(current.rounded()))/\(Int(challenge.goalValue)) \(L10n.t("quests.unit.reps"))"
        }
    }

    func isTracking(_ challenge: Challenge) -> Bool {
        trackingChallengeIDs.contains(challenge.id)
    }

    func isCompleted(_ challenge: Challenge) -> Bool {
        completedChallengeIDs.contains(challenge.id) || winsStore.hasWin(for: challenge.id, on: Date())
    }

    func startChallenge(_ challenge: Challenge) {
        normalizeForCurrentDayIfNeeded()
        trackingChallengeIDs.insert(challenge.id)
        saveDailyState()

        if challenge.isAutomatic {
            refreshAutoChallenges()
        }
    }

    func startPlankTimer() {
        normalizeForCurrentDayIfNeeded()
        startChallengeIfNeeded(plankChallengeID)

        guard !isPlankTimerRunning else { return }
        isPlankTimerRunning = true
        currentPlankSetSeconds = 0

        plankTicker = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                self.currentPlankSetSeconds += 1
            }
    }

    func finishPlankSet() {
        guard isPlankTimerRunning else { return }

        let elapsed = max(currentPlankSetSeconds, 0)

        plankTicker?.cancel()
        plankTicker = nil
        isPlankTimerRunning = false
        currentPlankSetSeconds = 0

        guard elapsed > 0 else { return }

        let current = progressByChallengeID[plankChallengeID] ?? 0
        let updated = current + Double(elapsed)
        progressByChallengeID[plankChallengeID] = updated

        evaluateCompletionIfNeeded(forChallengeID: plankChallengeID, achievedValue: updated)
        saveDailyState()
    }

    func addPushups(_ reps: Int) {
        guard reps > 0 else { return }
        normalizeForCurrentDayIfNeeded()
        startChallengeIfNeeded(pushupsChallengeID)

        let current = progressByChallengeID[pushupsChallengeID] ?? 0
        let updated = current + Double(reps)
        progressByChallengeID[pushupsChallengeID] = updated

        pushupUndoStack.append(reps)
        evaluateCompletionIfNeeded(forChallengeID: pushupsChallengeID, achievedValue: updated)
        saveDailyState()
    }

    func undoPushups() {
        guard let last = pushupUndoStack.popLast() else { return }

        let current = progressByChallengeID[pushupsChallengeID] ?? 0
        let updated = max(0, current - Double(last))
        progressByChallengeID[pushupsChallengeID] = updated
        saveDailyState()
    }

    func canUndoPushups() -> Bool {
        !pushupUndoStack.isEmpty
    }

    func claimActiveReward() {
        guard let reward = activeReward else { return }

        winsStore.addWin(
            challenge: reward.challenge,
            completedAt: reward.completedAt,
            proofValue: reward.proofValue
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
            return challenge.isAutomatic
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
        progressByChallengeID[stepsChallengeID] = summary.steps
        progressByChallengeID[sleepChallengeID] = summary.sleepHours
        progressByChallengeID[activeKcalChallengeID] = summary.activeKcal

        evaluateCompletionIfNeeded(forChallengeID: stepsChallengeID, achievedValue: summary.steps)
        evaluateCompletionIfNeeded(forChallengeID: sleepChallengeID, achievedValue: summary.sleepHours)
        evaluateCompletionIfNeeded(forChallengeID: activeKcalChallengeID, achievedValue: summary.activeKcal)

        saveDailyState()
    }

    private func evaluateCompletionIfNeeded(forChallengeID challengeID: String, achievedValue: Double) {
        guard let challenge = questByID[challengeID] else { return }
        guard trackingChallengeIDs.contains(challengeID) else { return }
        guard !isCompleted(challenge) else { return }
        guard achievedValue >= challenge.goalValue else { return }

        completedChallengeIDs.insert(challengeID)
        trackingChallengeIDs.remove(challengeID)

        if challengeID == plankChallengeID {
            plankTicker?.cancel()
            plankTicker = nil
            isPlankTimerRunning = false
            currentPlankSetSeconds = 0
        }

        enqueueReward(
            PendingChallengeReward(
                challenge: challenge,
                completedAt: Date(),
                proofValue: proofValue(for: challenge, achievedValue: achievedValue)
            )
        )
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
        }
    }

    private func normalizeForCurrentDayIfNeeded() {
        let today = Self.dayKey(for: Date())
        guard today != activeDayKey else { return }

        activeDayKey = today
        trackingChallengeIDs.removeAll()
        completedChallengeIDs.removeAll()
        progressByChallengeID[plankChallengeID] = 0
        progressByChallengeID[pushupsChallengeID] = 0
        pushupUndoStack.removeAll()
        rewardQueue.removeAll()
        activeReward = nil

        plankTicker?.cancel()
        plankTicker = nil
        isPlankTimerRunning = false
        currentPlankSetSeconds = 0

        saveDailyState()
    }

    private func loadDailyState() {
        guard let data = defaults.data(forKey: stateKey) else {
            progressByChallengeID[plankChallengeID] = 0
            progressByChallengeID[pushupsChallengeID] = 0
            return
        }

        do {
            let state = try JSONDecoder().decode(QuestsDailyState.self, from: data)
            activeDayKey = state.dayKey
            trackingChallengeIDs = Set(state.trackingChallengeIDs)
            completedChallengeIDs = Set(state.completedChallengeIDs)
            progressByChallengeID[plankChallengeID] = state.manualProgress[plankChallengeID] ?? 0
            progressByChallengeID[pushupsChallengeID] = state.manualProgress[pushupsChallengeID] ?? 0
            pushupUndoStack = state.pushupUndoStack
            normalizeForCurrentDayIfNeeded()
        } catch {
            progressByChallengeID[plankChallengeID] = 0
            progressByChallengeID[pushupsChallengeID] = 0
        }
    }

    private func saveDailyState() {
        let state = QuestsDailyState(
            dayKey: activeDayKey,
            trackingChallengeIDs: Array(trackingChallengeIDs),
            completedChallengeIDs: Array(completedChallengeIDs),
            manualProgress: [
                plankChallengeID: progressByChallengeID[plankChallengeID] ?? 0,
                pushupsChallengeID: progressByChallengeID[pushupsChallengeID] ?? 0
            ],
            pushupUndoStack: pushupUndoStack
        )

        do {
            let data = try JSONEncoder().encode(state)
            defaults.set(data, forKey: stateKey)
        } catch {
            // Keep runtime state even if persistence fails.
        }
    }

    private static func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
