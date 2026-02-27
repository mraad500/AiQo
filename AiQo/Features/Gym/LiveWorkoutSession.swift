// ===============================================
// File: LiveWorkoutSession.swift
// Target: iOS
// ===============================================

import Foundation
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
    let currentWorkout: GymWorkoutKind
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
    private let audioCoachManager = AudioCoachManager()
    
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
        currentWorkout == .cardioWithCaptainHamoudi
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
        return "\(lower)-\(upper) BPM"
    }
    
    // MARK: - Initialization
    
    init(
        title: String = "Gym Workout",
        activityType: HKWorkoutActivityType = .other,
        locationType: HKWorkoutSessionLocationType = .unknown,
        currentWorkout: GymWorkoutKind = .standard,
        coachingProfile: WorkoutCoachingProfile = .standard
    ) {
        self.title = title
        self.activityType = activityType
        self.locationType = locationType
        self.currentWorkout = currentWorkout
        self.coachingProfile = coachingProfile
        
        refreshZone2Configuration()
        audioCoachManager.reset(for: currentWorkout, zone2Target: resolvedZone2Target)
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
                self?.syncCoachingState()
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
                self?.syncCoachingState()
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
                    self.syncCoachingState()
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
            self.syncCoachingState()
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
                    self.syncCoachingState()
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
        audioCoachManager.stop()
        syncCoachingState()
        pushLiveActivityUpdateIfNeeded(force: true)
        // Note: You may want to send a pause command to Watch via WCSession
        // connectivity.sendCommand(["command": "pauseWorkout"])
    }
    
    func resumeFromPhone() {
        guard canResume else { return }
        withAnimation(.snappy) { phase = .running }
        syncCoachingState()
        pushLiveActivityUpdateIfNeeded(force: true)
        // Note: You may want to send a resume command to Watch via WCSession
        // connectivity.sendCommand(["command": "resumeWorkout"])
    }
    
    // MARK: - End Workout
    
    func endFromPhone() {
        guard canEnd else { return }
        withAnimation(.snappy) { phase = .ending }
        audioCoachManager.stop()
        syncCoachingState()
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
        audioCoachManager.reset(for: currentWorkout, zone2Target: resolvedZone2Target)
        zone2AuraState = isZone2GuidedWorkout ? .warmingUp : .inactive
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
        audioCoachManager.handleTimerTick(
            elapsedTime: TimeInterval(elapsedSeconds),
            heartRate: heartRate,
            isRunning: phase == .running
        )
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
