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
}
#endif
