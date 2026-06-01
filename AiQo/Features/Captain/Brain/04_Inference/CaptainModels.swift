import Foundation
import SwiftData

// MARK: - Persistent Chat Message (SwiftData)

/// نموذج SwiftData لحفظ رسائل المحادثة على القرص — يتحوّل من وإلى ChatMessage بدون ما يأثر على الـ UI
@Model
final class PersistentChatMessage {
    #Index<PersistentChatMessage>([\.sessionID], [\.timestamp])

    var messageID: UUID
    var text: String
    var isUser: Bool
    var timestamp: Date
    /// JSON-encoded SpotifyRecommendation — nil if absent
    var spotifyRecommendationData: Data?
    /// معرّف الجلسة — كل فتحة تطبيق تنشئ جلسة جديدة
    var sessionID: UUID = UUID()

    init(
        messageID: UUID,
        text: String,
        isUser: Bool,
        timestamp: Date,
        spotifyRecommendationData: Data? = nil,
        sessionID: UUID = UUID()
    ) {
        self.messageID = messageID
        self.text = text
        self.isUser = isUser
        self.timestamp = timestamp
        self.spotifyRecommendationData = spotifyRecommendationData
        self.sessionID = sessionID
    }

    /// تحويل من ChatMessage إلى PersistentChatMessage
    @MainActor
    convenience init(chatMessage msg: ChatMessage, sessionID: UUID) {
        let spotifyData: Data? = {
            guard let rec = msg.spotifyRecommendation else { return nil }
            return try? JSONEncoder().encode(rec)
        }()

        self.init(
            messageID: msg.id,
            text: msg.text,
            isUser: msg.isUser,
            timestamp: msg.timestamp,
            spotifyRecommendationData: spotifyData,
            sessionID: sessionID
        )
    }

    /// تحويل من PersistentChatMessage إلى ChatMessage خفيف للـ UI
    @MainActor
    func toChatMessage() -> ChatMessage {
        let spotify: SpotifyRecommendation? = {
            guard let data = spotifyRecommendationData else { return nil }
            return try? JSONDecoder().decode(SpotifyRecommendation.self, from: data)
        }()

        return ChatMessage(
            id: messageID,
            text: text,
            isUser: isUser,
            timestamp: timestamp,
            spotifyRecommendation: spotify
        )
    }
}

// MARK: - Chat Session (computed from PersistentChatMessage groups)

/// يمثّل جلسة محادثة واحدة — مشتق من تجميع الرسائل بنفس الـ sessionID
struct ChatSession: Identifiable, Sendable {
    let id: UUID
    let preview: String
    let timestamp: Date
    let messageCount: Int
}

// MARK: - Structured Response Models

struct CaptainStructuredResponse: Codable, Sendable {
    let message: String
    let quickReplies: [String]?
    let workoutPlan: WorkoutPlan?
    let mealPlan: MealPlan?
    let spotifyRecommendation: SpotifyRecommendation?
    /// Set ONLY when the user explicitly asked the Captain to remember/save
    /// something, or stated a durable fact worth pinning. Persisted to the
    /// "Saved Memories" section so the promise is actually kept.
    let savedMemory: CaptainSavedMemory?
    /// Set ONLY when the user asked for a reminder at a concrete clock time.
    /// Schedules a real local notification — never claim a reminder without it.
    let reminder: CaptainReminder?

    private enum CodingKeys: String, CodingKey {
        case message
        case quickReplies
        case workoutPlan
        case mealPlan
        case spotifyRecommendation
        case savedMemory
        case reminder
    }

