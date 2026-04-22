import Foundation
import WidgetKit

/// App-side half of the Hydration Widget contract.
///
/// IMPORTANT: the keys and widget kind here MUST match
/// `AiQoWidget/Hydration/HydrationWidgetShared.swift`. The duplication is
/// intentional: the widget extension is a separate target, and a shared
/// framework would be heavier than keeping a tiny 20-line constant file
/// on each side. If you change any value here, change it there too.
enum HydrationWidgetBridge {
    static let suiteName = "group.aiqo"
    static let widgetKind = "AiQoHydrationWidget"
    static let tapIncrementML: Int = 250

    enum Keys {
        static let consumedML = "aiqo_water_ml"
        static let goalML = "aiqo_water_goal_ml"
        static let lastUpdated = "aiqo_water_last_updated"
        static let tapCounter = "aiqo_water_tap_counter"
        static let tapCounterSeen = "aiqo_water_tap_counter_seen"
    }

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    /// Writes the current committed goal + consumed totals + language mirror,
    /// then reloads the widget. Call after every `refreshState`.
    static func publishSnapshot(
        consumedML: Int,
        goalML: Int,
        appLanguage: String
    ) {
        guard let defaults else { return }
        defaults.set(consumedML, forKey: Keys.consumedML)
        defaults.set(goalML, forKey: Keys.goalML)
        defaults.set(Date().timeIntervalSince1970, forKey: Keys.lastUpdated)
        // Mirror language so the widget can render ar/en without owning a
        // Localizable.strings bundle.
        defaults.set(appLanguage, forKey: "aiqo.app.language")
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
    }

    /// Returns the number of widget taps not yet drained into HealthKit.
    /// Capture this BEFORE writing any HK samples, then advance `seen` to
    /// this same value after the writes succeed.
    static func currentPendingTapCount() -> (counter: Int, seen: Int) {
        guard let defaults else { return (0, 0) }
        let counter = defaults.integer(forKey: Keys.tapCounter)
        let seen = defaults.integer(forKey: Keys.tapCounterSeen)
        return (counter, seen)
    }

    /// Advances `tapCounterSeen` to the counter value captured at drain start.
    /// Any taps that arrived between `currentPendingTapCount()` and this call
    /// stay unseen and will be drained on the next cycle.
    static func advanceTapCounterSeen(to value: Int) {
        guard let defaults else { return }
        defaults.set(value, forKey: Keys.tapCounterSeen)
    }
}
