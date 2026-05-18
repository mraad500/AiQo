//
//  OutdoorRunSession.swift
//  AiQo
//
//  Lifecycle + derived metrics for an Outdoor Running workout. GPS truth lives
//  in `RunLocationManager`; this owns the run state machine, the elapsed clock,
//  per-kilometre milestone feedback, and completion recording.
//

import Combine
import Foundation
import HealthKit
import SwiftUI
import UIKit

@MainActor
final class OutdoorRunSession: ObservableObject {

    enum Phase: Equatable {
        case ready      // permission ok, not started
        case running
        case paused
        case finished
    }

    // MARK: - Published state

    @Published private(set) var phase: Phase = .ready
    @Published private(set) var elapsedSeconds: Int = 0
    @Published private(set) var distanceMeters: Double = 0
    @Published var showMilestone = false
    @Published var milestoneText = ""
    @Published private(set) var finishedAt: Date?
    /// The Apple Watch companion workout is running (real HR + calories).
    @Published private(set) var isWatchActive = false
    /// Frozen at finish so the summary/share never disagree with what was saved.
    @Published private(set) var finalCalories: Double = 0
    @Published private(set) var finalAvgHeartRate: Double = 0

    let title: String

    private let connectivity = PhoneConnectivityManager.shared

    /// Rough kcal estimate (≈ a 70 kg runner), used only when no Watch is
    /// supplying real active energy. Matches what is written to history.
    var estimatedCalories: Double {
        (distanceMeters / 1000.0) * 62.0
    }

    /// Live calories — the Watch's real active energy when present, otherwise
    /// the GPS-based estimate so the figure is never blank.
    var liveCalories: Double {
        let watchEnergy = connectivity.activeEnergy
        return watchEnergy > 0 ? watchEnergy : estimatedCalories
    }

    /// Live heart rate from the Watch (0 when no Watch / no reading yet).
    var heartRate: Double {
        connectivity.currentHeartRate
    }

    // MARK: - Private

    private var timer: Timer?
    private var accumulatedBeforePause: TimeInterval = 0
    private var segmentStart: Date?
    private var lastMilestoneKm = 0
    private var hasRecorded = false

    // MARK: - Init

    init(title: String) {
        self.title = title
    }

    deinit {
        timer?.invalidate()
    }

    // MARK: - Derived

    var isActive: Bool {
        phase == .running || phase == .paused
    }

    /// Average pace over the whole run, in seconds per kilometre. Returns nil
    /// until enough distance exists for the figure to be meaningful.
    var averagePaceSecondsPerKm: Double? {
        guard distanceMeters >= 20, elapsedSeconds > 0 else { return nil }
        return Double(elapsedSeconds) / (distanceMeters / 1000.0)
    }

    /// Live pace derived from current GPS speed, falling back to the running
    /// average when the runner is momentarily slow/stopped.
    func livePaceSecondsPerKm(currentSpeedMetersPerSecond speed: Double) -> Double? {
        if speed > 0.5 {
            return 1000.0 / speed
        }
        return averagePaceSecondsPerKm
    }

    // MARK: - Controls

    func start() {
        guard phase == .ready else { return }
        phase = .running
        accumulatedBeforePause = 0
        segmentStart = Date()
        elapsedSeconds = 0
        lastMilestoneKm = 0
        startTimer()
        startWatchCompanionIfAvailable()
        AnalyticsService.shared.track(.workoutStarted(type: "running"))
    }

    func pause() {
        guard phase == .running else { return }
        accumulatedBeforePause += elapsedSinceSegmentStart()
        segmentStart = nil
        phase = .paused
        if isWatchActive { connectivity.pauseWorkoutOnWatch() }
    }

    func resume() {
        guard phase == .paused else { return }
        segmentStart = Date()
        phase = .running
        if isWatchActive { connectivity.resumeWorkoutOnWatch() }
    }

    /// Best-effort: the run is GPS-driven and never blocked on the Watch. If a
    /// reachable Watch exists we launch its workout so real HR + calories stream
    /// in; otherwise the run continues phone-only and HR shows "—".
    private func startWatchCompanionIfAvailable() {
        connectivity.refreshWatchConnectivityState()
        guard connectivity.canStartWorkoutFromPhone else { return }
        connectivity.launchWatchAppForWorkout(activityType: .running, locationType: .outdoor)
        isWatchActive = true
    }

    /// Ends the run, persists it to the rolling workout history, and reports
    /// analytics. Safe to call once; further calls are ignored.
    func finish() {
        guard phase != .finished else { return }
        if phase == .running {
            accumulatedBeforePause += elapsedSinceSegmentStart()
        }
        segmentStart = nil
        timer?.invalidate()
        timer = nil
        elapsedSeconds = Int(accumulatedBeforePause.rounded())
        finalCalories = liveCalories
        finalAvgHeartRate = connectivity.currentAverageHeartRate > 0
            ? connectivity.currentAverageHeartRate
            : connectivity.currentHeartRate
        finishedAt = Date()
        phase = .finished
        if isWatchActive { connectivity.endWorkoutOnWatch() }
        recordCompletionIfNeeded()
    }

    // MARK: - Distance feed (driven by the view observing RunLocationManager)

    func updateDistance(_ meters: Double) {
        guard phase == .running else { return }
        distanceMeters = meters
        checkMilestone()
    }

    // MARK: - Timer

    private func startTimer() {
        timer?.invalidate()
        let newTimer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    private func tick() {
        guard phase == .running else { return }
        let next = Int((accumulatedBeforePause + elapsedSinceSegmentStart()).rounded(.down))
        if next != elapsedSeconds {
            elapsedSeconds = next
        }
    }

    private func elapsedSinceSegmentStart() -> TimeInterval {
        guard let segmentStart else { return 0 }
        return max(0, Date().timeIntervalSince(segmentStart))
    }

    // MARK: - Milestones

    private func checkMilestone() {
        let km = Int(distanceMeters / 1000.0)
        guard km > 0, km > lastMilestoneKm else { return }
        lastMilestoneKm = km

        milestoneText = "\(km) " + L10n.t("gym.metrics.kmShort")
        withAnimation(.spring()) {
            showMilestone = true
        }

        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)

        let shownFor = km
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            guard let self, self.lastMilestoneKm == shownFor else { return }
            withAnimation {
                self.showMilestone = false
            }
        }
    }

    // MARK: - Completion

    private func recordCompletionIfNeeded() {
        guard !hasRecorded else { return }
        hasRecorded = true

        let durationMinutes = elapsedSeconds / 60
        let calories = finalCalories > 0 ? finalCalories : estimatedCalories

        WorkoutHistoryStore.shared.recordCompletion(
            title: title,
            durationSeconds: elapsedSeconds,
            activeCalories: calories,
            heartRate: finalAvgHeartRate > 0 ? finalAvgHeartRate : nil,
            distanceMeters: distanceMeters
        )

        AnalyticsService.shared.track(.workoutCompleted(
            type: "running",
            durationMin: durationMinutes,
            calories: Int(calories.rounded())
        ))
    }
}
