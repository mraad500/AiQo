import Foundation
import WatchConnectivity
import HealthKit // ✅ هذا كان ناقص
internal import Combine
import OSLog

@MainActor
final class PhoneConnectivityManager: NSObject, ObservableObject {

    static let shared = PhoneConnectivityManager()

    private let log = Logger(subsystem: "com.aiqo.app", category: "WC.Phone")
    private let wcSession: WCSession? = WCSession.isSupported() ? .default : nil

    @Published private(set) var activationState: WCSessionActivationState = .notActivated
    @Published private(set) var isPaired: Bool = false
    @Published private(set) var isWatchAppInstalled: Bool = false
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
        log.info("WCSession activate() called (iOS)")
    }

    func refreshState() {
        guard let wcSession else { return }
        activationState = wcSession.activationState
        isPaired = wcSession.isPaired
        isWatchAppInstalled = wcSession.isWatchAppInstalled
        isReachable = wcSession.isReachable
    }

    // MARK: - Controller API (iPhone -> Watch)
    func startWorkoutOnWatch(activityTypeRaw: Int, locationTypeRaw: Int) {
        let workoutID = UUID().uuidString

        // 1. إعداد الكونغريشن لإيقاظ الساعة
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = HKWorkoutActivityType(rawValue: UInt(activityTypeRaw)) ?? .running
        configuration.locationType = HKWorkoutSessionLocationType(rawValue: locationTypeRaw) ?? .outdoor

        // 2. أمر HealthKit لفتح تطبيق الساعة
        let healthStore = HKHealthStore()
        healthStore.startWatchApp(with: configuration) { [weak self] success, error in
            guard let self = self else { return }
            
            if let error = error {
                self.log.error("Failed to launch watch app: \(error.localizedDescription)")
            } else {
                self.log.info("Watch app launched successfully!")
            }

            // 3. إرسال أمر البدء عبر WCSession
            let payload: [String: Any] = [
                WCPayloadKey.command.rawValue: WCCommand.startWorkout.rawValue,
                WCPayloadKey.workoutID.rawValue: workoutID,
                WCPayloadKey.activityType.rawValue: activityTypeRaw,
                WCPayloadKey.locationType.rawValue: locationTypeRaw,
                WCPayloadKey.startDate.rawValue: Date()
            ]

            let envelope = [String: Any].wcEnvelope(kind: .command, payload: payload)

            // الرجوع للـ Main Thread للتحديث والارسال
            Task { @MainActor in
                LiveWorkoutSession.shared.start(workoutID: workoutID)
                self.send(envelope, qosLabel: "startWorkout")
            }
        }
    }

    func stopWorkoutOnWatch() {
        let workoutID = LiveWorkoutSession.shared.workoutID ?? UUID().uuidString

        let payload: [String: Any] = [
            WCPayloadKey.command.rawValue: WCCommand.endWorkout.rawValue,
            WCPayloadKey.workoutID.rawValue: workoutID,
            WCPayloadKey.endDate.rawValue: Date()
        ]

        let envelope = [String: Any].wcEnvelope(kind: .command, payload: payload)

        send(envelope, qosLabel: "stopWorkout")
        LiveWorkoutSession.shared.stop()
    }

    func sendPing() {
        let payload: [String: Any] = [
            WCPayloadKey.text.rawValue: "ping from iPhone",
            WCPayloadKey.timestamp.rawValue: Date()
        ]
        let envelope = [String: Any].wcEnvelope(kind: .ping, payload: payload)
        send(envelope, qosLabel: "ping")
    }

    // MARK: - Transport (realtime + fallbacks)
    private func send(_ envelope: [String: Any], qosLabel: String) {
        guard let wcSession else { return }

        // Last known state
        do { try wcSession.updateApplicationContext(envelope) }
        catch { log.warning("updateApplicationContext failed: \(error.localizedDescription)") }

        if wcSession.isReachable {
            wcSession.sendMessage(envelope, replyHandler: nil) { [weak self] error in
                Task { @MainActor in
                    self?.lastError = "sendMessage(\(qosLabel)) error: \(error.localizedDescription)"
                }
            }
        } else {
            // Background fallback
            wcSession.transferUserInfo(envelope)
        }
    }

    // MARK: - Incoming (Watch -> iPhone)
    private func handleIncoming(message: [String: Any]) {
        if let env = message.wcDecodeEnvelope() {
            lastReceived = "kind=\(env.kind.rawValue), v=\(env.version)"

            switch env.kind {
            case .liveMetrics:
                guard
                    let workoutID = env.payload[WCPayloadKey.workoutID.rawValue] as? String,
                    let data = env.payload[WCPayloadKey.metricsData.rawValue] as? Data,
                    let metrics = WCCoding.decode(LiveMetricsPayload.self, from: data)
                else { return }

                LiveWorkoutSession.shared.applyLiveMetrics(workoutID: workoutID, payload: metrics)

            case .workoutState:
                let state = env.payload[WCPayloadKey.state.rawValue] as? String
                if state == "stopped" { LiveWorkoutSession.shared.stop() }

            case .ping:
                let text = env.payload[WCPayloadKey.text.rawValue] as? String ?? "ping"
                lastReceived = "PING: \(text)"

            case .error:
                lastError = env.payload[WCPayloadKey.errorMessage.rawValue] as? String ?? "Unknown watch error"

            default:
                break
            }
        } else {
            lastReceived = "raw message: \(message)"
        }
    }
}

// MARK: - WCSessionDelegate
extension PhoneConnectivityManager: WCSessionDelegate {

    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {
        Task { @MainActor in
            self.activationState = activationState
            self.refreshState()
            if let error { self.lastError = "activation error: \(error.localizedDescription)" }
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        Task { @MainActor in self.refreshState() }
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
        Task { @MainActor in self.refreshState() }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in self.refreshState() }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        Task { @MainActor in self.handleIncoming(message: message) }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        Task { @MainActor in self.handleIncoming(message: userInfo) }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        Task { @MainActor in self.handleIncoming(message: applicationContext) }
    }
}
