// ===============================================
// File: PhoneConnectivityManager.swift
// Target: iOS
// ===============================================

import Foundation
import WatchConnectivity
import HealthKit
internal import Combine

class PhoneConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    enum VisionCoachEvent: String {
        case repDetected = "rep_detected"
        case challengeCompleted = "challenge_completed"
    }
    
    // MARK: - Singleton
    static let shared = PhoneConnectivityManager()

    // MARK: - HealthKit
    private let healthStore = HKHealthStore()

    // MARK: - Published Properties - Connection Status
    @Published var isReachable: Bool = false
    @Published var isPaired: Bool = false
    @Published var isWatchAppInstalled: Bool = false
    @Published var activationState: WCSessionActivationState = .notActivated

    // MARK: - Published Properties - Live Workout Data from Watch
    @Published var currentHeartRate: Double = 0
    @Published var activeEnergy: Double = 0
    @Published var currentDuration: Double = 0
    @Published var currentDistance: Double = 0
    
    // MARK: - Published Properties - Debug/Status
    @Published var lastReceived: String = "None"
    @Published var lastError: String = "None"
    
    private var lastPacketSequence: Int = -1

    // MARK: - Initialization
    
    override init() {
        super.init()
        
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
            print("📱 [PhoneConnectivity] Session activation requested")
        } else {
            print("📱 [PhoneConnectivity] WCSession not supported on this device")
        }
    }

    // MARK: - ✅ Launch Watch App for Workout (Using HKHealthStore)
    /// This method uses HKHealthStore.startWatchApp to reliably wake the Watch app.
    /// The Watch app's WKExtensionDelegate.handle(_:) receives the configuration.
    ///
    /// NOTE: This is called from HealthKitManager or LiveWorkoutSession, not directly.
    /// It's kept here for backward compatibility.
    
    func launchWatchAppForWorkout(
        activityType: HKWorkoutActivityType,
        locationType: HKWorkoutSessionLocationType
    ) {
        guard HKHealthStore.isHealthDataAvailable() else {
            DispatchQueue.main.async {
                self.lastError = "HealthKit not available"
            }
            return
        }

        let config = HKWorkoutConfiguration()
        config.activityType = activityType
        config.locationType = locationType

        healthStore.startWatchApp(with: config) { [weak self] success, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.lastError = "startWatchApp error: \(error.localizedDescription)"
                    print("📱 [PhoneConnectivity] startWatchApp failed: \(error.localizedDescription)")
                } else if !success {
                    self?.lastError = "startWatchApp returned false"
                    print("📱 [PhoneConnectivity] startWatchApp returned false")
                } else {
                    print("📱 [PhoneConnectivity] Watch app launched successfully")
                }
            }
        }
    }

    // MARK: - Start Workout on Watch (via WCSession - Fallback)
    /// This is the FALLBACK method using WCSession.
    /// Use launchWatchAppForWorkout for reliable background wake-up.
    
    func startWorkoutOnWatch(activityTypeRaw: Int, locationTypeRaw: Int) {
        let data: [String: Any] = [
            "command": "startWorkout",
            "activityTypeRaw": activityTypeRaw,
            "locationTypeRaw": locationTypeRaw
        ]
        sendCommand(data)
    }

    // MARK: - Stop Workout on Watch
    
    func stopWorkoutOnWatch() {
        sendCommand(["command": "stopWorkout"])
    }
    
    // MARK: - Pause/Resume Workout on Watch
    
    func pauseWorkoutOnWatch() {
        sendCommand(["command": "pauseWorkout"])
    }
    
    func resumeWorkoutOnWatch() {
        sendCommand(["command": "resumeWorkout"])
    }

    func sendVisionCoachEvent(_ event: VisionCoachEvent) {
        guard WCSession.default.activationState == .activated else { return }

        let payload: [String: Any] = [
            "event": event.rawValue
        ]

        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: nil) { error in
                print("📱 [PhoneConnectivity] Vision event send error: \(error.localizedDescription)")
            }
        } else {
            WCSession.default.transferUserInfo(payload)
        }
    }

    // MARK: - Send Command Helper
    
    private func sendCommand(_ data: [String: Any]) {
        guard WCSession.default.activationState == .activated else {
            print("📱 [PhoneConnectivity] Session not activated")
            DispatchQueue.main.async {
                self.lastError = "WCSession not activated"
            }
            return
        }

        if WCSession.default.isReachable {
            // Fast, real-time delivery
            WCSession.default.sendMessage(data, replyHandler: { reply in
                print("📱 [PhoneConnectivity] Command acknowledged: \(reply)")
            }) { [weak self] error in
                DispatchQueue.main.async {
                    self?.lastError = error.localizedDescription
                }
                print("📱 [PhoneConnectivity] sendMessage error: \(error.localizedDescription)")
            }
        } else {
            // Background-safe fallback (may be delayed)
            WCSession.default.transferUserInfo(data)
            print("📱 [PhoneConnectivity] Using transferUserInfo (Watch not reachable)")
        }
    }

    // MARK: - WCSessionDelegate - Activation
    
    func session(
        _ session: WCSession,
        activationDidCompleteWith state: WCSessionActivationState,
        error: Error?
    ) {
        DispatchQueue.main.async {
            self.activationState = state
            self.isReachable = session.isReachable
            self.isPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
        }
        
        if let error = error {
            print("📱 [PhoneConnectivity] Activation error: \(error.localizedDescription)")
        } else {
            print("📱 [PhoneConnectivity] Activation complete: \(state.rawValue)")
            print("   isPaired: \(session.isPaired)")
            print("   isWatchAppInstalled: \(session.isWatchAppInstalled)")
            print("   isReachable: \(session.isReachable)")
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
        print("📱 [PhoneConnectivity] Reachability changed: \(session.isReachable)")
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
        }
        print("📱 [PhoneConnectivity] Watch state changed - Paired: \(session.isPaired), Installed: \(session.isWatchAppInstalled)")
    }

    // MARK: - WCSessionDelegate - Receive Messages
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        handleIncomingData(message)
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        handleIncomingData(message)
        replyHandler(["status": "received"])
    }
    
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        handleIncomingData(userInfo)
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        handleIncomingData(applicationContext)
    }
    
    // MARK: - Handle Incoming Data from Watch
    
    private func handleIncomingData(_ message: [String: Any]) {
        print("📱 [PhoneConnectivity] Received: \(message)")
        
        if let sequence = Self.intValue(for: "packetSeq", in: message) {
            if sequence < lastPacketSequence {
                // Drop stale packet that arrived out-of-order.
                return
            }
            lastPacketSequence = sequence
        }
        
        DispatchQueue.main.async {
            self.lastReceived = message.description
            
            // Update live workout data
            if let hr = Self.doubleValue(for: "heartRate", in: message) {
                self.currentHeartRate = hr
            }
            if let energy = Self.doubleValue(for: "activeEnergy", in: message) {
                self.activeEnergy = energy
            }
            if let duration = Self.doubleValue(for: "duration", in: message) {
                self.currentDuration = duration
            }
            if let dist = Self.doubleValue(for: "distance", in: message) {
                self.currentDistance = dist
            }
        }
    }
    
    private static func doubleValue(for key: String, in message: [String: Any]) -> Double? {
        if let value = message[key] as? Double {
            return value
        }
        if let value = message[key] as? Int {
            return Double(value)
        }
        if let value = message[key] as? NSNumber {
            return value.doubleValue
        }
        return nil
    }
    
    private static func intValue(for key: String, in message: [String: Any]) -> Int? {
        if let value = message[key] as? Int {
            return value
        }
        if let value = message[key] as? NSNumber {
            return value.intValue
        }
        if let value = message[key] as? Double {
            return Int(value)
        }
        return nil
    }

    // MARK: - Required Delegate Methods
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("📱 [PhoneConnectivity] Session became inactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        print("📱 [PhoneConnectivity] Session deactivated, reactivating...")
        WCSession.default.activate()
    }
}
