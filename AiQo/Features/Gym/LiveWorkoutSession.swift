import Foundation
internal import Combine
import HealthKit
import UIKit

// ✅ تمت إضافة التعريف المفقود هنا
enum LiveWorkoutNotification {
    static let didStart = Notification.Name("LiveWorkoutDidStart")
    static let didStop  = Notification.Name("LiveWorkoutDidStop")
}

@MainActor
final class LiveWorkoutSession: NSObject, ObservableObject {
    static let shared = LiveWorkoutSession()
    
    @Published var workoutID: String?
    @Published var heartRate: Double = 0
    @Published var activeEnergy: Double = 0
    @Published var distance: Double = 0
    @Published var pace: String = "--"
    @Published var elapsed: TimeInterval = 0
    @Published var isConnected: Bool = false
    
    private var timerTask: Task<Void, Never>?
    private var lastReceivedDate: Date?
    
    private override init() {
        super.init()
        setupObservers()
    }
    
    private func setupObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleMetricsUpdate(_:)), name: NSNotification.Name("LiveMetricsReceived"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleWorkoutStart), name: NSNotification.Name("WorkoutDidStart"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleWorkoutEnd), name: NSNotification.Name("WorkoutDidEnd"), object: nil)
    }
    
    @objc private func handleMetricsUpdate(_ notification: Notification) {
        guard let metrics = notification.userInfo?["metrics"] as? LiveMetricsPayload else { return }
        
        Task { @MainActor in
            self.isConnected = true
            let currentID = self.workoutID ?? "WatchSession"
            self.applyLiveMetrics(workoutID: currentID, payload: metrics)
        }
    }
    
    @objc private func handleWorkoutStart() {
        Task { @MainActor in
            self.isConnected = true
            if self.workoutID == nil {
                self.start(workoutID: "WatchSession")
            }
        }
    }
    
    @objc private func handleWorkoutEnd() {
        Task { @MainActor in
            self.stop()
        }
    }
    
    func applyLiveMetrics(workoutID: String, payload: LiveMetricsPayload) {
        if self.workoutID == nil {
            self.workoutID = workoutID
            NotificationCenter.default.post(name: LiveWorkoutNotification.didStart, object: nil)
            startLocalSmoothTimer()
        }
        
        self.heartRate = payload.heartRate
        self.activeEnergy = payload.activeEnergy
        self.distance = payload.distance
        self.elapsed = payload.elapsed
        self.lastReceivedDate = Date()
        
        updatePace(distance: payload.distance, duration: payload.elapsed)
    }
    
    func start(workoutID: String) {
        self.workoutID = workoutID
        resetMetrics()
        NotificationCenter.default.post(name: LiveWorkoutNotification.didStart, object: nil)
        startLocalSmoothTimer()
    }
    
    func stop() {
        self.workoutID = nil
        self.isConnected = false
        timerTask?.cancel()
        NotificationCenter.default.post(name: LiveWorkoutNotification.didStop, object: nil)
    }
    
    private func updatePace(distance: Double, duration: TimeInterval) {
        guard distance > 0, duration > 0 else {
            self.pace = "--"
            return
        }
        let speed = distance / duration
        if speed > 0 {
            let minPerKm = (1000.0 / speed) / 60.0
            self.pace = String(format: "%.1f", minPerKm)
        }
    }
    
    private func resetMetrics() {
        heartRate = 0
        activeEnergy = 0
        distance = 0
        pace = "--"
        elapsed = 0
    }
    
    private func startLocalSmoothTimer() {
        timerTask?.cancel()
        timerTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard let self = self, let last = self.lastReceivedDate else { continue }
                
                if Date().timeIntervalSince(last) < 5 {
                    self.elapsed += 1
                }
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