    init(
        message: String,
        quickReplies: [String]? = nil,
        workoutPlan: WorkoutPlan? = nil,
        mealPlan: MealPlan? = nil,
        spotifyRecommendation: SpotifyRecommendation? = nil,
        savedMemory: CaptainSavedMemory? = nil,
        reminder: CaptainReminder? = nil
    ) {
        self.message = message.trimmingCharacters(in: .whitespacesAndNewlines)
        self.quickReplies = quickReplies?.prefix(3).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        self.workoutPlan = workoutPlan?.isMeaningful == true ? workoutPlan : nil
        self.mealPlan = mealPlan?.isMeaningful == true ? mealPlan : nil
        self.spotifyRecommendation = spotifyRecommendation?.isMeaningful == true ? spotifyRecommendation : nil
        self.savedMemory = savedMemory?.isMeaningful == true ? savedMemory : nil
        self.reminder = reminder?.isMeaningful == true ? reminder : nil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let rawMessage = try container.decode(String.self, forKey: .message)
        let normalizedMessage = rawMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedMessage.isEmpty else {
            throw DecodingError.dataCorruptedError(
                forKey: .message,
                in: container,
                debugDescription: "Captain response message must not be empty."
            )
        }

        message = normalizedMessage
        let rawReplies = try container.decodeIfPresent([String].self, forKey: .quickReplies)
        quickReplies = rawReplies?.prefix(3).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        workoutPlan = try container.decodeIfPresent(WorkoutPlan.self, forKey: .workoutPlan)
        let decodedMealPlan = try container.decodeIfPresent(MealPlan.self, forKey: .mealPlan)
        mealPlan = decodedMealPlan?.isMeaningful == true ? decodedMealPlan : nil
        let decodedSpotifyRecommendation = try container.decodeIfPresent(
            SpotifyRecommendation.self,
            forKey: .spotifyRecommendation
        )
        spotifyRecommendation = decodedSpotifyRecommendation?.isMeaningful == true ? decodedSpotifyRecommendation : nil
        let decodedSavedMemory = try container.decodeIfPresent(CaptainSavedMemory.self, forKey: .savedMemory)
        savedMemory = decodedSavedMemory?.isMeaningful == true ? decodedSavedMemory : nil
        let decodedReminder = try container.decodeIfPresent(CaptainReminder.self, forKey: .reminder)
        reminder = decodedReminder?.isMeaningful == true ? decodedReminder : nil
    }
}

// MARK: - Saved Memory (explicit "remember this")

/// Emitted when the user explicitly asks the Captain to remember/save something
/// ("احفظ هذا", "تذكر اني...", "remember that ..."), or when the user states a
/// durable fact the Captain decides is worth pinning. Persisted into the
/// "Saved Memories" section so the Captain never lies about having saved it.
nonisolated struct CaptainSavedMemory: Codable, Equatable, Sendable {
    /// The thing to remember, phrased as a durable fact in the user's language.
    let note: String
    /// Optional short label (≤ 40 chars) used as the row title in the UI.
    let title: String?

    private enum CodingKeys: String, CodingKey {
        case note
        case title
    }

    init(note: String, title: String? = nil) {
        self.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.title = (trimmedTitle?.isEmpty == false) ? trimmedTitle : nil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let rawNote = try container.decode(String.self, forKey: .note)
        let normalizedNote = rawNote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedNote.isEmpty else {
            throw DecodingError.dataCorruptedError(
                forKey: .note,
                in: container,
                debugDescription: "CaptainSavedMemory.note must not be empty."
            )
        }

        note = normalizedNote
        let rawTitle = try container.decodeIfPresent(String.self, forKey: .title)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        title = (rawTitle?.isEmpty == false) ? rawTitle : nil
    }

    var isMeaningful: Bool { !note.isEmpty }
}

// MARK: - Reminder (one-off, clock-time)

/// Emitted ONLY when the user asks for a reminder at a concrete clock time.
/// `time` is local 24h "HH:mm". `date` is an optional local "yyyy-MM-dd";
/// when omitted the scheduler uses today (or tomorrow if the time already
/// passed). The Captain must never promise a reminder without emitting this.
nonisolated struct CaptainReminder: Codable, Equatable, Sendable {
    /// What to remind the user about, in the user's language (spoken-style).
    let body: String
    /// Local 24h clock time "HH:mm" (e.g. "07:30", "21:00").
    let time: String
    /// Optional local date "yyyy-MM-dd". nil → next occurrence of `time`.
    let date: String?

    private enum CodingKeys: String, CodingKey {
        case body
        case time
        case date
    }

    init(body: String, time: String, date: String? = nil) {
        self.body = body.trimmingCharacters(in: .whitespacesAndNewlines)
        self.time = Self.normalizedTime(time)
        let trimmedDate = date?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.date = (trimmedDate?.isEmpty == false) ? trimmedDate : nil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let rawBody = try container.decode(String.self, forKey: .body)
        let normalizedBody = rawBody.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedBody.isEmpty else {
            throw DecodingError.dataCorruptedError(
                forKey: .body,
                in: container,
                debugDescription: "CaptainReminder.body must not be empty."
            )
        }

        let rawTime = try container.decode(String.self, forKey: .time)
        let normalizedTime = Self.normalizedTime(rawTime)
        guard Self.isValidTime(normalizedTime) else {
            throw DecodingError.dataCorruptedError(
                forKey: .time,
                in: container,
                debugDescription: "CaptainReminder.time must be 24h HH:mm."
            )
        }

        body = normalizedBody
        time = normalizedTime
        let rawDate = try container.decodeIfPresent(String.self, forKey: .date)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        date = (rawDate?.isEmpty == false) ? rawDate : nil
    }

    var isMeaningful: Bool { !body.isEmpty && Self.isValidTime(time) }

    /// Hour/minute parsed from `time`, or nil if malformed.
    var clock: (hour: Int, minute: Int)? {
        let parts = time.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]), let minute = Int(parts[1]),
              (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        return (hour, minute)
    }

    /// Normalizes "7:5" → "07:05", strips stray spaces, keeps only HH:mm.
    static func normalizedTime(_ raw: String) -> String {
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = cleaned.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0].trimmingCharacters(in: .whitespaces)),
              let minute = Int(parts[1].trimmingCharacters(in: .whitespaces)) else {
            return cleaned
        }
        return String(format: "%02d:%02d", hour, minute)
    }

    static func isValidTime(_ value: String) -> Bool {
        let parts = value.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]), let minute = Int(parts[1]) else { return false }
        return (0...23).contains(hour) && (0...59).contains(minute)
    }
}

