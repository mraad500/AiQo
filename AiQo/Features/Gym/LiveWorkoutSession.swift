// ===============================================
// File: LiveWorkoutSession.swift
// Target: iOS
// ===============================================

import AVFoundation
import Foundation
import HealthKit
import SwiftUI
import UIKit
import Combine

@MainActor
final class LiveWorkoutSession: ObservableObject {
    
    // MARK: - Workout Phases
    enum Phase: Equatable {
        case idle       // Ready to start
        case starting   // Connecting to Watch
        case running    // Workout active
        case paused     // Temporarily paused
        case ending     // Saving workout
    }

    enum Zone2AuraState: Equatable {
        case inactive
        case warmingUp
        case inZone2
        case tooFast
        case tooSlow
    }

    // MARK: - Configuration
    let activityType: HKWorkoutActivityType
    let locationType: HKWorkoutSessionLocationType
    let currentWorkout: GymWorkoutKind
    let coachingProfile: WorkoutCoachingProfile
    
    // MARK: - Managers
    private let connectivity = PhoneConnectivityManager.shared
    private let liveActivity = WorkoutLiveActivityManager.shared
    
    // MARK: - Published State
    
    @Published var title: String = ""
    @Published var phase: Phase = .idle {
        didSet {
            guard phase != oldValue else { return }
            // The "ending" phase is the only one that depends on the watch
            // sending back a terminal confirmation. If that confirmation is
            // lost over the air (or the watch hangs finishing its HealthKit
            // save) the user would be stuck on "جاري الإنهاء..." forever, so
            // we arm a watchdog the moment we enter it and disarm on exit.
            if phase == .ending {
                armEndTimeoutWatchdog()
            } else {
                cancelEndTimeoutWatchdog()
            }
        }
    }

    // Live workout data (updated in real-time from Watch)
    @Published var heartRate: Double = 0
    @Published var activeEnergy: Double = 0
    @Published var distanceMeters: Double = 0
    @Published var elapsedSeconds: Int = 0

    @Published private(set) var zone2AuraState: Zone2AuraState = .inactive
    @Published private(set) var zone2LowerBoundBPM: Double = 0
    @Published private(set) var zone2UpperBoundBPM: Double = 0
    @Published private(set) var resolvedUserAge: Int = 0
    @Published private(set) var activeLiveBuffs: [WorkoutActivityAttributes.Buff] = []
    @Published private(set) var remoteConnectionState: WorkoutConnectionState = .idle
    @Published private(set) var mirroredSessionID: String?
    @Published private(set) var isControlPending: Bool = false
    
    @Published var isWatchReachable: Bool = false
    
    // Milestone alert properties (shown when completing each km)
    @Published var showMilestoneAlert: Bool = false
    @Published var milestoneAlertText: String = ""
    
    // Error handling
    @Published var lastError: String? = nil
    
    // Private tracking
    private var lastRecordedKm: Int = 0
    private var cancellables = Set<AnyCancellable>()
    private let audioCoachManager = AudioCoachManager()
    private var elapsedAnchorSeconds: TimeInterval = 0
    private var elapsedAnchorDate: Date?
    private var smoothingTimer: Timer?
    private var liveActivityIsActive = false
    private var isCaptainWarmupAmbientActive = false
    private var hasRegisteredCaptainWarmupAmbient = false
    private var captainWarmupAmbientPlayer: AVAudioPlayer?
    private var captainWarmupAmbientFadeTask: Task<Void, Never>?
    private var shouldIgnoreIncomingSnapshots = false
    private var endTimeoutTask: Task<Void, Never>?

    /// How long to wait for the watch to confirm an end before finalizing the
    /// workout locally. The end command is already dispatched by then; this only
    /// guards against a lost acknowledgement / terminal snapshot.
    private static let endConfirmationTimeoutSeconds: UInt64 = 12

