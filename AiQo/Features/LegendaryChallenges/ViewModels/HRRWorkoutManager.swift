import Foundation
import HealthKit
import Observation
import Combine

// MARK: - Recovery Level

enum RecoveryLevel: String, Codable {
    case excellent = "excellent"
    case good = "good"
    case needsWork = "needsWork"

    var titleAr: String {
        switch self {
        case .excellent: return "ممتاز"
        case .good: return "جيد"
        case .needsWork: return "قابل للتطوير"
        }
    }

    var captainComment: String {
        switch self {
        case .excellent:
            return "محرّكك قوي! جسمك يسترد بسرعة. راح أبني لك خطة تتحدى مستواك."
        case .good:
            return "لياقتك فوق المتوسط. الخطة راح تطوّرك خطوة خطوة."
        case .needsWork:
            return "أساساتك موجودة. راح نبدأ بخطة تقوّي الاسترداد أولاً وبعدها ندخل بالجد."
        }
    }

    var iconName: String {
        switch self {
        case .excellent: return "bolt.heart.fill"
        case .good: return "heart.fill"
        case .needsWork: return "heart.text.square.fill"
        }
    }

    var accentColor: String {
        switch self {
        case .excellent: return "mint"
        case .good: return "sand"
        case .needsWork: return "orange"
        }
    }
}

// MARK: - HRR Workout Manager
// FIXED: Rewritten to use PhoneConnectivityManager (Watch-based workout)
// instead of creating an HKWorkoutSession directly on iPhone.
// iPhone does NOT have HR sensors — the Watch must run the session
// and stream HR back, exactly like the existing المشي/الجري workouts.

@MainActor
@Observable
final class HRRWorkoutManager {

    // FIXED: Use PhoneConnectivityManager to talk to the Watch
    private let connectivity = PhoneConnectivityManager.shared

    var currentHeartRate: Double = 0
    var peakHeartRate: Double = 0
    var recoveryHeartRate: Double = 0
    var isWorkoutActive = false
    var authorizationGranted = false
    var error: String?

    // FIXED: Track whether Watch is connected and sending HR
    var isReceivingHeartRate: Bool { currentHeartRate > 0 }
    var watchConnectionStatus: WatchConnectionStatus { connectivity.watchStartConnectionStatus }

