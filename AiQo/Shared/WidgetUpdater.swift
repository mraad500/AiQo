import Foundation
import WidgetKit

enum WidgetUpdater {

    private static let suiteName = "group.aiqo"

    static func update(
        steps: Int,
        activeCalories: Int,
        stepsGoal: Int,
        standPercent: Int = 0,
        bpm: Int = 0,
        distanceKm: Double = 0
    ) {
        guard let shared = UserDefaults(suiteName: suiteName) else { return }

        shared.set(steps, forKey: "aiqo_steps")
        shared.set(activeCalories, forKey: "aiqo_active_cal")
        shared.set(stepsGoal, forKey: "aiqo_steps_goal")
        shared.set(standPercent, forKey: "aiqo_stand_percent")

        shared.set(bpm, forKey: "aiqo_bpm")
        shared.set(distanceKm, forKey: "aiqo_km")

        WidgetCenter.shared.reloadTimelines(ofKind: "AiQoWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "AiQoWatchFaceWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "AiQoRingsFaceWidget")
    }
}