    private static let captainWarmupAmbientTrackName = "SoundOfEnergy"
    private static let captainWarmupAmbientLoopDurationSeconds = 360
    private static let captainWarmupAmbientBaseVolume: Float = 0.30
    private static let captainWarmupAmbientDuckedVolume: Float = 0.10
    
    // MARK: - Computed Properties
    
    var statusText: String {
        if remoteConnectionState == .disconnected && phase != .idle {
            return L10n.t("gym.session.status.disconnected")
        }

        if isControlPending {
            return L10n.t("gym.session.status.syncing")
        }

        switch phase {
        case .idle: return L10n.t("gym.session.status.ready")
        case .starting: return L10n.t("gym.session.status.connecting")
        case .running: return L10n.t("gym.session.status.active")
        case .paused: return L10n.t("gym.session.status.paused")
        case .ending: return L10n.t("gym.session.status.saving")
        }
    }
    
    var canStart: Bool { phase == .idle && !isControlPending }
    var canEnd: Bool { (phase == .running || phase == .paused) && canSendControlCommand }
    var canPause: Bool { phase == .running && canSendControlCommand }
    var canResume: Bool { phase == .paused && canSendControlCommand }

    private var canSendControlCommand: Bool {
        !isControlPending && remoteConnectionState != .disconnected && remoteConnectionState != .failed
    }

    /// Stable bounded-cardinality label for analytics. Maps `HKWorkoutActivityType`
    /// values used in this app to short strings; everything else collapses to `"other"`
    /// so a new HK type doesn't silently inflate the analytics dimension.
    private var workoutTypeLabel: String {
        switch activityType {
        case .running: return "running"
        case .walking: return "walking"
        case .cycling: return "cycling"
        case .traditionalStrengthTraining: return "strength"
        case .highIntensityIntervalTraining: return "hiit"
        case .swimming: return "swimming"
        case .yoga: return "yoga"
        default: return "other"
        }
    }

    var isZone2GuidedWorkout: Bool {
        coachingProfile == .captainHamoudiZone2
    }

    var isZone2WarmupActive: Bool {
        isZone2GuidedWorkout && elapsedSeconds < AudioCoachManager.warmUpDurationSeconds
    }

    var zone2WarmupRemainingSeconds: Int {
        max(AudioCoachManager.warmUpDurationSeconds - elapsedSeconds, 0)
    }

    var zone2RangeLabel: String {
        guard isZone2GuidedWorkout else { return "--" }
        let lower = Int(zone2LowerBoundBPM.rounded())
        let upper = Int(zone2UpperBoundBPM.rounded())
        return "\(lower)-\(upper) \(L10n.t("heart.bpmUnit"))"
    }
    
    // MARK: - Initialization
    
    init(
        title: String? = nil,
        activityType: HKWorkoutActivityType = .other,
        locationType: HKWorkoutSessionLocationType = .unknown,
        currentWorkout: GymWorkoutKind = .standard,
        coachingProfile: WorkoutCoachingProfile = .standard
    ) {
        self.title = title ?? L10n.t("gym.session.defaultTitle")
        self.activityType = activityType
        self.locationType = locationType
        self.currentWorkout = currentWorkout
        self.coachingProfile = coachingProfile
        
        refreshZone2Configuration()
        audioCoachManager.reset(for: currentWorkout, zone2Target: resolvedZone2Target)
        zone2AuraState = isZone2GuidedWorkout ? .warmingUp : .inactive
        setupBindings()
        startElapsedSmoothingTimer()
    }

    // MARK: - Data Bindings
    
    private func setupBindings() {
        connectivity.$workoutConnectionState
            .receive(on: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] state in
                self?.applyConnectionState(state)
            }
            .store(in: &cancellables)

        connectivity.$latestSnapshot
            .receive(on: RunLoop.main)
            .sink { [weak self] snapshot in
                guard let snapshot else { return }
                self?.applyRemoteSnapshot(snapshot)
            }
            .store(in: &cancellables)

