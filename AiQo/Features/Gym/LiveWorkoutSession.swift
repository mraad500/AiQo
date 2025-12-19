import Foundation
internal import Combine

@MainActor
final class LiveWorkoutSession: ObservableObject {
    static let shared = LiveWorkoutSession()

    @Published private(set) var workoutID: String?
    @Published private(set) var isRunning: Bool = false

    @Published var heartRate: Double = 0
    @Published var activeEnergy: Double = 0
    @Published var elapsed: TimeInterval = 0
    @Published var distance: Double = 0 // إضافة المسافة
    @Published var lastUpdate: Date = .distantPast

    private init() {}

    func start(workoutID: String) {
        self.workoutID = workoutID
        self.isRunning = true
        // تصفير العدادات عند البدء
        self.heartRate = 0
        self.activeEnergy = 0
        self.elapsed = 0
        self.distance = 0
    }

    func stop() {
        self.isRunning = false
        self.workoutID = nil
    }

    func applyLiveMetrics(workoutID: String?, payload: LiveMetricsPayload) {
        // التحقق من أن البيانات تابعة للجلسة الحالية
        if let current = self.workoutID, let incoming = workoutID, current != incoming {
            // يمكن إضافة لوج هنا، لكن سنرفض البيانات الخاطئة
            return
        }

        self.heartRate = payload.heartRate
        self.activeEnergy = payload.activeEnergy
        self.elapsed = payload.elapsed
        self.distance = payload.distance
        self.lastUpdate = payload.timestamp
    }
}
