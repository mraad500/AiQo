// ===============================================
// File: WatchConnectivityManager.swift
// Target: WatchOS
// ===============================================

import Foundation
import WatchConnectivity
import HealthKit
import Combine
#if canImport(WatchKit)
import WatchKit
#endif

#if os(watchOS)
class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    
    // MARK: - Singleton
    static let shared = WatchConnectivityManager()
    
    // MARK: - Published Properties
    @Published var lastMessage: String = ""
    @Published var isPhoneReachable: Bool = false
    
    // Reference to WorkoutManager (set during init)
    weak var workoutManager: WorkoutManager?
    
    private var latestLiveTransfer: WCSessionUserInfoTransfer?
    private var lastLivePayload: [String: Any]?
    private var packetSequence: Int = 0

    // MARK: - Initialization
    
    override init() {
        super.init()
        
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
            print("⌚️ [WatchConnectivity] Session activation requested")
        } else {
            print("⌚️ [WatchConnectivity] WCSession not supported")
        }
    }
    
    // MARK: - Send Live Data to iPhone
    /// Sends real-time workout data to the iPhone
    /// Uses sendMessage for fastest delivery when reachable
    
    func sendLiveData(data: [String: Any]) {
        let session = WCSession.default
        guard session.activationState == .activated else {
            print("⌚️ [WatchConnectivity] Session not activated, cannot send data")
            return
        }
        
        packetSequence &+= 1
        var payload = data
        payload["sentAt"] = Date().timeIntervalSince1970
        payload["packetSeq"] = packetSequence
        lastLivePayload = payload
        
        if session.isReachable {
            // Real-time delivery when iPhone app is in foreground
            session.sendMessage(payload, replyHandler: nil) { error in
                print("⌚️ [WatchConnectivity] sendMessage error: \(error.localizedDescription)")
            }
        } else {
            // Keep latest snapshot available without building a large queue.
            do {
                try session.updateApplicationContext(payload)
            } catch {
                print("⌚️ [WatchConnectivity] updateApplicationContext error: \(error.localizedDescription)")
            }
            
            // Keep only the newest transfer in queue to avoid lag buildup.
            latestLiveTransfer?.cancel()
            latestLiveTransfer = session.transferUserInfo(payload)
        }
    }
    
    // MARK: - Send Command to iPhone
    
    func sendCommand(_ command: [String: Any]) {
        guard WCSession.default.activationState == .activated else { return }
        
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(command, replyHandler: nil) { error in
                print("⌚️ [WatchConnectivity] Command send error: \(error.localizedDescription)")
            }
        } else {
            WCSession.default.transferUserInfo(command)
        }
    }

    // MARK: - WCSessionDelegate
    
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        DispatchQueue.main.async {
            self.isPhoneReachable = session.isReachable
        }
        
        if let error = error {
            print("⌚️ [WatchConnectivity] Activation error: \(error.localizedDescription)")
        } else {
            print("⌚️ [WatchConnectivity] Activation complete: \(activationState.rawValue)")
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isPhoneReachable = session.isReachable
        }
        print("⌚️ [WatchConnectivity] Reachability changed: \(session.isReachable)")
        
        // When link becomes reachable again, flush latest snapshot instantly.
        if session.isReachable, let payload = lastLivePayload {
            session.sendMessage(payload, replyHandler: nil) { error in
                print("⌚️ [WatchConnectivity] flush sendMessage error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Receive Messages from iPhone
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        handleIncomingData(message)
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        handleIncomingData(message)
        
        // Send acknowledgment back to iPhone
        replyHandler(["status": "received", "timestamp": Date().timeIntervalSince1970])
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        handleIncomingData(userInfo)
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        handleIncomingData(applicationContext)
    }
    
    // MARK: - Handle Incoming Data
    /// Processes commands and data received from iPhone via WCSession
    /// Note: startWatchApp workflow bypasses this (goes through WKExtensionDelegate)
    
    private func handleIncomingData(_ data: [String: Any]) {
        print("⌚️ [WatchConnectivity] Received data: \(data)")
        
        DispatchQueue.main.async { [weak self] in
            self?.lastMessage = data.description
        }

        if let event = data["event"] as? String {
            handleVisionCoachEvent(event)
            return
        }
        
        // Handle stop command
        if let command = data["command"] as? String {
            switch command {
            case "stopWorkout":
                DispatchQueue.main.async { [weak self] in
                    self?.workoutManager?.stopWorkout()
                }
                return
                
            case "pauseWorkout":
                DispatchQueue.main.async { [weak self] in
                    self?.workoutManager?.pause()
                }
                return
                
            case "resumeWorkout":
                DispatchQueue.main.async { [weak self] in
                    self?.workoutManager?.resume()
                }
                return
                
            case "startWorkout":
                // Fallback: Start default workout if no config provided
                if data["activityTypeRaw"] == nil {
                    DispatchQueue.main.async { [weak self] in
                        self?.workoutManager?.startDefaultWorkout()
                    }
                    return
                }
                
            default:
                print("⌚️ [WatchConnectivity] Unknown command: \(command)")
            }
        }
        
        // Handle workout start with configuration
        // This is the FALLBACK path when startWatchApp isn't used
        if let activityRaw = data["activityTypeRaw"] as? Int {
            let activityType = HKWorkoutActivityType(rawValue: UInt(activityRaw)) ?? .other
            let locationRaw = data["locationTypeRaw"] as? Int ?? 1
            let locationType = HKWorkoutSessionLocationType(rawValue: locationRaw) ?? .indoor
            
            print("⌚️ [WatchConnectivity] Starting workout via WCSession - Activity: \(activityRaw), Location: \(locationRaw)")
            
            DispatchQueue.main.async { [weak self] in
                self?.workoutManager?.startWorkout(
                    workoutType: activityType,
                    locationType: locationType
                )
            }
        }
    }

    private func handleVisionCoachEvent(_ event: String) {
        DispatchQueue.main.async {
            switch event {
            case "rep_detected":
                self.playRepDetectedHaptic()
            case "challenge_completed":
                self.playChallengeCompletedHaptic()
            default:
                break
            }
        }
    }

    private func playRepDetectedHaptic() {
        let device = WKInterfaceDevice.current()
        device.play(.directionUp)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) {
            WKInterfaceDevice.current().play(.click)
        }
    }

    private func playChallengeCompletedHaptic() {
        let device = WKInterfaceDevice.current()
        device.play(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
            WKInterfaceDevice.current().play(.success)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
            WKInterfaceDevice.current().play(.directionUp)
        }
    }
}
#else
final class WatchConnectivityManager: ObservableObject {
    static let shared = WatchConnectivityManager()

    @Published var lastMessage: String = ""
    @Published var isPhoneReachable: Bool = false

    weak var workoutManager: WorkoutManager?

    private init() {}

    func sendLiveData(data: [String: Any]) {}
    func sendCommand(_ command: [String: Any]) {}
}
#endif