        connectivity.$currentWorkoutPhase
            .receive(on: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] remotePhase in
                self?.applyRemotePhaseFallback(remotePhase)
            }
            .store(in: &cancellables)

        connectivity.$isCommandInFlight
            .receive(on: RunLoop.main)
            .removeDuplicates()
            .assign(to: &$isControlPending)

        connectivity.$mirroredSessionID
            .receive(on: RunLoop.main)
            .removeDuplicates()
            .assign(to: &$mirroredSessionID)

        connectivity.$lastError
            .receive(on: RunLoop.main)
            .sink { [weak self] error in
                self?.lastError = error == "None" ? nil : error
            }
            .store(in: &cancellables)

        CaptainVoiceService.shared.$isSpeaking
            .receive(on: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] isSpeaking in
                self?.syncCaptainWarmupAmbientSpeechState(isSpeaking)
            }
            .store(in: &cancellables)
    }

    // MARK: - Milestone Detection (Haptic + Visual Alert)
    
    private func checkForMilestone(totalMeters: Double) {
        let currentKm = Int(totalMeters / 1000)
        
        // Trigger when a NEW kilometer is completed
        if currentKm > 0 && currentKm > lastRecordedKm {
            lastRecordedKm = currentKm
            
            // 1. Show visual alert
            withAnimation(.spring()) {
                self.milestoneAlertText = "\(currentKm) km ✅"
                self.showMilestoneAlert = true
            }
            
            // 2. Haptic feedback (silent vibration)
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.success)
            
            print("📱 Phone Vibrated for: \(currentKm) km")
            
            // 3. Auto-hide alert after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation {
                    self.showMilestoneAlert = false
                }
            }
        }
    }

    // MARK: - Start / Controls

    func startFromPhone() {
        guard canStart else { return }
        connectivity.refreshWatchConnectivityState()
        guard connectivity.canStartWorkoutFromPhone else {
            lastError = L10n.t("gym.session.error.connectWatch")
            return
        }

        prepareForWorkoutStart()

        connectivity.launchWatchAppForWorkout(
            activityType: activityType,
            locationType: locationType
        )
    }

    func startFromPhone(with configuration: HKWorkoutConfiguration) {
        guard canStart else { return }
        connectivity.refreshWatchConnectivityState()
        guard connectivity.canStartWorkoutFromPhone else {
            lastError = L10n.t("gym.session.error.connectWatch")
            return
        }

        prepareForWorkoutStart()

        connectivity.launchWatchAppForWorkout(
            activityType: configuration.activityType,
            locationType: configuration.locationType
        )
    }

    func pauseFromPhone() {
        guard canPause else { return }
        lastError = nil
        connectivity.pauseWorkoutOnWatch()
    }

    func resumeFromPhone() {
        guard canResume else { return }
        lastError = nil
        connectivity.resumeWorkoutOnWatch()
    }

    func endFromPhone() {
        guard canEnd else { return }
        lastError = nil
        connectivity.endWorkoutOnWatch()
        // Reflect the ending state immediately (and arm the watchdog via the
        // phase `didSet`) instead of waiting for the watch's first `.stopping`
        // snapshot, which may never arrive on a flaky connection.
        if phase != .ending {
            withAnimation(.snappy) {
                phase = .ending
            }
        }
    }

    // MARK: - End Watchdog

    private func armEndTimeoutWatchdog() {
        cancelEndTimeoutWatchdog()
        endTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.endConfirmationTimeoutSeconds * 1_000_000_000)
            guard !Task.isCancelled, let self, self.phase == .ending else { return }
            self.finalizeStuckEnd()
        }
    }

    private func cancelEndTimeoutWatchdog() {
        endTimeoutTask?.cancel()
        endTimeoutTask = nil
    }

    /// The watch never confirmed the end within the timeout. The end command
    /// was already dispatched, so we reconcile the phone's mirror state and
    /// drive the workout to completion through the normal end path — the user
    /// is never left stuck on "جاري الإنهاء...".
    private func finalizeStuckEnd() {
        guard phase == .ending else { return }
        print("⏱️ Workout end not confirmed by watch in time — finalizing locally")
        // Asking the connectivity layer to go terminal publishes `.ended`,
        // which routes back through `applyRemotePhaseFallback` → `handleRemoteEnded`.
        connectivity.reconcileLostWorkoutEnd()
        // Safety net: if that publish was de-duplicated (already terminal) and
        // didn't drive us to idle, finalize directly so we never hang.
        if phase != .idle {
            handleRemoteEnded()
        }
    }

    func forceEndFromPhoneImmediately() {
        guard phase != .idle else { return }

        AnalyticsService.shared.track(.workoutCancelled)

        shouldIgnoreIncomingSnapshots = true
        lastError = nil

        if canEnd {
            connectivity.endWorkoutOnWatch()
        }

        if liveActivityIsActive {
            liveActivity.end(
                title: title,
                elapsedSeconds: elapsedSeconds,
                heartRate: heartRate,
                activeCalories: activeEnergy,
                distanceMeters: distanceMeters,
                zone2State: liveActivityHeartRateState,
                activeBuffs: activeLiveBuffs
            )
        }

        resetWorkoutState()
        withAnimation(.snappy) {
            phase = .idle
        }
    }
    
    // MARK: - Private Helpers

    private func startElapsedSmoothingTimer() {
        smoothingTimer?.invalidate()

        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tickElapsedDisplay()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        smoothingTimer = timer
    }

    private func tickElapsedDisplay() {
        guard phase == .running, let elapsedAnchorDate else { return }

        let nextValue = Int((elapsedAnchorSeconds + Date().timeIntervalSince(elapsedAnchorDate)).rounded(.down))
        guard nextValue != elapsedSeconds else { return }

        elapsedSeconds = max(nextValue, Int(elapsedAnchorSeconds.rounded(.down)))
        syncCoachingState()
    }

    private func applyConnectionState(_ state: WorkoutConnectionState) {
        remoteConnectionState = state
        isWatchReachable = state != .disconnected && state != .failed && state != .idle

        switch state {
        case .launching, .awaitingMirror:
            if phase == .idle {
                withAnimation(.snappy) {
                    phase = .starting
                }
            }
        case .failed:
            if phase == .starting {
                stopCaptainWarmupAudioIfNeeded()
                if liveActivityIsActive {
                    liveActivity.end(
                        title: title,
                        elapsedSeconds: elapsedSeconds,
                        heartRate: heartRate,
                        activeCalories: activeEnergy,
                        distanceMeters: distanceMeters,
                        zone2State: liveActivityHeartRateState,
                        activeBuffs: activeLiveBuffs
                    )
                    liveActivityIsActive = false
                }
                withAnimation(.snappy) {
                    phase = .idle
                }
            }
        case .disconnected:
            pushLiveActivityUpdateIfNeeded(force: true)
        case .mirrored, .reconnecting, .ended, .idle:
            break
        }
    }

    private func applyRemoteSnapshot(_ snapshot: WorkoutSessionStateDTO) {
        if shouldIgnoreIncomingSnapshots {
            if snapshot.currentState == .ended {
                shouldIgnoreIncomingSnapshots = false
                handleRemoteEnded()
            }
            return
        }

        let previousConnectionState = remoteConnectionState
        let previousPhase = phase

        remoteConnectionState = snapshot.connectionState
        isWatchReachable = snapshot.connectionState != .disconnected && snapshot.connectionState != .failed
        heartRate = snapshot.heartRate ?? 0
        activeEnergy = snapshot.activeEnergy ?? 0
        distanceMeters = snapshot.distance ?? 0
        checkForMilestone(totalMeters: distanceMeters)

        elapsedAnchorSeconds = snapshot.elapsedTime
        elapsedAnchorDate = Date()
        elapsedSeconds = Int(snapshot.elapsedTime.rounded(.down))

        if snapshot.currentState == .ended {
            handleRemoteEnded()
            return
        }

        let nextPhase = phase(from: snapshot.currentState)
        if nextPhase != phase {
            withAnimation(.snappy) {
                phase = nextPhase
            }
        }

        if phase == .paused || phase == .ending {
            elapsedSeconds = Int(snapshot.elapsedTime.rounded())
        }

        if phase == .running || phase == .paused || phase == .ending {
            ensureLiveActivityStartedIfNeeded()
        }

        if phase == .paused || phase == .ending {
            audioCoachManager.stop()
        }

        syncCoachingState()
        let shouldForceLiveActivityPush =
            phase != previousPhase ||
            snapshot.connectionState != previousConnectionState
        pushLiveActivityUpdateIfNeeded(force: shouldForceLiveActivityPush)
    }

    private func applyRemotePhaseFallback(_ remotePhase: WorkoutSessionPhase) {
        guard remotePhase == .ended else { return }
        guard phase != .idle else { return }
        handleRemoteEnded()
    }

    private func ensureLiveActivityStartedIfNeeded() {
        guard !liveActivityIsActive else { return }
        guard phase == .running || phase == .paused || phase == .ending else { return }

        liveActivity.start(
            title: title,
            zone2State: liveActivityHeartRateState,
            activeBuffs: activeLiveBuffs
        )
        liveActivityIsActive = true
    }

    private func handleRemoteEnded() {
        stopCaptainWarmupAudioIfNeeded()
        audioCoachManager.stop()

        if liveActivityIsActive {
            liveActivity.end(
                title: title,
                elapsedSeconds: elapsedSeconds,
                heartRate: heartRate,
                activeCalories: activeEnergy,
                distanceMeters: distanceMeters,
                zone2State: liveActivityHeartRateState,
                activeBuffs: activeLiveBuffs
            )
            liveActivityIsActive = false
        }

        WorkoutHistoryStore.shared.recordCompletion(
            title: title,
            durationSeconds: elapsedSeconds,
            activeCalories: activeEnergy,
            heartRate: heartRate,
            distanceMeters: distanceMeters
        )

        AnalyticsService.shared.track(.workoutCompleted(
            type: workoutTypeLabel,
            durationMin: elapsedSeconds / 60,
            calories: Int(activeEnergy.rounded())
        ))

        resetWorkoutState()
        withAnimation(.snappy) {
            phase = .idle
        }
    }

    private func phase(from remotePhase: WorkoutSessionPhase) -> Phase {
        switch remotePhase {
        case .idle:
            return .idle
        case .preparing:
            return .starting
        case .running:
            return .running
        case .paused:
            return .paused
        case .stopping:
            return .ending
        case .ended:
            return .idle
        }
    }
    
    private func resetWorkoutState() {
        stopCaptainWarmupAudioIfNeeded()
        heartRate = 0
        activeEnergy = 0
        distanceMeters = 0
        elapsedSeconds = 0
        elapsedAnchorSeconds = 0
        elapsedAnchorDate = nil
        lastRecordedKm = 0
        showMilestoneAlert = false
        milestoneAlertText = ""
        audioCoachManager.reset(for: currentWorkout, zone2Target: resolvedZone2Target)
        zone2AuraState = isZone2GuidedWorkout ? .warmingUp : .inactive
        activeLiveBuffs = []
        liveActivityIsActive = false
    }

    private var resolvedZone2Target: AudioCoachManager.Zone2Target {
        let lower = Int(zone2LowerBoundBPM.rounded())
        let upper = Int(zone2UpperBoundBPM.rounded())

        guard lower > 0, upper >= lower else {
            return .captainHamoudiDefault
        }

        return AudioCoachManager.Zone2Target(lowerBoundBPM: lower, upperBoundBPM: upper)
    }

    private func refreshZone2Configuration() {
        guard isZone2GuidedWorkout else {
            resolvedUserAge = 0
            zone2LowerBoundBPM = 0
            zone2UpperBoundBPM = 0
            return
        }

        let age = resolveUserAge()
        resolvedUserAge = age
        let maxHeartRate = max(100, 220 - age)
        zone2LowerBoundBPM = Double(maxHeartRate) * 0.60
        zone2UpperBoundBPM = Double(maxHeartRate) * 0.70
    }

    private func resolveUserAge() -> Int {
        let profile = UserProfileStore.shared.current
        if (13...100).contains(profile.age) {
            return profile.age
        }

        if let birthDate = profile.birthDate {
            let age = Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 30
            if (13...100).contains(age) {
                return age
            }
        }

        return 30
    }

    private func evaluateZone2Coaching() {
        guard isZone2GuidedWorkout else {
            zone2AuraState = .inactive
            return
        }

        if phase == .idle || phase == .starting {
            zone2AuraState = .warmingUp
            return
        }

        let upper = zone2UpperBoundBPM
        let lower = zone2LowerBoundBPM
        let nextState: Zone2AuraState

        if elapsedSeconds < AudioCoachManager.warmUpDurationSeconds {
            nextState = .warmingUp
        } else if heartRate > upper {
            nextState = .tooFast
        } else if heartRate < lower {
            nextState = .tooSlow
        } else {
            nextState = .inZone2
        }

        guard nextState != zone2AuraState else { return }
        zone2AuraState = nextState
    }

    private func syncCoachingState() {
        evaluateZone2Coaching()
        updateCaptainWarmupAmbientIfNeeded()
        audioCoachManager.handleDynamicZone2Coaching(
            heartRate: heartRate,
            distanceMeters: distanceMeters,
            isRunning: phase == .running
        )
    }

    func setActiveBuffs(_ buffs: [WorkoutActivityAttributes.Buff]) {
        var seen = Set<String>()
        let next = buffs.reduce(into: [WorkoutActivityAttributes.Buff]()) { partial, buff in
            guard seen.insert(buff.id).inserted, partial.count < 3 else { return }
            partial.append(buff)
        }

        guard next != activeLiveBuffs else { return }
        activeLiveBuffs = next
        pushLiveActivityUpdateIfNeeded(force: true)
    }

    /// Emits on zone transitions only — per-session Combine publisher. Any
    /// in-session UI can bind to this directly; `@Published` guarantees one
    /// emission per actual zone change because the assignment below is
    /// gated by a value comparison.
    @Published private(set) var zoneTransitionState: WorkoutActivityAttributes.HeartRateState = .neutral

    private var liveActivityHeartRateState: WorkoutActivityAttributes.HeartRateState {
        let state: WorkoutActivityAttributes.HeartRateState
        switch zone2AuraState {
        case .inactive:
            state = .neutral
        case .warmingUp:
            state = .warmingUp
        case .inZone2:
            state = .zone2
        case .tooFast:
            state = .aboveZone2
        case .tooSlow:
            state = .belowZone2
        }

        if state != zoneTransitionState {
            zoneTransitionState = state
            Self.captainVoiceZoneTransitions.send(CaptainVoiceZoneSnapshot(
                state: state,
                currentBPM: Int(heartRate),
                zone2LowerBPM: Int(zone2LowerBoundBPM),
                zone2UpperBPM: Int(zone2UpperBoundBPM)
            ))
        }
        return state
    }

    /// App-global broadcast point for zone transitions. `LiveWorkoutSession`
    /// is instantiated per-workout (not a singleton), so the coaching voice
    /// service — which lives outside any single workout scope — can't subscribe
    /// to an instance property. Every session instance pushes its transitions
    /// here, and `ZoneCoachingVoiceService` subscribes at app launch.
    /// The payload type `CaptainVoiceZoneSnapshot` is defined in
    /// `AiQo/Features/Captain/Voice/CaptainVoiceZoneSnapshot.swift`.
    static let captainVoiceZoneTransitions = PassthroughSubject<CaptainVoiceZoneSnapshot, Never>()

    private func pushLiveActivityUpdateIfNeeded(force: Bool = false) {
        guard phase == .running || phase == .paused || phase == .ending else { return }

        let activityPhase: WorkoutActivityAttributes.WorkoutPhase
        switch phase {
        case .running: activityPhase = .running
        case .paused: activityPhase = .paused
        case .ending: activityPhase = .ending
        case .idle, .starting:
            return
        }

        liveActivity.update(
            title: title,
            elapsedSeconds: elapsedSeconds,
            heartRate: heartRate,
            activeCalories: activeEnergy,
            distanceMeters: distanceMeters,
            phase: activityPhase,
            zone2State: liveActivityHeartRateState,
            activeBuffs: activeLiveBuffs,
            force: force
        )
    }

    private func prepareForWorkoutStart() {
        shouldIgnoreIncomingSnapshots = false
        refreshZone2Configuration()
        resetWorkoutState()
        if !liveActivityIsActive {
            liveActivity.start(
                title: title,
                zone2State: liveActivityHeartRateState,
                activeBuffs: activeLiveBuffs
            )
            liveActivityIsActive = true
        }
        startCaptainWarmupAudioIfNeeded()
        withAnimation(.snappy) {
            phase = .starting
        }
        lastError = nil
        AnalyticsService.shared.track(.workoutStarted(type: workoutTypeLabel))
    }

    private func startCaptainWarmupAudioIfNeeded() {
        guard currentWorkout == .cardioWithCaptainHamoudi else { return }
        guard captainWarmupAmbientPlayer == nil else {
            isCaptainWarmupAmbientActive = true
            configureCaptainWarmupAmbientAudioSession()
            captainWarmupAmbientPlayer?.play()
            syncCaptainWarmupAmbientSpeechState(CaptainVoiceService.shared.isSpeaking)
            registerCaptainWarmupAmbientIfNeeded()
            return
        }

        guard let nextPlayer = makeCaptainWarmupAmbientPlayer() else { return }

        configureCaptainWarmupAmbientAudioSession()

        nextPlayer.numberOfLoops = -1
        nextPlayer.volume = CaptainVoiceService.shared.isSpeaking
            ? Self.captainWarmupAmbientDuckedVolume
            : Self.captainWarmupAmbientBaseVolume
        nextPlayer.prepareToPlay()

        guard nextPlayer.play() else { return }

        captainWarmupAmbientPlayer = nextPlayer
        isCaptainWarmupAmbientActive = true
        registerCaptainWarmupAmbientIfNeeded()
    }

    private func updateCaptainWarmupAmbientIfNeeded() {
        guard isCaptainWarmupAmbientActive else { return }
        guard elapsedSeconds >= Self.captainWarmupAmbientLoopDurationSeconds else { return }

        stopCaptainWarmupAmbientIfNeeded()
    }

    private func stopCaptainWarmupAudioIfNeeded() {
        stopCaptainWarmupAmbientIfNeeded()
    }

    private func stopCaptainWarmupAmbientIfNeeded() {
        guard isCaptainWarmupAmbientActive else { return }
        isCaptainWarmupAmbientActive = false
        captainWarmupAmbientFadeTask?.cancel()
        captainWarmupAmbientFadeTask = nil
        captainWarmupAmbientPlayer?.stop()
        captainWarmupAmbientPlayer = nil
        unregisterCaptainWarmupAmbientIfNeeded()

        guard !CaptainVoiceService.shared.isSpeaking else { return }
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    private func makeCaptainWarmupAmbientPlayer() -> AVAudioPlayer? {
        if let asset = NSDataAsset(name: Self.captainWarmupAmbientTrackName, bundle: .main),
           let player = try? AVAudioPlayer(data: asset.data) {
            return player
        }

        for fileExtension in ["m4a", "mp3", "aac", "wav"] {
            guard let url = Bundle.main.url(
                forResource: Self.captainWarmupAmbientTrackName,
                withExtension: fileExtension
            ) else {
                continue
            }

            if let player = try? AVAudioPlayer(contentsOf: url) {
                return player
            }
        }

        return nil
    }

    private func configureCaptainWarmupAmbientAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func syncCaptainWarmupAmbientSpeechState(_ isSpeaking: Bool) {
        guard let captainWarmupAmbientPlayer, isCaptainWarmupAmbientActive else { return }

        if !captainWarmupAmbientPlayer.isPlaying {
            configureCaptainWarmupAmbientAudioSession()
            captainWarmupAmbientPlayer.play()
        }

        setCaptainWarmupAmbientVolume(
            isSpeaking ? Self.captainWarmupAmbientDuckedVolume : Self.captainWarmupAmbientBaseVolume,
            animated: true
        )
    }

    private func setCaptainWarmupAmbientVolume(_ targetVolume: Float, animated: Bool) {
        guard let captainWarmupAmbientPlayer else { return }

        captainWarmupAmbientFadeTask?.cancel()

        guard animated else {
            captainWarmupAmbientPlayer.volume = targetVolume
            return
        }

        let startVolume = captainWarmupAmbientPlayer.volume
        let steps = 6
        let stepDuration = UInt64(40_000_000)

        captainWarmupAmbientFadeTask = Task { @MainActor [weak self] in
            guard let self else { return }

            for step in 1...steps {
                if Task.isCancelled { return }
                guard let player = self.captainWarmupAmbientPlayer else { return }

                let progress = Float(step) / Float(steps)
                player.volume = startVolume + ((targetVolume - startVolume) * progress)
                try? await Task.sleep(nanoseconds: stepDuration)
            }

            self.captainWarmupAmbientPlayer?.volume = targetVolume
        }
    }

    private func registerCaptainWarmupAmbientIfNeeded() {
        guard !hasRegisteredCaptainWarmupAmbient else { return }
        hasRegisteredCaptainWarmupAmbient = true
        CaptainVoiceService.shared.beginExternalMixedPlayback()
    }

    private func unregisterCaptainWarmupAmbientIfNeeded() {
        guard hasRegisteredCaptainWarmupAmbient else { return }
        hasRegisteredCaptainWarmupAmbient = false
        CaptainVoiceService.shared.endExternalMixedPlayback()
    }
}

