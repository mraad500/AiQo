// ===============================================
// File: LiveWorkoutSession.swift
// Target: iOS
// ===============================================

import Foundation
import AVFoundation
import HealthKit
import SwiftUI
import UIKit
internal import Combine

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
    let coachingProfile: WorkoutCoachingProfile
    
    // MARK: - Managers
    private let connectivity = PhoneConnectivityManager.shared
    private let healthKitManager = HealthKitManager.shared  // ✅ NEW: Reference to HealthKitManager
    private let liveActivity = WorkoutLiveActivityManager.shared
    
    // MARK: - Published State
    
    @Published var title: String = "Gym Workout"
    @Published var phase: Phase = .idle
    
    // Live workout data (updated in real-time from Watch)
    @Published var heartRate: Double = 0
    @Published var activeEnergy: Double = 0
    @Published var distanceMeters: Double = 0
    @Published var elapsedSeconds: Int = 0

    @Published private(set) var zone2AuraState: Zone2AuraState = .inactive
    @Published private(set) var zone2LowerBoundBPM: Double = 0
    @Published private(set) var zone2UpperBoundBPM: Double = 0
    @Published private(set) var resolvedUserAge: Int = 0
    
    @Published var isWatchReachable: Bool = false
    
    // Milestone alert properties (shown when completing each km)
    @Published var showMilestoneAlert: Bool = false
    @Published var milestoneAlertText: String = ""
    
    // Error handling
    @Published var lastError: String? = nil
    
    // Private tracking
    private var lastRecordedKm: Int = 0
    private var cancellables = Set<AnyCancellable>()
    private let zone2WarmupDuration: Int = 300
    private let zone2AudioCooldown: TimeInterval = 120
    private let zone2AudioCoach = Zone2AudioCoach()
    private var lastZone2CueAt: Date?
    
    // MARK: - Computed Properties
    
    var statusText: String {
        switch phase {
        case .idle: return "Ready"
        case .starting: return "Connecting..."
        case .running: return "Active"
        case .paused: return "Paused"
        case .ending: return "Saving..."
        }
    }
    
    var canStart: Bool { phase == .idle }
    var canEnd: Bool { phase == .running || phase == .paused }
    var canPause: Bool { phase == .running }
    var canResume: Bool { phase == .paused }

    var isZone2GuidedWorkout: Bool {
        coachingProfile == .captainHamoudiZone2
    }

    var isZone2WarmupActive: Bool {
        isZone2GuidedWorkout && elapsedSeconds < zone2WarmupDuration
    }

    var zone2WarmupRemainingSeconds: Int {
        max(zone2WarmupDuration - elapsedSeconds, 0)
    }

    var zone2RangeLabel: String {
        guard isZone2GuidedWorkout else { return "--" }
        let lower = Int(zone2LowerBoundBPM.rounded())
        let upper = Int(zone2UpperBoundBPM.rounded())
        return "\(lower)-\(upper) BPM"
    }
    
    // MARK: - Initialization
    
    init(
        title: String = "Gym Workout",
        activityType: HKWorkoutActivityType = .other,
        locationType: HKWorkoutSessionLocationType = .unknown,
        coachingProfile: WorkoutCoachingProfile = .standard
    ) {
        self.title = title
        self.activityType = activityType
        self.locationType = locationType
        self.coachingProfile = coachingProfile
        
        refreshZone2Configuration()
        zone2AuraState = isZone2GuidedWorkout ? .warmingUp : .inactive
        setupBindings()
    }

    // MARK: - Data Bindings
    
    private func setupBindings() {
        
        // Watch reachability
        connectivity.$isReachable
            .receive(on: RunLoop.main)
            .removeDuplicates()
            .assign(to: &$isWatchReachable)
        
        // Heart rate from Watch
        connectivity.$currentHeartRate
            .receive(on: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] value in
                self?.heartRate = value
                self?.evaluateZone2Coaching()
                self?.pushLiveActivityUpdateIfNeeded()
            }
            .store(in: &cancellables)
        
        // Active energy from Watch
        connectivity.$activeEnergy
            .receive(on: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] value in
                self?.activeEnergy = value
                self?.pushLiveActivityUpdateIfNeeded()
            }
            .store(in: &cancellables)
        
        // Distance with milestone checking
        connectivity.$currentDistance
            .receive(on: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] distance in
                guard let self = self else { return }
                self.distanceMeters = distance
                self.checkForMilestone(totalMeters: distance)
                self.pushLiveActivityUpdateIfNeeded()
            }
            .store(in: &cancellables)
        
        // Duration from Watch
        connectivity.$currentDuration
            .receive(on: RunLoop.main)
            .map { Int($0) }
            .removeDuplicates()
            .sink { [weak self] value in
                self?.elapsedSeconds = value
                self?.evaluateZone2Coaching()
                self?.pushLiveActivityUpdateIfNeeded()
            }
            .store(in: &cancellables)
        
        // Error tracking
        connectivity.$lastError
            .receive(on: RunLoop.main)
            .sink { [weak self] error in
                if error != "None" {
                    self?.lastError = error
                }
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

    // MARK: - ✅ NEW: Start Workout Using startWatchApp (RELIABLE METHOD)
    
    /// Starts the workout by using HKHealthStore.startWatchApp(with:completion:)
    /// This is the RECOMMENDED approach for reliably waking the Watch app.
    func startFromPhone() {
        guard canStart else { return }
        
        refreshZone2Configuration()
        // Reset state for new workout
        resetWorkoutState()
        
        withAnimation { phase = .starting }
        lastError = nil
        
        print("🚀 [LiveWorkoutSession] Starting workout via startWatchApp...")
        print("   Activity: \(activityType.rawValue), Location: \(locationType.rawValue)")
        
        // ✅ PRIMARY METHOD: Use HKHealthStore.startWatchApp
        // This is the RELIABLE way to wake the Watch app from any state
        healthKitManager.startWatchWorkout(
            activityType: activityType,
            locationType: locationType
        ) { [weak self] success, error in
            guard let self = self else { return }
            
            if success {
                print("✅ [LiveWorkoutSession] Watch app woken successfully!")
                
                // The Watch app's WKExtensionDelegate will receive the configuration
                // and start the workout automatically. We just need to wait briefly
                // for the Watch to begin sending live data.
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.snappy) {
                        self.phase = .running
                    }
                    self.evaluateZone2Coaching()
                    self.liveActivity.start(title: self.title)
                    self.pushLiveActivityUpdateIfNeeded(force: true)
                }
            } else {
                print("❌ [LiveWorkoutSession] Failed to launch Watch app: \(error?.localizedDescription ?? "Unknown error")")
                
                self.lastError = error?.localizedDescription ?? "Failed to connect to Watch"
                
                // FALLBACK: Try WCSession as backup
                self.startWithWCSessionFallback()
            }
        }
    }
    
    /// Fallback method using WCSession (less reliable for background starts)
    private func startWithWCSessionFallback() {
        print("⚠️ [LiveWorkoutSession] Trying WCSession fallback...")
        
        // First, try to launch the Watch app
        connectivity.launchWatchAppForWorkout(
            activityType: activityType,
            locationType: locationType
        )
        
        // Then send the start command
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            
            self.connectivity.startWorkoutOnWatch(
                activityTypeRaw: Int(self.activityType.rawValue),
                locationTypeRaw: Int(self.locationType.rawValue)
            )
            
            withAnimation(.snappy) {
                self.phase = .running
            }
            self.evaluateZone2Coaching()
            self.liveActivity.start(title: self.title)
            self.pushLiveActivityUpdateIfNeeded(force: true)
        }
    }
    
    // MARK: - Alternative Start Method (Direct Configuration)
    
    /// Alternative method that accepts a pre-configured HKWorkoutConfiguration
    func startFromPhone(with configuration: HKWorkoutConfiguration) {
        guard canStart else { return }
        
        refreshZone2Configuration()
        resetWorkoutState()
        
        withAnimation { phase = .starting }
        lastError = nil
        
        print("🚀 [LiveWorkoutSession] Starting workout with custom configuration...")
        
        healthKitManager.startWatchWorkout(workoutConfiguration: configuration) { [weak self] success, error in
            guard let self = self else { return }
            
            if success {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.snappy) {
                        self.phase = .running
                    }
                    self.evaluateZone2Coaching()
                    self.liveActivity.start(title: self.title)
                    self.pushLiveActivityUpdateIfNeeded(force: true)
                }
            } else {
                self.lastError = error?.localizedDescription ?? "Failed to connect to Watch"
                self.startWithWCSessionFallback()
            }
        }
    }
    
    // MARK: - Pause/Resume Controls
    
    func pauseFromPhone() {
        guard canPause else { return }
        withAnimation(.snappy) { phase = .paused }
        zone2AudioCoach.stop()
        evaluateZone2Coaching()
        pushLiveActivityUpdateIfNeeded(force: true)
        // Note: You may want to send a pause command to Watch via WCSession
        // connectivity.sendCommand(["command": "pauseWorkout"])
    }
    
    func resumeFromPhone() {
        guard canResume else { return }
        withAnimation(.snappy) { phase = .running }
        evaluateZone2Coaching()
        pushLiveActivityUpdateIfNeeded(force: true)
        // Note: You may want to send a resume command to Watch via WCSession
        // connectivity.sendCommand(["command": "resumeWorkout"])
    }
    
    // MARK: - End Workout
    
    func endFromPhone() {
        guard canEnd else { return }
        withAnimation(.snappy) { phase = .ending }
        zone2AudioCoach.stop()
        evaluateZone2Coaching()
        pushLiveActivityUpdateIfNeeded(force: true)
        
        // Send stop command to Watch
        connectivity.stopWorkoutOnWatch()
        
        // Allow time for Watch to save, then reset
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.liveActivity.end(
                title: self.title,
                elapsedSeconds: self.elapsedSeconds,
                heartRate: self.heartRate,
                activeCalories: self.activeEnergy,
                distanceMeters: self.distanceMeters
            )
            withAnimation(.snappy) {
                self.resetWorkoutState()
                self.phase = .idle
            }
        }
    }
    
    // MARK: - Private Helpers
    
    private func resetWorkoutState() {
        heartRate = 0
        activeEnergy = 0
        distanceMeters = 0
        elapsedSeconds = 0
        lastRecordedKm = 0
        showMilestoneAlert = false
        milestoneAlertText = ""
        lastZone2CueAt = nil
        zone2AudioCoach.stop()
        zone2AuraState = isZone2GuidedWorkout ? .warmingUp : .inactive
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

        if heartRate > upper {
            nextState = .tooFast
        } else if elapsedSeconds < zone2WarmupDuration {
            nextState = .warmingUp
        } else if heartRate < lower {
            nextState = .tooSlow
        } else {
            nextState = .inZone2
        }

        guard nextState != zone2AuraState else { return }
        zone2AuraState = nextState

        guard phase == .running else { return }
        switch nextState {
        case .tooFast:
            playZone2CueIfNeeded(.slowDown)
        case .tooSlow:
            playZone2CueIfNeeded(.speedUp)
        case .inactive, .warmingUp, .inZone2:
            break
        }
    }

    private func playZone2CueIfNeeded(_ cue: Zone2AudioCoach.Cue) {
        let now = Date()
        if let lastZone2CueAt, now.timeIntervalSince(lastZone2CueAt) < zone2AudioCooldown {
            return
        }

        zone2AudioCoach.play(cue: cue)
        lastZone2CueAt = now
    }

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
            force: force
        )
    }
}

