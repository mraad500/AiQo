import Foundation
import WatchConnectivity
import Combine
import OSLog

@MainActor
final class WatchConnectivityManager: NSObject, ObservableObject {

    static let shared = WatchConnectivityManager()

    private let log = Logger(subsystem: "com.aiqo.app.watch", category: "WC.Watch")
    private let wcSession: WCSession? = WCSession.isSupported() ? .default : nil

    @Published private(set) var activationState: WCSessionActivationState = .notActivated
    @Published private(set) var isReachable: Bool = false

    @Published private(set) var lastReceived: String = "-"
    @Published private(set) var lastError: String = "-"

    private override init() { super.init() }

    // MARK: - Lifecycle
    func activate() {
        guard let wcSession else { return }
        wcSession.delegate = self
        wcSession.activate()
        refreshState()
        log.info("WCSession activate() called (Watch)")
    }

    func refreshState() {
        guard let wcSession else { return }
        activationState = wcSession.activationState
        isReachable = wcSession.isReachable
    }

    // MARK: - Outgoing (Watch -> iPhone)
    func publishLiveMetrics(workoutID: String, metrics: LiveMetricsPayload) {
        guard let data = WCCoding.encode(metrics) else { return }

        let payload: [String: Any] = [
            WCPayloadKey.workoutID.rawValue: workoutID,
            WCPayloadKey.metricsData.rawValue: data,
            WCPayloadKey.timestamp.rawValue: metrics.timestamp
        ]

        let envelope = [String: Any].wcEnvelope(kind: .liveMetrics, payload: payload)
        send(envelope, qosLabel: "liveMetrics")
    }

    func publishWorkoutState(workoutID: String, state: String) {
        let payload: [String: Any] = [
            WCPayloadKey.workoutID.rawValue: workoutID,
            WCPayloadKey.state.rawValue: state,
            WCPayloadKey.timestamp.rawValue: Date()
        ]
        let envelope = [String: Any].wcEnvelope(kind: .workoutState, payload: payload)
        send(envelope, qosLabel: "workoutState")
    }

    func publishError(_ message: String) {
        let payload: [String: Any] = [
            WCPayloadKey.errorMessage.rawValue: message,
            WCPayloadKey.timestamp.rawValue: Date()
        ]
        let envelope = [String: Any].wcEnvelope(kind: .error, payload: payload)
        send(envelope, qosLabel: "error")
    }

    func sendPing() {
        let payload: [String: Any] = [
            WCPayloadKey.text.rawValue: "ping from Watch",
            WCPayloadKey.timestamp.rawValue: Date()
        ]
        let envelope = [String: Any].wcEnvelope(kind: .ping, payload: payload)
        send(envelope, qosLabel: "ping")
    }

    // MARK: - Transport
    private func send(_ envelope: [String: Any], qosLabel: String) {
        guard let wcSession else { return }

        // Always update ApplicationContext for background consistency
        do { try wcSession.updateApplicationContext(envelope) }
        catch { log.warning("updateApplicationContext failed: \(error.localizedDescription)") }

        if wcSession.isReachable {
            wcSession.sendMessage(envelope, replyHandler: nil) { [weak self] error in
                Task { @MainActor in
                    self?.lastError = "sendMessage(\(qosLabel)) error: \(error.localizedDescription)"
                }
            }
        } else {
            wcSession.transferUserInfo(envelope)
        }
    }

    // MARK: - Incoming (iPhone -> Watch)
    private func routeIncoming(message: [String: Any]) {
        if let env = message.wcDecodeEnvelope() {
            lastReceived = "kind=\(env.kind.rawValue), v=\(env.version)"

            switch env.kind {
            case .command:
                handleCommand(payload: env.payload)

            case .ping:
                let text = env.payload[WCPayloadKey.text.rawValue] as? String ?? "ping"
                lastReceived = "PING: \(text)"

            default:
                break
            }
        } else {
            lastReceived = "raw message: \(message)"
        }
    }

    private func handleCommand(payload: [String: Any]) {
        guard
            let commandRaw = payload[WCPayloadKey.command.rawValue] as? String,
            let command = WCCommand(rawValue: commandRaw)
        else { return }

        switch command {
        case .startWorkout:
            let workoutID = payload[WCPayloadKey.workoutID.rawValue] as? String ?? UUID().uuidString
            let activityRaw = payload[WCPayloadKey.activityType.rawValue] as? Int ?? 37
            let locationRaw = payload[WCPayloadKey.locationType.rawValue] as? Int ?? 1

            WorkoutManager.shared.startFromPhone(
                workoutID: workoutID,
                activityTypeRaw: activityRaw,
                locationTypeRaw: locationRaw
            )

        case .endWorkout:
            WorkoutManager.shared.stop()

        case .pauseWorkout:
            WorkoutManager.shared.pause()

        case .resumeWorkout:
            WorkoutManager.shared.resume()
        }
    }
}

// MARK: - WCSessionDelegate
extension WatchConnectivityManager: WCSessionDelegate {

    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {
        Task { @MainActor in
            self.activationState = activationState
            self.refreshState()
            if let error { self.lastError = "activation error: \(error.localizedDescription)" }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in self.refreshState() }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        Task { @MainActor in self.routeIncoming(message: message) }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        Task { @MainActor in self.routeIncoming(message: userInfo) }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        Task { @MainActor in self.routeIncoming(message: applicationContext) }
    }
}

// MARK: - ConnectivityDebugProviding
extension WatchConnectivityManager: ConnectivityDebugProviding {

    var activationStateText: String {
        switch activationState {
        case .notActivated: return "notActivated"
        case .inactive: return "inactive"
        case .activated: return "activated"
        @unknown default: return "unknown"
        }
    }

    var reachabilityText: String {
        isReachable ? "reachable" : "not reachable"
    }
}
