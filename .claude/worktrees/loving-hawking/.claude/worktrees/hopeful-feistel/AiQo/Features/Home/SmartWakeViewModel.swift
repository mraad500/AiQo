internal import Combine
import Foundation

@MainActor
final class SmartWakeViewModel: ObservableObject {
    @Published private(set) var mode: SmartWakeMode
    @Published private(set) var bedtime: Date
    @Published private(set) var latestWakeTime: Date
    @Published private(set) var wakeWindow: SmartWakeWindow
    @Published private(set) var selectedRecommendationID: String?
    @Published private(set) var featuredRecommendation: SmartWakeRecommendation?
    @Published private(set) var alternateRecommendations: [SmartWakeRecommendation]
    @Published private(set) var inlineMessage: String?
    @Published private(set) var alarmSaveState: AlarmSaveState

    private let engine: SmartWakeEngine
    private let alarmSchedulingService: any AlarmSchedulingService
    private var hasUserCustomizedBedtime = false
    private var hasUserCustomizedLatestWakeTime = false
    private var savedRecommendationID: String?

    init(
        initialBedtime: Date,
        initialLatestWakeTime: Date? = nil,
        initialMode: SmartWakeMode = .fromBedtime,
        initialWakeWindow: SmartWakeWindow = .twenty,
        engine: SmartWakeEngine? = nil,
        alarmSchedulingService: (any AlarmSchedulingService)? = nil
    ) {
        self.engine = engine ?? SmartWakeEngine()
        self.alarmSchedulingService = alarmSchedulingService ?? AlarmSchedulingServiceFactory.makeDefault()
        self.mode = initialMode
        self.bedtime = initialBedtime
        self.latestWakeTime = initialLatestWakeTime ?? self.engine.defaultLatestWakeTime(from: initialBedtime)
        self.wakeWindow = initialWakeWindow
        self.alternateRecommendations = []
        self.selectedRecommendationID = nil
        self.featuredRecommendation = nil
        self.inlineMessage = nil
        self.alarmSaveState = .idle
        self.hasUserCustomizedLatestWakeTime = initialLatestWakeTime != nil

        recompute()
    }

    var allRecommendations: [SmartWakeRecommendation] {
        [featuredRecommendation].compactMap { $0 } + alternateRecommendations
    }

    var selectedRecommendation: SmartWakeRecommendation? {
        guard let selectedRecommendationID else {
            return featuredRecommendation
        }

        return allRecommendations.first(where: { $0.id == selectedRecommendationID }) ?? featuredRecommendation
    }

    func setMode(_ newMode: SmartWakeMode) {
        guard newMode != mode else { return }
        mode = newMode
        recompute()
    }

    func setBedtime(_ newBedtime: Date) {
        bedtime = newBedtime
        hasUserCustomizedBedtime = true

        if !hasUserCustomizedLatestWakeTime {
            latestWakeTime = engine.defaultLatestWakeTime(from: newBedtime)
        }

        recompute()
    }

    func setLatestWakeTime(_ newLatestWakeTime: Date) {
        latestWakeTime = newLatestWakeTime
        hasUserCustomizedLatestWakeTime = true
        recompute()
    }

    func setWakeWindow(_ newWakeWindow: SmartWakeWindow) {
        guard newWakeWindow != wakeWindow else { return }
        wakeWindow = newWakeWindow
        recompute()
    }

    func selectRecommendation(_ recommendation: SmartWakeRecommendation) {
        selectedRecommendationID = recommendation.id
        synchronizeAlarmStateWithSelection()
    }

    func updateInferredBedtime(_ inferredBedtime: Date) {
        guard !hasUserCustomizedBedtime else { return }
        bedtime = inferredBedtime

        if !hasUserCustomizedLatestWakeTime {
            latestWakeTime = engine.defaultLatestWakeTime(from: inferredBedtime)
        }

        recompute()
    }

    func saveSelectedAlarm() async {
        guard let recommendation = selectedRecommendation else {
            alarmSaveState = .failed(message: "اختر وقت الاستيقاظ أولاً.")
            return
        }

        do {
            let authorizationStatus = await alarmSchedulingService.authorizationStatus()

            if authorizationStatus == .unsupported {
                alarmSaveState = .failed(message: "حفظ المنبه عبر AlarmKit غير متاح على هذا الجهاز حالياً.")
                return
            }

            if authorizationStatus == .notDetermined {
                alarmSaveState = .requestingPermission
            }

            let resolvedAuthorizationStatus = try await alarmSchedulingService.requestAuthorizationIfNeeded()
            guard resolvedAuthorizationStatus == .authorized else {
                savedRecommendationID = nil
                alarmSaveState = .denied(message: "تحتاج تسمح للتطبيق بإنشاء منبه. فعّل إذن المنبه حتى ينحفظ الوقت.")
                return
            }

            alarmSaveState = .saving

            _ = try await alarmSchedulingService.scheduleWakeAlarm(at: recommendation.wakeDate)
            savedRecommendationID = recommendation.id
            alarmSaveState = .saved
        } catch {
            savedRecommendationID = nil
            let message = (error as? LocalizedError)?.errorDescription ?? "تعذر حفظ المنبه حالياً."
            if let alarmError = error as? AlarmSchedulingError,
               alarmError == .permissionDenied {
                alarmSaveState = .denied(message: message)
            } else {
                alarmSaveState = .failed(message: message)
            }
        }
    }

    private func recompute() {
        let recommendations: [SmartWakeRecommendation]

        switch mode {
        case .fromBedtime:
            recommendations = engine.recommendations(fromBedtime: bedtime)
        case .fromWakeTime:
            recommendations = engine.recommendations(
                latestWakeTime: latestWakeTime,
                window: wakeWindow,
                referenceBedtime: bedtime
            )
        }

        guard let featured = recommendations.first else {
            featuredRecommendation = nil
            alternateRecommendations = []
            selectedRecommendationID = nil
            inlineMessage = "عدّل الوقت المطلوب لنولّد اقتراحات استيقاظ مناسبة."
            return
        }

        featuredRecommendation = featured
        alternateRecommendations = Array(recommendations.dropFirst().prefix(3))
        inlineMessage = nil

        let updatedRecommendationIDs = Set(([featured] + alternateRecommendations).map(\.id))
        if let selectedRecommendationID, updatedRecommendationIDs.contains(selectedRecommendationID) {
            return
        }

        if updatedRecommendationIDs.contains(featured.id) {
            selectedRecommendationID = featured.id
        }

        synchronizeAlarmStateWithSelection()
    }

    private func synchronizeAlarmStateWithSelection() {
        guard alarmSaveState.isBusy == false else { return }
        guard let savedRecommendationID else {
            alarmSaveState = .idle
            return
        }

        if selectedRecommendationID == savedRecommendationID {
            return
        }

        self.savedRecommendationID = nil
        alarmSaveState = .idle
    }
}
