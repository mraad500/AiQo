import Foundation

enum MetricKind {
    case steps, calories, stand, water, sleep, distance

    var title: String {
        switch self {
        case .steps:
            return NSLocalizedString("metric.steps.title",
                                     comment: "Steps card title")
        case .calories:
            return NSLocalizedString("metric.calories.title",
                                     comment: "Calories card title")
        case .stand:
            return NSLocalizedString("metric.stand.title",
                                     comment: "Stand card title")
        case .water:
            return NSLocalizedString("metric.water.title",
                                     comment: "Water card title")
        case .sleep:
            return NSLocalizedString("metric.sleep.title",
                                     comment: "Sleep card title")
        case .distance:
            return NSLocalizedString("metric.distance.title",
                                     comment: "Distance card title")
        }
    }
    var unit: String {
        switch self {
        case .steps: ""
        case .calories: "kcal"
        case .stand: "%"
        case .water: "L"
        case .sleep: "h"
        case .distance: "km"
        }
    }
    var icon: String {
        switch self {
        case .steps: "figure.walk"
        case .calories: "flame.fill"
        case .stand: "figure.stand"
        case .water: "drop.fill"
        case .sleep: "moon.fill"
        case .distance: "figure.run"
        }
    }
}
