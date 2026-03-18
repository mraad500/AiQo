import Foundation
import FamilyControls
import DeviceActivity
import ManagedSettings
internal import Combine

@MainActor
final class ProtectionModel: ObservableObject {

    static let shared = ProtectionModel()

    @Published var selection = FamilyActivitySelection()
    @Published private(set) var isAuthorized: Bool = false

    private let center = DeviceActivityCenter()
    private let store = ManagedSettingsStore()
    
    // لتتبع حالة المؤقت
    private var unlockTimer: Timer?

    var isEnabled: Bool {
        if let value = AppGroupKeys.defaults()?.object(forKey: AppGroupKeys.isEnabled) as? Bool {
            return value
        }

        if let legacyValue = AppGroupKeys.legacyDefaults()?.object(forKey: AppGroupKeys.isEnabled) as? Bool {
            AppGroupKeys.defaults()?.set(legacyValue, forKey: AppGroupKeys.isEnabled)
            return legacyValue
        }

        return false
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
        // الغاء اي مؤقت سابق اذا كان موجود
        unlockTimer?.invalidate()
        
        saveSelectionToAppGroup()
        startMonitoringOneMinute()
        setEnabled(true)
    }

    func disable() {
        store.clearAllSettings()
        center.stopMonitoring()
        setEnabled(false)
        unlockTimer?.invalidate()
    }
    
    // MARK: - 🔓 الميزة الجديدة: الفتح المؤقت
    func unlockTemporarily(minutes: Int) {
        // 1. نوقف الحماية (نفتح التطبيقات)
        disable()
        
        print("🔓 AiQo: Unlocking for \(minutes) minutes...")
        
        // 2. نشغل مؤقت يرجع يقفلها بعد الوقت المحدد
        // ملاحظة: هذا المؤقت يشتغل والتطبيق بالخلفية لفترة قصيرة
        // لتطوير مستقبلي اقوى نستخدم Background Tasks
        unlockTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(minutes * 60), repeats: false) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                print("🔒 Time is up! Locking again.")
                self?.enable()
            }
        }
    }

    private func saveSelectionToAppGroup() {
        let defaults = AppGroupKeys.defaults()
        if let data = try? JSONEncoder().encode(selection) {
            defaults?.set(data, forKey: AppGroupKeys.savedSelection)
        }
    }

    private func setEnabled(_ value: Bool) {
        let defaults = AppGroupKeys.defaults()
        defaults?.set(value, forKey: AppGroupKeys.isEnabled)
        objectWillChange.send()
    }

    private func startMonitoringOneMinute() {
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
            setEnabled(false)
        }
    }
}