nonisolated struct SpotifyRecommendation: Codable, Equatable, Sendable {
    let vibeName: String
    let description: String
    let spotifyURI: String

    private enum CodingKeys: String, CodingKey {
        case vibeName
        case description
        case spotifyURI
    }

    init(
        vibeName: String,
        description: String,
        spotifyURI: String
    ) {
        self.vibeName = vibeName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.description = description.trimmingCharacters(in: .whitespacesAndNewlines)
        self.spotifyURI = spotifyURI.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let rawVibeName = try container.decode(String.self, forKey: .vibeName)
        let normalizedVibeName = rawVibeName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedVibeName.isEmpty else {
            throw DecodingError.dataCorruptedError(
                forKey: .vibeName,
                in: container,
                debugDescription: "SpotifyRecommendation.vibeName must not be empty."
            )
        }

        let rawDescription = try container.decode(String.self, forKey: .description)
        let normalizedDescription = rawDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedDescription.isEmpty else {
            throw DecodingError.dataCorruptedError(
                forKey: .description,
                in: container,
                debugDescription: "SpotifyRecommendation.description must not be empty."
            )
        }

        let rawSpotifyURI = try container.decode(String.self, forKey: .spotifyURI)
        let normalizedSpotifyURI = rawSpotifyURI.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedSpotifyURI.isEmpty else {
            throw DecodingError.dataCorruptedError(
                forKey: .spotifyURI,
                in: container,
                debugDescription: "SpotifyRecommendation.spotifyURI must not be empty."
            )
        }

        vibeName = normalizedVibeName
        description = normalizedDescription
        spotifyURI = normalizedSpotifyURI
    }

    var isMeaningful: Bool {
        !vibeName.isEmpty && !description.isEmpty && !spotifyURI.isEmpty
    }
}

extension SpotifyRecommendation {
    static func myVibeFallback(
        for userMessage: String,
        currentVibe: String = "",
        language: AppLanguage
    ) -> SpotifyRecommendation {
        let normalizedSignal = normalizedSignal(from: [userMessage, currentVibe])

        if containsAny(normalizedSignal, keywords: [
            "energy", "boost", "pump", "hype", "gym", "workout", "run",
            "طاقه", "طاقة", "حماس", "نشاط", "تمرين", "رياضه", "رياضة"
        ]) {
            return recommendation(
                vibeNameArabic: "Energy Lift",
                vibeNameEnglish: "Energy Lift",
                descriptionArabic: "مسار يرفع الطاقة شوي شوي بدون فوضى، حتى تدخل المود بسرعة وتبقى حاضر.",
                descriptionEnglish: "A clean energy ramp that wakes the system up without turning the room noisy.",
                spotifyURI: "spotify:playlist:37i9dQZF1DX76Wlfdnj7AP",
                language: language
            )
        }

        if containsAny(normalizedSignal, keywords: [
            "focus", "deep work", "study", "work", "clarity", "concentrate",
            "تركيز", "دراسه", "دراسة", "شغل", "وضوح"
        ]) {
            return recommendation(
                vibeNameArabic: "Deep Focus",
                vibeNameEnglish: "Deep Focus",
                descriptionArabic: "تركيز ناعم وثابت يقلل التشويش ويحافظ على صفاء الخط الواحد.",
                descriptionEnglish: "A stable focus lane built to cut noise and hold a clean line of concentration.",
                spotifyURI: "spotify:playlist:37i9dQZF1DWZeKCadgRdKQ",
                language: language
            )
        }

        return recommendation(
            vibeNameArabic: "Zen Mode",
            vibeNameEnglish: "Zen Mode",
            descriptionArabic: "فايب هادئ يخفف التحفيز ويرجع النفس لإيقاع أهدأ مع حضور أنظف.",
            descriptionEnglish: "A low-stimulus grounding mix that softens the system and settles the room.",
            spotifyURI: "spotify:playlist:37i9dQZF1DWZqd5JICZI0u",
            language: language
        )
    }
}

