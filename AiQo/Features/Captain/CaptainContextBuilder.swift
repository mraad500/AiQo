import Foundation

struct CaptainSystemContextSnapshot: Sendable {
    let systemPrefix: String
    let stageNumber: Int
    let stageTitle: String
    let timeOfDay: String
    let vibeTitle: String
    let toneHint: String
    let steps: Int
    let sleepHours: Double
    let calories: Int
    let heartRate: Int?
}

@MainActor
final class CaptainContextBuilder {
    static let shared = CaptainContextBuilder()

    private let intelligenceManager: CaptainIntelligenceManager
    private let levelStore: LevelStore
    private let vibeAudioEngine: VibeAudioEngine
    private let spotifyVibeManager: SpotifyVibeManager
    private let calendar: Calendar

    init(
        intelligenceManager: CaptainIntelligenceManager? = nil,
        levelStore: LevelStore? = nil,
        vibeAudioEngine: VibeAudioEngine? = nil,
        spotifyVibeManager: SpotifyVibeManager? = nil,
        calendar: Calendar = .current
    ) {
        self.intelligenceManager = intelligenceManager ?? .shared
        self.levelStore = levelStore ?? .shared
        self.vibeAudioEngine = vibeAudioEngine ?? .shared
        self.spotifyVibeManager = spotifyVibeManager ?? .shared
        self.calendar = calendar
    }

    func buildSystemContext() async -> CaptainSystemContextSnapshot {
        let metrics = await loadMetrics()
        let stage = stageDescriptor(for: levelStore.level)
        let dayPart = VibeDayPart.current(for: Date(), calendar: calendar)
        let vibeTitle = currentVibeTitle(for: dayPart)
        let toneHint = toneHint(
            stageNumber: stage.number,
            dayPart: dayPart,
            vibeTitle: vibeTitle,
            metrics: metrics
        )

        var prefix = "[SYSTEM CONTEXT: Stage \(stage.number): \(stage.title), Time: \(dayPart.title), Vibe: \(vibeTitle), Steps: \(metrics.stepCount), Sleep: \(String(format: "%.1f", metrics.sleepHours))h, Calories: \(metrics.activeEnergyKilocalories)"
        if let heartRate = metrics.averageOrCurrentHeartRateBPM {
            prefix += ", Heart Rate: \(heartRate)"
        }
        prefix += ". Adjust your tone to be \(toneHint).]"

        return CaptainSystemContextSnapshot(
            systemPrefix: prefix,
            stageNumber: stage.number,
            stageTitle: stage.title,
            timeOfDay: dayPart.title,
            vibeTitle: vibeTitle,
            toneHint: toneHint,
            steps: max(0, metrics.stepCount),
            sleepHours: max(0, metrics.sleepHours),
            calories: max(0, metrics.activeEnergyKilocalories),
            heartRate: metrics.averageOrCurrentHeartRateBPM
        )
    }

    private func loadMetrics() async -> CaptainDailyHealthMetrics {
        do {
            return try await intelligenceManager.fetchTodayEssentialMetrics()
        } catch {
            return CaptainDailyHealthMetrics(
                stepCount: 0,
                activeEnergyKilocalories: 0,
                averageOrCurrentHeartRateBPM: nil,
                sleepHours: 0
            )
        }
    }

    private func currentVibeTitle(for dayPart: VibeDayPart) -> String {
        if let spotifyTitle = spotifyVibeManager.currentVibeTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
           !spotifyTitle.isEmpty {
            return normalizeVibeTitle(spotifyTitle)
        }

        if let activeMode = vibeAudioEngine.currentState.currentMode {
            return normalizeVibeTitle(activeMode.rawValue)
        }

        return normalizeVibeTitle(vibeAudioEngine.currentProfile.mode(for: dayPart).rawValue)
    }

    private func normalizeVibeTitle(_ title: String) -> String {
        if title.contains("Ego-Death") {
            return "Ego-Death"
        }

        return title
            .replacingOccurrences(of: "(Zen)", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func stageDescriptor(for level: Int) -> (number: Int, title: String) {
        let stageNumber = max(1, min(10, ((max(level, 1) - 1) / 5) + 1))
        let titles: [Int: String] = [
            1: "Foundation Awakening",
            2: "Discipline Ritual",
            3: "Comfort Zone Break",
            4: "Momentum Forge",
            5: "Identity Shift",
            6: "Resilience Engine",
            7: "Peak Focus",
            8: "Command Presence",
            9: "Legend Protocol",
            10: "Transcendence Mode"
        ]

        return (stageNumber, titles[stageNumber] ?? "Comfort Zone Break")
    }

    private func toneHint(
        stageNumber: Int,
        dayPart: VibeDayPart,
        vibeTitle: String,
        metrics: CaptainDailyHealthMetrics
    ) -> String {
        let normalizedVibe = vibeTitle.lowercased()

        if normalizedVibe.contains("ego-death") || dayPart == .night {
            return "deep and calm"
        }

        if normalizedVibe.contains("recovery") || metrics.sleepHours < 5.5 {
            return "gentle and restorative"
        }

        if normalizedVibe.contains("awakening") || dayPart == .morning {
            return "clear and uplifting"
        }

        if metrics.stepCount < 1800 {
            return "grounding and patient"
        }

        if stageNumber >= 7 {
            return "precise and commanding"
        }

        return "focused and supportive"
    }
}
