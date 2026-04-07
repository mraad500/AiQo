import Foundation

// MARK: - Circadian Bio-Time Phase

/// المرحلة البيولوجية الحالية — تدمج الساعة + النوم + النشاط لتحديد حالة الطاقة الحقيقية
enum BioTimePhase: String, Sendable {
    /// 5:00–9:59 — الجسم يصحى، الكورتيزول يرتفع
    case awakening
    /// 10:00–13:59 — ذروة الطاقة والتركيز
    case energy
    /// 14:00–17:59 — التركيز العميق، الإنتاج المستمر
    case focus
    /// 18:00–20:59 — الجسم يبدأ ينزل، استشفاء نشط
    case recovery
    /// 21:00–4:59 — الجهاز العصبي يهدأ، وقت الصمت الداخلي
    case zen

    /// حساب المرحلة من الساعة + جودة النوم + مستوى النشاط
    static func current(
        hour: Int,
        sleepHours: Double,
        steps: Int
    ) -> BioTimePhase {
        let sleepDeprived = sleepHours > 0 && sleepHours < 5.5

        // نوم ضعيف + صبح مبكر = الجسم بعده بمرحلة zen مو awakening
        if sleepDeprived && (5..<10).contains(hour) {
            return .recovery
        }

        // نشاط عالي بالليل = الجسم بعده بـ energy مو zen
        if hour >= 21 && steps > 8_000 {
            return .recovery
        }

        switch hour {
        case 5..<10:  return .awakening
        case 10..<14: return .energy
        case 14..<18: return .focus
        case 18..<21: return .recovery
        default:      return .zen
        }
    }

    /// تعليمات اللهجة للـ LLM — سطر واحد فقط
    var toneDirective: String {
        switch self {
        case .awakening:
            return "Tone: gentle, clear, optimistic. The user just woke up — ease them in, don't overwhelm."
        case .energy:
            return "Tone: sharp, direct, high-output. Peak biological energy — match their drive."
        case .focus:
            return "Tone: steady, precise, minimal. Deep work hours — be efficient, don't break flow."
        case .recovery:
            return "Tone: warm, calm, encouraging. The body is winding down — be supportive, not pushy."
        case .zen:
            return "Tone: soft, philosophical, minimal. Late night — speak gently, encourage rest and reflection."
        }
    }

    /// التعليمات بالعربي العراقي للـ system prompt
    var toneDirectiveArabic: String {
        switch self {
        case .awakening:
            return "النبرة: هادئة وواضحة. المستخدم لسه صاحي — خفف عليه، لا تثقل."
        case .energy:
            return "النبرة: حادة ومباشرة. ذروة الطاقة — جاريه بنفس السرعة."
        case .focus:
            return "النبرة: ثابتة ودقيقة. ساعات التركيز — كن مختصر ولا تقطع التدفق."
        case .recovery:
            return "النبرة: دافئة وهادئة. الجسم يرتاح — ادعمه بدون ضغط."
        case .zen:
            return "النبرة: ناعمة وتأملية. وقت متأخر — تكلم بهدوء وشجّع الراحة."
        }
    }
}

// MARK: - Context Data

struct CaptainContextData: Sendable {
    let steps: Int
    let calories: Int
    let vibe: String
    let level: Int

    // Bio-state enrichment
    let sleepHours: Double
    let heartRate: Int?
    let timeOfDay: String
    let toneHint: String
    let stageTitle: String
    let bioPhase: BioTimePhase

    init(
        steps: Int,
        calories: Int,
        vibe: String,
        level: Int,
        sleepHours: Double = 0,
        heartRate: Int? = nil,
        timeOfDay: String = "",
        toneHint: String = "",
        stageTitle: String = "",
        bioPhase: BioTimePhase = .energy
    ) {
        self.steps = steps
        self.calories = calories
        self.vibe = vibe
        self.level = level
        self.sleepHours = sleepHours
        self.heartRate = heartRate
        self.timeOfDay = timeOfDay
        self.toneHint = toneHint
        self.stageTitle = stageTitle
        self.bioPhase = bioPhase
    }
}

struct CaptainSystemContextSnapshot: Sendable {
    let systemPrefix: String
    let level: Int
    let stageNumber: Int
    let stageTitle: String
    let timeOfDay: String
    let vibeTitle: String
    let toneHint: String
    let steps: Int
    let sleepHours: Double
    let calories: Int
    let heartRate: Int?
    let hrvSDNN: Double?
    let restingHeartRate: Int?
    let waterIntakeML: Double?
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
        let level = max(levelStore.level, 1)
        let stage = stageDescriptor(for: level)
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
            prefix += ", HR: \(heartRate)bpm"
        }
        if let hrv = metrics.hrvSDNN {
            prefix += ", HRV: \(String(format: "%.0f", hrv))ms"
        }
        if let restingHR = metrics.restingHeartRate {
            prefix += ", RestHR: \(restingHR)bpm"
        }
        if let water = metrics.waterIntakeML {
            prefix += ", Water: \(String(format: "%.0f", water))mL"
        }
        prefix += ". Adjust your tone to be \(toneHint).]"

        return CaptainSystemContextSnapshot(
            systemPrefix: prefix,
            level: level,
            stageNumber: stage.number,
            stageTitle: stage.title,
            timeOfDay: dayPart.title,
            vibeTitle: vibeTitle,
            toneHint: toneHint,
            steps: max(0, metrics.stepCount),
            sleepHours: max(0, metrics.sleepHours),
            calories: max(0, metrics.activeEnergyKilocalories),
            heartRate: metrics.averageOrCurrentHeartRateBPM,
            hrvSDNN: metrics.hrvSDNN,
            restingHeartRate: metrics.restingHeartRate,
            waterIntakeML: metrics.waterIntakeML
        )
    }

    func buildContextData() async -> CaptainContextData {
        let snapshot = await buildSystemContext()
        let hour = calendar.component(.hour, from: Date())
        let bioPhase = BioTimePhase.current(
            hour: hour,
            sleepHours: snapshot.sleepHours,
            steps: snapshot.steps
        )

        return CaptainContextData(
            steps: snapshot.steps,
            calories: snapshot.calories,
            vibe: snapshot.vibeTitle,
            level: snapshot.level,
            sleepHours: snapshot.sleepHours,
            heartRate: snapshot.heartRate,
            timeOfDay: snapshot.timeOfDay,
            toneHint: snapshot.toneHint,
            stageTitle: snapshot.stageTitle,
            bioPhase: bioPhase
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
                sleepHours: 0,
                hrvSDNN: nil,
                restingHeartRate: nil,
                waterIntakeML: nil
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
