// ===============================================
// File: WatchConnectivityManager.swift
// Target: watchOS
// ===============================================

import Foundation
import WatchConnectivity
import Combine
#if canImport(WatchKit)
import WatchKit
#endif

#if os(watchOS)
@MainActor
final class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()

    @Published private(set) var lastMessage: String = ""
    @Published private(set) var isPhoneReachable: Bool = false

    private override init() {
        super.init()

        guard WCSession.isSupported() else {
            print("⌚️ [WatchConnectivity] WCSession not supported")
            return
        }

        let session = WCSession.default
        session.delegate = self
        session.activate()
        print("⌚️ [WatchConnectivity] Session activation requested")
    }

    func sendWorkoutCompanionMessage(_ message: WorkoutCompanionMessage, guaranteed: Bool) {
        guard WCSession.isSupported() else { return }

        let session = WCSession.default
        guard session.activationState == .activated else {
            print("⌚️ [WatchConnectivity] Companion send skipped: session not activated")
            return
        }

        do {
            let data = try WorkoutSyncCodec.encodeCompanionMessage(message)
            let packet: [String: Any] = [WorkoutSyncDictionaryKey.workoutCompanionMessage: data]

            if session.isReachable {
                session.sendMessage(packet, replyHandler: nil) { error in
                    print("⌚️ [WatchConnectivity] Companion send failed: \(error.localizedDescription)")
                    guard guaranteed else { return }
                    session.transferUserInfo(packet)
                    print("⌚️ [WatchConnectivity] Companion fallback queued")
                }
            } else if guaranteed {
                session.transferUserInfo(packet)
            } else {
                try session.updateApplicationContext(packet)
            }
        } catch {
            print("⌚️ [WatchConnectivity] Companion encode failed: \(error.localizedDescription)")
        }
    }

    func updateWorkoutSnapshotContext(_ snapshot: WorkoutSyncSnapshot) {
        guard WCSession.isSupported() else { return }

        let session = WCSession.default
        guard session.activationState == .activated else {
            print("⌚️ [WatchConnectivity] Snapshot context skipped: session not activated")
            return
        }

        do {
            try session.updateApplicationContext(
                [WorkoutSyncDictionaryKey.snapshotContext: snapshot.dictionaryRepresentation]
            )
        } catch {
            print("⌚️ [WatchConnectivity] Snapshot context failed: \(error.localizedDescription)")
        }
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Self.runOnMain { [weak self] in
            self?.applyActivationState(session: session, activationState: activationState, error: error)
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Self.runOnMain { [weak self] in
            self?.applyReachability(session.isReachable)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Self.runOnMain { [weak self] in
            self?.handleIncomingData(message)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        Self.runOnMain { [weak self] in
            self?.handleIncomingData(message)
        }
        replyHandler(["status": "received"])
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        Self.runOnMain { [weak self] in
            self?.handleIncomingData(userInfo)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Self.runOnMain { [weak self] in
            self?.handleIncomingData(applicationContext)
        }
    }

    private func handleIncomingData(_ data: [String: Any]) {
        if let startRequest = WorkoutCompanionStartRequest(dictionary: data) {
            lastMessage = "command=\(startRequest.companionCommand.rawValue)"
            print("⌚️ [WatchConnectivity] Received start request: \(startRequest.companionCommand.rawValue)")
            WorkoutManager.shared.handleCompanionStartRequest(startRequest)
            return
        }

        if let companionData = data[WorkoutSyncDictionaryKey.workoutCompanionMessage] as? Data {
            do {
                let message = try WorkoutSyncCodec.decodeCompanionMessage(companionData)
                lastMessage = "kind=\(message.kind.rawValue)"
                print("⌚️ [WatchConnectivity] Received workout companion message: \(message.kind.rawValue)")
                WorkoutManager.shared.handleCompanionMessage(message)
            } catch {
                print("⌚️ [WatchConnectivity] Companion decode failed: \(error.localizedDescription)")
            }
            return
        }

        lastMessage = data.description
        print("⌚️ [WatchConnectivity] Received data: \(data)")

        guard let event = data["event"] as? String else { return }

        switch event {
        case "rep_detected":
            playRepDetectedHaptic()
        case "challenge_completed":
            playChallengeCompletedHaptic()
        default:
            break
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

    private func applyActivationState(
        session: WCSession,
        activationState: WCSessionActivationState,
        error: Error?
    ) {
        isPhoneReachable = session.isReachable

        if let error {
            print("⌚️ [WatchConnectivity] Activation error: \(error.localizedDescription)")
        } else {
            print("⌚️ [WatchConnectivity] Activation complete: \(activationState.rawValue)")
        }
    }

    private func applyReachability(_ reachable: Bool) {
        isPhoneReachable = reachable
        print("⌚️ [WatchConnectivity] Reachability changed: \(reachable)")
    }

    nonisolated private static func runOnMain(_ operation: @escaping @MainActor () -> Void) {
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                operation()
            }
            return
        }

        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                operation()
            }
        }
    }
}
#else
final class WatchConnectivityManager: ObservableObject {
    static let shared = WatchConnectivityManager()

    @Published private(set) var lastMessage: String = ""
    @Published private(set) var isPhoneReachable: Bool = false

    private init() {}

    func sendWorkoutCompanionMessage(_ message: WorkoutCompanionMessage, guaranteed: Bool) {
        lastMessage = "kind=\(message.kind.rawValue)"
        print("⌚️ [WatchConnectivity] Companion send unavailable in fallback runtime (guaranteed=\(guaranteed))")
    }

    func updateWorkoutSnapshotContext(_ snapshot: WorkoutSyncSnapshot) {
        lastMessage = "snapshot=\(snapshot.currentState.rawValue)"
        print("⌚️ [WatchConnectivity] Snapshot context unavailable in fallback runtime")
    }
}
#endif