    private var cancellables = Set<AnyCancellable>()
    private var noHRTimeoutTask: Task<Void, Never>?

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            error = "HealthKit غير متوفر على هالجهاز"
            return false
        }

        let healthStore = HKHealthStore()
        let heartRateType = HKQuantityType(.heartRate)
        let workoutType = HKObjectType.workoutType()

        let readTypes: Set<HKObjectType> = [heartRateType]
        let writeTypes: Set<HKSampleType> = [workoutType, heartRateType]

        do {
            try await healthStore.requestAuthorization(toShare: writeTypes, read: readTypes)
            authorizationGranted = true
            return true
        } catch {
            self.error = "ما قدرنا ناخذ صلاحيات HealthKit: \(error.localizedDescription)"
            authorizationGranted = false
            return false
        }
    }

    // MARK: - Start Workout on Watch
    // FIXED: Uses the SAME pattern as LiveWorkoutSession.startFromPhone()

    func startStepTest() {
        // FIXED: Check Watch connectivity first
        connectivity.refreshWatchConnectivityState()

        guard connectivity.canStartWorkoutFromPhone else {
            error = "يحتاج Apple Watch متصلة ⌚"
            return
        }

        // Reset state
        peakHeartRate = 0
        currentHeartRate = 0
        recoveryHeartRate = 0
        error = nil

        // FIXED: Subscribe to Watch HR snapshots BEFORE starting workout
        startListeningToWatchSnapshots()

        // FIXED: Launch workout on Watch via PhoneConnectivityManager
        // Uses .highIntensityIntervalTraining + .indoor — same as before
        connectivity.launchWatchAppForWorkout(
            activityType: .highIntensityIntervalTraining,
            locationType: .indoor
        )

        isWorkoutActive = true

        // FIXED: Start a timeout — if no HR after 30 seconds, warn user
        startNoHRTimeout()
    }

    // MARK: - Listen to Watch HR Snapshots
    // FIXED: Subscribe to PhoneConnectivityManager.latestSnapshot
    // exactly like LiveWorkoutSession does

    private func startListeningToWatchSnapshots() {
        // Cancel any existing subscriptions
        cancellables.removeAll()

        // FIXED: Listen to latestSnapshot from PhoneConnectivityManager
        // This is the SAME data source LiveWorkoutSession uses
        connectivity.$latestSnapshot
            .receive(on: RunLoop.main)
            .sink { [weak self] snapshot in
                guard let self, let snapshot else { return }
                self.handleSnapshot(snapshot)
            }
            .store(in: &cancellables)

        // FIXED: Also listen for connection errors
        connectivity.$lastError
            .receive(on: RunLoop.main)
            .sink { [weak self] errorMsg in
                guard let self else { return }
                if errorMsg != "None" && self.isWorkoutActive && self.currentHeartRate == 0 {
                    self.error = "مشكلة بالاتصال بالساعة: \(errorMsg)"
                }
            }
            .store(in: &cancellables)

        // FIXED: Listen for connection state changes
        connectivity.$workoutConnectionState
            .receive(on: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] state in
                guard let self else { return }
                if state == .failed && self.isWorkoutActive {
                    self.error = "ما قدرنا نتصل بالساعة. تأكد الساعة قريبة ومشحونة."
                }
            }
            .store(in: &cancellables)
    }

    // FIXED: Process incoming Watch snapshot — extract HR
    private func handleSnapshot(_ snapshot: WorkoutSessionStateDTO) {
        guard isWorkoutActive else { return }

        let hr = snapshot.heartRate ?? 0

        if hr > 0 {
            currentHeartRate = hr
            // Cancel the no-HR timeout since we're receiving data
            noHRTimeoutTask?.cancel()
            noHRTimeoutTask = nil
            // Clear any connectivity error
            if error?.contains("ما نقدر نقرأ النبض") == true ||
               error?.contains("مشكلة بالاتصال") == true ||
               error?.contains("ما قدرنا نتصل") == true {
                error = nil
            }
        }

        // Track peak HR (only during active test phase, caller manages phases)
        if hr > peakHeartRate {
            peakHeartRate = hr
        }
    }

    // MARK: - Capture Recovery HR

    func captureRecoveryHR() {
        recoveryHeartRate = currentHeartRate
    }

    // MARK: - End Workout
    // FIXED: Tell Watch to end the workout via PhoneConnectivityManager

    func endWorkout() {
        guard isWorkoutActive else { return }

        // FIXED: Send end command to Watch
        connectivity.endWorkoutOnWatch()

        // Stop listening
        cancellables.removeAll()
        noHRTimeoutTask?.cancel()
        noHRTimeoutTask = nil

        isWorkoutActive = false
    }

    // MARK: - Recovery Calculation

    func calculateRecoveryLevel() -> RecoveryLevel {
        if recoveryHeartRate < 100 {
            return .excellent
        } else if recoveryHeartRate <= 110 {
            return .good
        } else {
            return .needsWork
        }
    }

    var hrrDrop: Double {
        max(peakHeartRate - recoveryHeartRate, 0)
    }

    // MARK: - No-HR Timeout
    // FIXED: Warn user if Watch doesn't send HR within 30 seconds

    private func startNoHRTimeout() {
        noHRTimeoutTask?.cancel()
        noHRTimeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
            guard let self, !Task.isCancelled else { return }
            if self.isWorkoutActive && self.currentHeartRate == 0 {
                self.error = "ما نقدر نقرأ النبض — تأكد الساعة لابسها صح ⌚"
            }
        }
    }

    // MARK: - Cleanup

    func reset() {
        cancellables.removeAll()
        noHRTimeoutTask?.cancel()
        noHRTimeoutTask = nil
        currentHeartRate = 0
        peakHeartRate = 0
        recoveryHeartRate = 0
        isWorkoutActive = false
        error = nil
    }
}
