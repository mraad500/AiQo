//
//  ScreenshotMode.swift
//  AiQo
//
//  DEBUG-only screenshot mode activated via Xcode launch arguments:
//    -aiqo-screenshot-mode YES
//    -aiqo-screenshot-scenario home_sleep_8_5
//
//  Provides deterministic mock data for App Store screenshots
//  without any HealthKit dependency, loading states, or permission prompts.
//

#if DEBUG

import Foundation

// MARK: - ScreenshotScenario

/// Each scenario defines the exact values shown on screen.
/// Add new cases here for future screenshot needs.
enum ScreenshotScenario: String {
    case home_sleep_8_5

    var demoConfig: DemoConfiguration {
        switch self {
        case .home_sleep_8_5:
            return DemoConfiguration(
                steps: "11,884",
                calories: "947",
                stand: "100",
                water: "3 L",
                sleep: "8.5",
                distance: "8.3"
            )
        }
    }

    var activitySnapshot: ActivitySnapshot {
        switch self {
        case .home_sleep_8_5:
            return ActivitySnapshot(steps: 11_884, calories: 947)
        }
    }
}

// MARK: - ScreenshotMode

enum ScreenshotMode {

    /// `true` when the app was launched with `-aiqo-screenshot-mode YES`.
    static let isActive: Bool = {
        UserDefaults.standard.bool(forKey: "aiqo-screenshot-mode")
    }()

    /// The resolved scenario, or `nil` when screenshot mode is off / scenario is unknown.
    static let scenario: ScreenshotScenario? = {
        guard isActive,
              let raw = UserDefaults.standard.string(forKey: "aiqo-screenshot-scenario") else {
            return nil
        }
        return ScreenshotScenario(rawValue: raw)
    }()
}

#endif
