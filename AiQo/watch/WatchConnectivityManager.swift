import Foundation
import WatchConnectivity
internal import Combine
import HealthKit

@MainActor
final class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    
    //  ✅ تم تعديله ليكون weak لتجنب Retain Cycles
    weak var workoutDelegate: WorkoutManager?
    
    private let wcSession: WCSession? = WCSession.isSupported() ? .default : nil
    @Published private(set) var isReachable: Bool = false
    
    private override init() { super.init() }
    
    func activate() {
        wcSession?.delegate = self
        wcSession?.activate()
    }
    
    // إرسال البيانات الحية (Priority: High)
    func publishLiveMetrics(workoutID: String, metrics: LiveMetricsPayload) {
        guard let wcSession, let data = WCCoding.encode(metrics) else { return }
        
        let payload: [String: Any] = [
            WCPayloadKey.workoutID.rawValue: workoutID,
            WCPayloadKey.metricsData.rawValue: data,
            WCPayloadKey.timestamp.rawValue: metrics.timestamp
        ]
        
        let envelope = [String: Any].wcEnvelope(kind: .liveMetrics, payload: payload)
        
        //  ✅ استخدام sendMessage دائماً للبيانات الحية لضمان السرعة
        if wcSession.isReachable {
            wcSession.sendMessage(envelope, replyHandler: nil) { error in
                print("Error sending metrics: \(error.localizedDescription)")
            }
        }
    }
    
    // إرسال حالة التمرين (Start/End)
    func publishWorkoutState(workoutID: String, state: String) {
        let payload: [String: Any] = [
            WCPayloadKey.workoutID.rawValue: workoutID,
            WCPayloadKey.state.rawValue: state
        ]
        let envelope = [String: Any].wcEnvelope(kind: .workoutState, payload: payload)
        
        if let wcSession = wcSession, wcSession.isReachable {
            wcSession.sendMessage(envelope, replyHandler: nil)
        } else {
            // استخدام transferUserInfo كخطة بديلة إذا لم يكن متصلاً
            wcSession?.transferUserInfo(envelope)
        }
    }
    
    // استقبال الأوامر من الآيفون
    private func handleIncoming(message: [String: Any]) {
        guard let env = message.wcDecodeEnvelope(), env.kind == .command else { return }
        let payload = env.payload
        
        guard let cmdRaw = payload[WCPayloadKey.command.rawValue] as? String,
              let cmd = WCCommand(rawValue: cmdRaw) else { return }
        
        switch cmd {
        case .startWorkout:
            let actRaw = payload[WCPayloadKey.activityType.rawValue] as? UInt ?? 37
            let hkType = HKWorkoutActivityType(rawValue: actRaw) ?? .other
            
            let locRaw = payload[WCPayloadKey.locationType.rawValue] as? Int ?? 1
            let hkLocation = HKWorkoutSessionLocationType(rawValue: locRaw) ?? .unknown
            
            Task { @MainActor in
                self.workoutDelegate?.startWorkout(workoutType: hkType, location: hkLocation)
            }
            
        case .endWorkout:
            Task { @MainActor in
                self.workoutDelegate?.endWorkout()
            }
            
        default: break
        }
    }
}

extension WatchConnectivityManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        Task { @MainActor in self.isReachable = session.isReachable }
    }
    
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in self.isReachable = session.isReachable }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        Task { @MainActor in self.handleIncoming(message: message) }
    }
}
