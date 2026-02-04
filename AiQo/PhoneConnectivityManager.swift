// ===============================
// File: PhoneConnectivityManager.swift (update)
// Target: iOS
// ===============================

import Foundation
import WatchConnectivity
import HealthKit
internal import Combine

class PhoneConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = PhoneConnectivityManager()

    private let healthStore = HKHealthStore()

    @Published var isReachable: Bool = false
    @Published var isPaired: Bool = false
    @Published var isWatchAppInstalled: Bool = false
    @Published var activationState: WCSessionActivationState = .notActivated

    @Published var currentHeartRate: Double = 0
    @Published var activeEnergy: Double = 0
    @Published var currentDuration: Double = 0
    @Published var currentDistance: Double = 0
    @Published var lastReceived: String = "None"
    @Published var lastError: String = "None"

    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    // ✅ NEW: Wake/launch the watch workout app with a configuration  [oai_citation:8‡Apple Developer](https://developer.apple.com/documentation/healthkit/hkhealthstore/startwatchapp%28with%3Acompletion%3A%29?utm_source=chatgpt.com)
    func launchWatchAppForWorkout(activityType: HKWorkoutActivityType, locationType: HKWorkoutSessionLocationType) {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let config = HKWorkoutConfiguration()
        config.activityType = activityType
        config.locationType = locationType

        healthStore.startWatchApp(with: config) { [weak self] ok, error in
            DispatchQueue.main.async {
                if let error {
                    self?.lastError = "startWatchApp error: \(error.localizedDescription)"
                } else if !ok {
                    self?.lastError = "startWatchApp failed (ok=false)"
                }
            }
        }
    }

    func startWorkoutOnWatch(activityTypeRaw: Int, locationTypeRaw: Int) {
        let data: [String: Any] = [
            "command": "startWorkout",
            "activityTypeRaw": activityTypeRaw,
            "locationTypeRaw": locationTypeRaw
        ]
        sendCommand(data)
    }

    func stopWorkoutOnWatch() {
        sendCommand(["command": "stopWorkout"])
    }

    private func sendCommand(_ data: [String: Any]) {
        guard WCSession.default.activationState == .activated else { return }

        if WCSession.default.isReachable {
            WCSession.default.sendMessage(data, replyHandler: nil) { [weak self] error in
                DispatchQueue.main.async { self?.lastError = error.localizedDescription }
            }
        } else {
            // background-safe fallback  [oai_citation:9‡Apple Developer](https://developer.apple.com/documentation/watchconnectivity/wcsession?utm_source=chatgpt.com)
            WCSession.default.transferUserInfo(data)
        }
    }

    // MARK: - WCSessionDelegate
    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.activationState = state
            self.isReachable = session.isReachable
            self.isPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { self.isReachable = session.isReachable }
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            self.lastReceived = message.description
            if let hr = message["heartRate"] as? Double { self.currentHeartRate = hr }
            if let energy = message["activeEnergy"] as? Double { self.activeEnergy = energy }
            if let duration = message["duration"] as? Double { self.currentDuration = duration }
            if let dist = message["distance"] as? Double { self.currentDistance = dist }
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { WCSession.default.activate() }
}
