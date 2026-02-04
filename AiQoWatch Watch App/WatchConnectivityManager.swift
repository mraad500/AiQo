import Foundation
import WatchConnectivity
import HealthKit
import Combine
class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    
    static let shared = WatchConnectivityManager()
    @Published var lastMessage: String = ""
    
    var workoutManager: WorkoutManager?

    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {}

    // استلام الرسائل من الايفون
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        handleIncomingData(message)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        handleIncomingData(userInfo)
    }
    
    // ✅ دالة جديدة: إرسال البيانات الحية إلى الايفون
    func sendLiveData(data: [String: Any]) {
        // نستخدم sendMessage لأنه الأسرع (Real-time)
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(data, replyHandler: nil) { error in
                print("Error sending live data: \(error.localizedDescription)")
            }
        }
    }
    
    private func handleIncomingData(_ data: [String: Any]) {
        print("⌚️ Watch received data: \(data)")
        
        if let command = data["command"] as? String, command == "stopWorkout" {
            DispatchQueue.main.async {
                self.workoutManager?.stopWorkout()
            }
            return
        }
        
        if let activityRaw = data["activityTypeRaw"] as? Int {
            let activityType = HKWorkoutActivityType(rawValue: UInt(activityRaw)) ?? .other
            // قراءة نوع الموقع ايضاً اذا موجود
            let locationRaw = data["locationTypeRaw"] as? Int ?? 1 // 1 = indoor default
            let locationType = HKWorkoutSessionLocationType(rawValue: locationRaw) ?? .indoor
            
            print("⌚️ Starting workout: \(activityType.rawValue), loc: \(locationType.rawValue)")
            
            DispatchQueue.main.async {
                self.workoutManager?.startWorkout(workoutType: activityType, locationType: locationType)
            }
        }
        else if let command = data["command"] as? String, command == "startWorkout" {
            DispatchQueue.main.async {
                self.workoutManager?.startDefaultWorkout()
            }
        }
    }
}
