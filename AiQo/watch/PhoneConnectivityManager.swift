import Foundation
import WatchConnectivity
internal import Combine

class PhoneConnectivityManager: NSObject, ObservableObject {
    static let shared = PhoneConnectivityManager()
    private let wcSession = WCSession.default
    
    @Published var activationState: WCSessionActivationState = .notActivated
    @Published var isReachable: Bool = false
    @Published var isPaired: Bool = false
    @Published var isWatchAppInstalled: Bool = false
    
    @Published var lastReceived: String = "No data"
    @Published var lastError: String = "-"
    
    override init() {
        super.init()
        if WCSession.isSupported() {
            wcSession.delegate = self
        }
    }
    
    func activate() {
        if WCSession.isSupported() {
            wcSession.activate()
        }
    }
    
    private func updateState() {
        DispatchQueue.main.async {
            self.activationState = self.wcSession.activationState
            self.isReachable = self.wcSession.isReachable
            self.isPaired = self.wcSession.isPaired
            self.isWatchAppInstalled = self.wcSession.isWatchAppInstalled
        }
    }
    
    // MARK: - Commands
    func startWorkoutOnWatch(activityTypeRaw: Int, locationTypeRaw: Int) {
        let payload: [String: Any] = [
            WCPayloadKey.command.rawValue: WCCommand.startWorkout.rawValue,
            WCPayloadKey.activityType.rawValue: activityTypeRaw,
            WCPayloadKey.locationType.rawValue: locationTypeRaw
        ]
        send(payload: payload)
    }
    
    func stopWorkoutOnWatch() {
        let payload: [String: Any] = [
            WCPayloadKey.command.rawValue: WCCommand.endWorkout.rawValue
        ]
        send(payload: payload)
    }
    
    func sendPing() {
        let payload: [String: Any] = ["text": "Ping from iPhone", "timestamp": Date()]
        send(payload: payload)
    }
    
    private func send(payload: [String: Any]) {
        let envelope = [String: Any].wcEnvelope(kind: .command, payload: payload)
        if wcSession.isReachable {
            wcSession.sendMessage(envelope, replyHandler: nil) { error in
                DispatchQueue.main.async { self.lastError = error.localizedDescription }
            }
        }
    }
    
    // MARK: - Incoming Data Logic
    private func handleIncoming(_ userInfo: [String: Any]) {
        guard let env = userInfo.wcDecodeEnvelope() else { return }
        
        DispatchQueue.main.async {
            self.lastReceived = "Kind: \(env.kind.rawValue) at \(Date())"
            
            switch env.kind {
            case .liveMetrics:
                //  ✅ فك تشفير البيانات القادمة من الساعة
                if let data = env.payload[WCPayloadKey.metricsData.rawValue] as? Data {
                    if let metrics = WCCoding.decode(LiveMetricsPayload.self, from: data) {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("LiveMetricsReceived"),
                            object: nil,
                            userInfo: ["metrics": metrics]
                        )
                    }
                }
                
            case .workoutState:
                //  ✅ استقبال حالات البدء والإنهاء
                if let state = env.payload[WCPayloadKey.state.rawValue] as? String {
                    if state == "started" {
                        NotificationCenter.default.post(name: NSNotification.Name("WorkoutDidStart"), object: nil)
                    } else if state == "ended" {
                        NotificationCenter.default.post(name: NSNotification.Name("WorkoutDidEnd"), object: nil)
                    }
                }
                
            default: break
            }
        }
    }
}

extension PhoneConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) { updateState() }
    func sessionDidBecomeInactive(_ session: WCSession) { updateState() }
    func sessionDidDeactivate(_ session: WCSession) { session.activate(); updateState() }
    func sessionReachabilityDidChange(_ session: WCSession) { updateState() }
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) { handleIncoming(message) }
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) { handleIncoming(userInfo) }
}
