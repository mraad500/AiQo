import WidgetKit

struct AiQoEntry: TimelineEntry {
    let date: Date

    let steps: Int
    let activeCalories: Int
    let standPercent: Int
    let stepsGoal: Int
    let caloriesGoal: Int
    let progress: Double

    let heartRate: Int
    let distanceKm: Double
}

extension AiQoEntry {
    static let placeholder = AiQoEntry(
        date: Date(),
        steps: 3157,
        activeCalories: 589,
        standPercent: 67,
        stepsGoal: 10000,
        caloriesGoal: 400,
        progress: 0.3157,
        heartRate: 106,
        distanceKm: 2.61
    )

    var safeProgress: Double {
        if progress.isNaN || progress.isInfinite { return 0 }
        return min(max(progress, 0), 1)
    }

    var safeStandProgress: Double {
        let normalized = Double(standPercent) / 100.0
        if normalized.isNaN || normalized.isInfinite { return 0 }
        return min(max(normalized, 0), 1)
    }

    var safeStepsProgress: Double {
        let goal = max(stepsGoal, 1)
        let normalized = Double(max(steps, 0)) / Double(goal)
        if normalized.isNaN || normalized.isInfinite { return 0 }
        return min(max(normalized, 0), 1)
    }

    var safeCaloriesProgress: Double {
        let goal = max(caloriesGoal, 1)
        let normalized = Double(max(activeCalories, 0)) / Double(goal)
        if normalized.isNaN || normalized.isInfinite { return 0 }
        return min(max(normalized, 0), 1)
    }

    var safeAuraProgress: Double {
        let normalized = (safeStepsProgress + safeCaloriesProgress) / 2
        if normalized.isNaN || normalized.isInfinite { return 0 }
        return min(max(normalized, 0), 1)
    }

    var auraPercentText: String {
        "\(Int((safeAuraProgress * 100).rounded()))%"
    }

    var standHoursText: String {
        let stoodHours = Int(round(safeStandProgress * 12.0))
        return "\(stoodHours)H"
    }
}
