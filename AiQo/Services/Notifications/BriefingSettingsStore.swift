import Foundation
import SwiftData

// MARK: - Briefing Settings (SwiftData)

@Model
final class BriefingSettings {
    var morningHeroEnabled: Bool = true
    var middayPulseEnabled: Bool = true
    var eveningReflectionEnabled: Bool = true
    var windDownEnabled: Bool = true
    var workoutSummaryEnabled: Bool = true
    var lastMorningFireDate: Date?
    var lastAppOpenDate: Date?

    init() {}
}

// MARK: - Briefing Settings Store

@MainActor
final class BriefingSettingsStore {
    static let shared = BriefingSettingsStore()

    private let defaults = UserDefaults.standard

    // UserDefaults keys (SwiftData is too heavy for simple toggles that need sync read)
    private enum Keys {
        static let morningHeroEnabled = "aiqo.briefing.morningHeroEnabled"
        static let middayPulseEnabled = "aiqo.briefing.middayPulseEnabled"
        static let eveningReflectionEnabled = "aiqo.briefing.eveningReflectionEnabled"
        static let windDownEnabled = "aiqo.briefing.windDownEnabled"
        static let workoutSummaryEnabled = "aiqo.briefing.workoutSummaryEnabled"
        static let lastMorningFireDate = "aiqo.briefing.lastMorningFireDate"
        static let lastAppOpenDate = "aiqo.briefing.lastAppOpenDate"
    }

    private init() {
        // Set defaults on first launch
        if defaults.object(forKey: Keys.morningHeroEnabled) == nil {
            defaults.set(true, forKey: Keys.morningHeroEnabled)
            defaults.set(true, forKey: Keys.middayPulseEnabled)
            defaults.set(true, forKey: Keys.eveningReflectionEnabled)
            defaults.set(true, forKey: Keys.windDownEnabled)
            defaults.set(true, forKey: Keys.workoutSummaryEnabled)
        }
    }

    // MARK: - Read-only aggregated settings

    var settings: BriefingSettingsSnapshot {
        BriefingSettingsSnapshot(
            morningHeroEnabled: defaults.bool(forKey: Keys.morningHeroEnabled),
            middayPulseEnabled: defaults.bool(forKey: Keys.middayPulseEnabled),
            eveningReflectionEnabled: defaults.bool(forKey: Keys.eveningReflectionEnabled),
            windDownEnabled: defaults.bool(forKey: Keys.windDownEnabled),
            workoutSummaryEnabled: defaults.bool(forKey: Keys.workoutSummaryEnabled),
            lastMorningFireDate: defaults.object(forKey: Keys.lastMorningFireDate) as? Date,
            lastAppOpenDate: defaults.object(forKey: Keys.lastAppOpenDate) as? Date
        )
    }

    // MARK: - Toggles

    func setEnabled(_ enabled: Bool, for slot: BriefingSlot) {
        switch slot {
        case .morningHero:       defaults.set(enabled, forKey: Keys.morningHeroEnabled)
        case .middayPulse:       defaults.set(enabled, forKey: Keys.middayPulseEnabled)
        case .eveningReflection: defaults.set(enabled, forKey: Keys.eveningReflectionEnabled)
        case .windDown:          defaults.set(enabled, forKey: Keys.windDownEnabled)
        case .workoutSummary:    defaults.set(enabled, forKey: Keys.workoutSummaryEnabled)
        }
    }

    func isEnabled(_ slot: BriefingSlot) -> Bool {
        switch slot {
        case .morningHero:       return defaults.bool(forKey: Keys.morningHeroEnabled)
        case .middayPulse:       return defaults.bool(forKey: Keys.middayPulseEnabled)
        case .eveningReflection: return defaults.bool(forKey: Keys.eveningReflectionEnabled)
        case .windDown:          return defaults.bool(forKey: Keys.windDownEnabled)
        case .workoutSummary:    return defaults.bool(forKey: Keys.workoutSummaryEnabled)
        }
    }

    // MARK: - Timestamps

    func recordMorningFire() {
        defaults.set(Date(), forKey: Keys.lastMorningFireDate)
    }

    func recordAppOpen() {
        defaults.set(Date(), forKey: Keys.lastAppOpenDate)
    }
}

// MARK: - Settings Snapshot

struct BriefingSettingsSnapshot {
    let morningHeroEnabled: Bool
    let middayPulseEnabled: Bool
    let eveningReflectionEnabled: Bool
    let windDownEnabled: Bool
    let workoutSummaryEnabled: Bool
    let lastMorningFireDate: Date?
    let lastAppOpenDate: Date?
}
