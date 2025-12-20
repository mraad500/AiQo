import Foundation
import FamilyControls
import DeviceActivity
import ManagedSettings
internal import Combine

@MainActor
final class ProtectionModel: ObservableObject {

    // 👇 1. هذا هو السطر الجديد (المفتاح السحري)
    static let shared = ProtectionModel()

    @Published var selection = FamilyActivitySelection()
    @Published private(set) var isAuthorized: Bool = false

    private let center = DeviceActivityCenter()
    private let store = ManagedSettingsStore()

    var isEnabled: Bool {
        UserDefaults(suiteName: AppGroupKeys.appGroupID)?
            .bool(forKey: AppGroupKeys.isEnabled) ?? false
    }

    var canEnable: Bool {
        !selection.applicationTokens.isEmpty ||
        !selection.categoryTokens.isEmpty ||
        !selection.webDomainTokens.isEmpty
    }

    var selectionSummary: String {
        let apps = selection.applicationTokens.count
        let cats = selection.categoryTokens.count
        let web = selection.webDomainTokens.count
        return "Apps: \(apps) | Categories: \(cats) | Web: \(web)"
    }

    // خلينا الـ init متاح حتى اذا ردنا نستخدمه بغير مكان، بس الاعتماد الكلي حيصير على shared
    init() {
        refreshAuthorization()
    }

    func refreshAuthorization() {
        let status = AuthorizationCenter.shared.authorizationStatus
        isAuthorized = (status == .approved)
    }

    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            refreshAuthorization()
        } catch {
            refreshAuthorization()
        }
    }

    func enable() {
        guard isAuthorized else { return }
        saveSelectionToAppGroup()
        startMonitoringOneMinute()
        setEnabled(true)
    }

    func disable() {
        // فتح الكل فوراً
        store.clearAllSettings()
        center.stopMonitoring()
        setEnabled(false)

        // (اختياري) امسح السلكشن
        // clearSelectionFromAppGroup()
    }

    private func saveSelectionToAppGroup() {
        let defaults = UserDefaults(suiteName: AppGroupKeys.appGroupID)
        if let data = try? JSONEncoder().encode(selection) {
            defaults?.set(data, forKey: AppGroupKeys.savedSelection)
        }
    }

    private func setEnabled(_ value: Bool) {
        let defaults = UserDefaults(suiteName: AppGroupKeys.appGroupID)
        defaults?.set(value, forKey: AppGroupKeys.isEnabled)
        objectWillChange.send()
    }

    private func startMonitoringOneMinute() {
        // مهم: لا تقفل فوراً — القفل يتم بعد Threshold بالـ Monitor
        store.clearAllSettings()

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )

        let event = DeviceActivityEvent(
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            webDomains: selection.webDomainTokens,
            threshold: DateComponents(minute: 1)
        )

        do {
            center.stopMonitoring()
            try center.startMonitoring(
                .monitor,
                during: schedule,
                events: [.oneMinute: event]
            )
        } catch {
            // اذا صار خطأ، طفي الميزة
            setEnabled(false)
        }
    }
}
