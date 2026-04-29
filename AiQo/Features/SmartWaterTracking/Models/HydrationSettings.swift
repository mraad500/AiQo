import Foundation

struct HydrationSettings: Sendable, Equatable {
    var smartTrackingEnabled: Bool
    var goalML: Double
    var wakeStartHour: Int
    var wakeEndHour: Int
    var quietStartHour: Int
    var quietEndHour: Int
    var cooldownMinutes: Int

    /// Defaults reflect typical daytime user behavior:
    /// - wake window 08:00–22:00 aligns with the quiet-hours start so the
    ///   "expected intake" ramp reaches 100% by the time we stop reminding.
    /// - 14-hour reminder window keeps pace math intuitive (1 L by mid-window).
    /// - cooldown 25 min matches the recent-drink suppression rule.
    /// Existing users preserve whatever was persisted — `HydrationSettingsStore.load()`
    /// only consults defaults when a key has never been written.
    static let `default` = HydrationSettings(
        smartTrackingEnabled: true,
        goalML: 2500,
        wakeStartHour: 8,
        wakeEndHour: 22,
        quietStartHour: 22,
        quietEndHour: 7,
        cooldownMinutes: 25
    )

    /// Weight-based daily goal using the 30–35 mL/kg range (midpoint 32.5 mL/kg).
    /// Falls back to 2500 mL when no weight is available. Result is clamped
    /// to a sane range and rounded to the nearest 100 mL so the Stepper UI
    /// doesn't surface awkward numbers like "2123 mL".
    static func recommendedGoalML(forWeightKg weightKg: Int) -> Double {
        guard weightKg > 0 else { return Self.default.goalML }
        let raw = Double(weightKg) * 32.5
        let clamped = min(4000, max(1500, raw))
        return (clamped / 100).rounded() * 100
    }
}

enum HydrationSettingsStore {
    private enum Key {
        static let enabled = "aiqo.hydration.smart.enabled"
        static let goalML = "aiqo.hydration.goal.ml"
        static let wakeStart = "aiqo.hydration.wake.start"
        static let wakeEnd = "aiqo.hydration.wake.end"
        static let cooldown = "aiqo.hydration.cooldown.minutes"
    }

    /// True when the user (or a prior bootstrap) has committed a goal to disk.
    /// Used by HydrationService to decide whether to seed a weight-based goal on first launch.
    static func isGoalUserSet() -> Bool {
        UserDefaults.standard.object(forKey: Key.goalML) != nil
    }

    static func load() -> HydrationSettings {
        var settings = HydrationSettings.default
        let defaults = UserDefaults.standard

        if defaults.object(forKey: Key.enabled) != nil {
            settings.smartTrackingEnabled = defaults.bool(forKey: Key.enabled)
        }
        if defaults.object(forKey: Key.goalML) != nil {
            let stored = defaults.double(forKey: Key.goalML)
            if stored > 0 { settings.goalML = stored }
        }
        if defaults.object(forKey: Key.wakeStart) != nil {
            settings.wakeStartHour = defaults.integer(forKey: Key.wakeStart)
        }
        if defaults.object(forKey: Key.wakeEnd) != nil {
            settings.wakeEndHour = defaults.integer(forKey: Key.wakeEnd)
        }
        if defaults.object(forKey: Key.cooldown) != nil {
            settings.cooldownMinutes = defaults.integer(forKey: Key.cooldown)
        }
        return settings
    }

    static func save(_ settings: HydrationSettings) {
        let defaults = UserDefaults.standard
        defaults.set(settings.smartTrackingEnabled, forKey: Key.enabled)
        defaults.set(settings.goalML, forKey: Key.goalML)
        defaults.set(settings.wakeStartHour, forKey: Key.wakeStart)
        defaults.set(settings.wakeEndHour, forKey: Key.wakeEnd)
        defaults.set(settings.cooldownMinutes, forKey: Key.cooldown)
    }
}