private extension SpotifyRecommendation {
    static func recommendation(
        vibeNameArabic: String,
        vibeNameEnglish: String,
        descriptionArabic: String,
        descriptionEnglish: String,
        spotifyURI: String,
        language: AppLanguage
    ) -> SpotifyRecommendation {
        SpotifyRecommendation(
            vibeName: language == .arabic ? vibeNameArabic : vibeNameEnglish,
            description: language == .arabic ? descriptionArabic : descriptionEnglish,
            spotifyURI: spotifyURI
        )
    }

    static func normalizedSignal(from values: [String]) -> String {
        values
            .joined(separator: " ")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: "أ", with: "ا")
            .replacingOccurrences(of: "إ", with: "ا")
            .replacingOccurrences(of: "آ", with: "ا")
            .replacingOccurrences(of: "ة", with: "ه")
            .replacingOccurrences(of: "ـ", with: "")
    }

    static func containsAny(_ text: String, keywords: [String]) -> Bool {
        keywords.contains { keyword in
            text.contains(
                keyword.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            )
        }
    }
}

struct MealPlan: Codable, Equatable, Sendable {
    let meals: [Meal]

    private enum CodingKeys: String, CodingKey {
        case meals
    }

    init(meals: [Meal]) {
        self.meals = meals
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedMeals = try container.decode([Meal].self, forKey: .meals)

        guard !decodedMeals.isEmpty else {
            throw DecodingError.dataCorruptedError(
                forKey: .meals,
                in: container,
                debugDescription: "MealPlan.meals must contain at least one meal."
            )
        }

        meals = decodedMeals
    }

    var isMeaningful: Bool {
        !meals.isEmpty
    }

    struct Meal: Codable, Equatable, Identifiable, Sendable {
        var id = UUID()
        let type: String
        let description: String
        let calories: Int

        private enum CodingKeys: String, CodingKey {
            case type
            case description
            case calories
        }

        init(
            id: UUID = UUID(),
            type: String,
            description: String,
            calories: Int
        ) {
            self.id = id
            self.type = type.trimmingCharacters(in: .whitespacesAndNewlines)
            self.description = description.trimmingCharacters(in: .whitespacesAndNewlines)
            self.calories = calories
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            let rawType = try container.decode(String.self, forKey: .type)
            let normalizedType = rawType.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedType.isEmpty else {
                throw DecodingError.dataCorruptedError(
                    forKey: .type,
                    in: container,
                    debugDescription: "Meal.type must not be empty."
                )
            }

            let rawDescription = try container.decode(String.self, forKey: .description)
            let normalizedDescription = rawDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedDescription.isEmpty else {
                throw DecodingError.dataCorruptedError(
                    forKey: .description,
                    in: container,
                    debugDescription: "Meal.description must not be empty."
                )
            }

            let decodedCalories = try container.decode(Int.self, forKey: .calories)
            guard decodedCalories > 0 else {
                throw DecodingError.dataCorruptedError(
                    forKey: .calories,
                    in: container,
                    debugDescription: "Meal.calories must be greater than zero."
                )
            }

            id = UUID()
            type = normalizedType
            description = normalizedDescription
            calories = decodedCalories
        }
    }
}

struct WorkoutPlan: Codable, Equatable, Sendable {
    let title: String
    let exercises: [Exercise]
    let days: [WorkoutDay]?
    let durationWeeks: Int?

    private enum CodingKeys: String, CodingKey {
        case title
        case exercises
        case days
        case durationWeeks
    }