// MARK: - Usage Example in SwiftUI View
/*
struct WorkoutView: View {
    @StateObject private var session = LiveWorkoutSession(
        title: "Morning Run",
        activityType: .running,
        locationType: .outdoor
    )
    
    var body: some View {
        VStack(spacing: 20) {
            Text(session.title)
                .font(.title)
            
            Text(session.statusText)
                .foregroundStyle(.secondary)
            
            // Live stats
            if session.phase == .running {
                HStack(spacing: 40) {
                    StatView(title: "❤️", value: "\(Int(session.heartRate))")
                    StatView(title: "🔥", value: "\(Int(session.activeEnergy))")
                    StatView(title: "📍", value: String(format: "%.2f km", session.distanceMeters / 1000))
                }
            }
            
            // Control buttons
            HStack(spacing: 20) {
                if session.canStart {
                    Button("Start") {
                        session.startFromPhone()
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                if session.canEnd {
                    Button("End") {
                        session.endFromPhone()
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            }
            
            // Error display
            if let error = session.lastError {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
        .overlay(alignment: .top) {
            // Milestone alert
            if session.showMilestoneAlert {
                Text(session.milestoneAlertText)
                    .font(.headline)
                    .padding()
                    .background(Color.green.opacity(0.9))
                    .cornerRadius(10)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
}

struct StatView: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack {
            Text(title)
            Text(value)
                .font(.title2.bold())
        }
    }
}
*/