@MainActor
private final class Zone2AudioCoach {
    enum Cue {
        case slowDown
        case speedUp

        var assetBaseName: String {
            switch self {
            case .slowDown: return "slow_down_zone2"
            case .speedUp: return "speed_up_zone2"
            }
        }
    }

    private var player: AVAudioPlayer?

    func play(cue: Cue) {
        guard let data = loadAudioData(named: cue.assetBaseName) else { return }
        configureAudioSessionIfNeeded()

        do {
            let nextPlayer = try AVAudioPlayer(data: data)
            nextPlayer.prepareToPlay()
            nextPlayer.play()
            player = nextPlayer
        } catch {
            // Coaching should continue silently if audio playback fails.
        }
    }

    func stop() {
        player?.stop()
        player = nil
    }

    private func loadAudioData(named baseName: String) -> Data? {
        if let dataset = NSDataAsset(name: baseName) {
            return dataset.data
        }

        for ext in ["mp3", "m4a", "wav"] {
            guard let url = Bundle.main.url(forResource: baseName, withExtension: ext) else {
                continue
            }
            if let data = try? Data(contentsOf: url) {
                return data
            }
        }

        return nil
    }

    private func configureAudioSessionIfNeeded() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true, options: [])
        } catch {
            // Fallback to silent coaching when the audio session cannot be configured.
        }
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
                .foregroundColor(.secondary)
            
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
                    .foregroundColor(.red)
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