    init(
        title: String,
        exercises: [Exercise],
        days: [WorkoutDay]? = nil,
        durationWeeks: Int? = nil
    ) {
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.exercises = exercises
        self.days = days?.isEmpty == false ? days : nil
        self.durationWeeks = durationWeeks.flatMap { $0 > 0 ? $0 : nil }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let rawTitle = try container.decode(String.self, forKey: .title)
        let normalizedTitle = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTitle.isEmpty else {
            throw DecodingError.dataCorruptedError(
                forKey: .title,
                in: container,
                debugDescription: "WorkoutPlan.title must not be empty."
            )
        }

        let decodedDays = try container.decodeIfPresent([WorkoutDay].self, forKey: .days)
        let decodedExercises = try container.decodeIfPresent([Exercise].self, forKey: .exercises)
        let decodedDurationWeeks = try container.decodeIfPresent(Int.self, forKey: .durationWeeks)

        let resolvedDays: [WorkoutDay]? = (decodedDays?.isEmpty == false) ? decodedDays : nil
        let resolvedExercises: [Exercise]
        if let flat = decodedExercises, !flat.isEmpty {
            resolvedExercises = flat
        } else if let days = resolvedDays {
            resolvedExercises = days.flatMap { $0.exercises }
        } else {
            resolvedExercises = []
        }

        guard !resolvedExercises.isEmpty else {
            throw DecodingError.dataCorruptedError(
                forKey: .exercises,
                in: container,
                debugDescription: "WorkoutPlan must contain at least one exercise (flat or via days)."
            )
        }

        title = normalizedTitle
        exercises = resolvedExercises
        days = resolvedDays
        durationWeeks = decodedDurationWeeks.flatMap { $0 > 0 ? $0 : nil }
    }

    var isMeaningful: Bool {
        !title.isEmpty && !exercises.isEmpty
    }
}

struct WorkoutDay: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    let name: String
    let focus: String?
    let exercises: [Exercise]

    private enum CodingKeys: String, CodingKey {
        case name
        case focus
        case exercises
    }

    init(id: UUID = UUID(), name: String, focus: String?, exercises: [Exercise]) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.focus = focus?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmptyOrNil
        self.exercises = exercises
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let rawName = try container.decode(String.self, forKey: .name)
        let normalizedName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty else {
            throw DecodingError.dataCorruptedError(
                forKey: .name,
                in: container,
                debugDescription: "WorkoutDay.name must not be empty."
            )
        }

        let rawFocus = try container.decodeIfPresent(String.self, forKey: .focus)
        let decodedExercises = try container.decode([Exercise].self, forKey: .exercises)
        guard !decodedExercises.isEmpty else {
            throw DecodingError.dataCorruptedError(
                forKey: .exercises,
                in: container,
                debugDescription: "WorkoutDay.exercises must contain at least one exercise."
            )
        }

        id = UUID()
        name = normalizedName
        focus = rawFocus?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmptyOrNil
        exercises = decodedExercises
    }
}

private extension String {
    var nonEmptyOrNil: String? { isEmpty ? nil : self }
}

struct Exercise: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    let name: String
    let sets: Int
    let repsOrDuration: String

    private enum CodingKeys: String, CodingKey {
        case name
        case sets
        case repsOrDuration
    }

    init(
        id: UUID = UUID(),
        name: String,
        sets: Int,
        repsOrDuration: String
    ) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.sets = sets
        self.repsOrDuration = repsOrDuration.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let rawName = try container.decode(String.self, forKey: .name)
        let normalizedName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty else {
            throw DecodingError.dataCorruptedError(
                forKey: .name,
                in: container,
                debugDescription: "Exercise.name must not be empty."
            )
        }

        let decodedSets = try container.decode(Int.self, forKey: .sets)
        guard decodedSets > 0 else {
            throw DecodingError.dataCorruptedError(
                forKey: .sets,
                in: container,
                debugDescription: "Exercise.sets must be greater than zero."
            )
        }

        let rawRepsOrDuration = try container.decode(String.self, forKey: .repsOrDuration)
        let normalizedRepsOrDuration = rawRepsOrDuration.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedRepsOrDuration.isEmpty else {
            throw DecodingError.dataCorruptedError(
                forKey: .repsOrDuration,
                in: container,
                debugDescription: "Exercise.repsOrDuration must not be empty."
            )
        }

        id = UUID()
        name = normalizedName
        sets = decodedSets
        repsOrDuration = normalizedRepsOrDuration
    }
}
