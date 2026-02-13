//
//  CaptainServices.swift
//  AiQo
//

import Foundation
internal import Combine
import UserNotifications
import HealthKit

// MARK: - API Models

struct CaptainResponse: Decodable {
    let ok: Bool?
    let message: String?
    let conversationId: String?
    let memoryUpdate: JSONValue?

    // Convenience
    var replyText: String { message ?? "" }
}

private enum CaptainResponseParser {
    private static let messageKeys = ["message", "reply", "text", "output", "answer", "content"]
    private static let conversationKeys = ["conversationId", "conversation_id", "threadId", "sessionId"]
    private static let okKeys = ["ok", "success"]

    static func parse(data: Data) -> CaptainResponse? {
        guard let object = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }

        if let dict = object as? [String: Any] {
            return parse(dict: dict)
        }

        if let array = object as? [Any] {
            for item in array {
                if let dict = item as? [String: Any], let parsed = parse(dict: dict) {
                    return parsed
                }
            }
        }

        return nil
    }

    static func parseErrorSummary(data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }
        guard let dict = object as? [String: Any] else {
            return nil
        }

        if let errorText = stringValue(for: ["error", "message", "detail", "reason"], in: dict),
           !errorText.isEmpty {
            return errorText
        }

        if let nested = dict["response"] as? [String: Any],
           let nestedError = stringValue(for: ["error", "message", "detail", "reason"], in: nested),
           !nestedError.isEmpty {
            return nestedError
        }

        return nil
    }

    private static func parse(dict: [String: Any]) -> CaptainResponse? {
        let message = firstString(in: dict, keys: messageKeys)
        let conversationId = firstString(in: dict, keys: conversationKeys)
        let ok = firstBool(in: dict, keys: okKeys)

        if message != nil || conversationId != nil || ok != nil {
            return CaptainResponse(ok: ok, message: message, conversationId: conversationId, memoryUpdate: nil)
        }

        for value in dict.values {
            if let nested = value as? [String: Any], let parsed = parse(dict: nested) {
                return parsed
            }
            if let nestedArray = value as? [Any] {
                for item in nestedArray {
                    if let nestedDict = item as? [String: Any], let parsed = parse(dict: nestedDict) {
                        return parsed
                    }
                }
            }
        }

        return nil
    }

    private static func firstString(in dict: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let direct = dict[key] as? String {
                let trimmed = direct.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
        }
        return nil
    }

    private static func firstBool(in dict: [String: Any], keys: [String]) -> Bool? {
        for key in keys {
            if let value = dict[key] as? Bool {
                return value
            }
            if let value = dict[key] as? NSNumber {
                return value.boolValue
            }
            if let value = dict[key] as? String {
                let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if normalized == "true" || normalized == "1" { return true }
                if normalized == "false" || normalized == "0" { return false }
            }
        }
        return nil
    }

    private static func stringValue(for keys: [String], in dict: [String: Any]) -> String? {
        for key in keys {
            if let text = dict[key] as? String {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
        }
        return nil
    }
}

enum JSONValue: Decodable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }
}

enum CaptainSource: String, Encodable {
    case captain
    case coach
}

struct CaptainUserContext: Encodable {
    let fullName: String
    let level: String
    let weight: Double
    let gender: String
    let age: Int?
    let steps: Int?
    let caloriesBurned: Int?
    let workoutType: String?
    let distance: Double?
    let sleepHours: Double?
    let fitnessGoal: String?
    let aiqoCoins: Int?
    let currentDailySteps: Int?
    let todayWorkout: String?

    enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
        case level
        case weight
        case gender
        case age
        case steps
        case caloriesBurned = "calories_burned"
        case workoutType = "workout_type"
        case distance
        case sleepHours = "sleep_hours"
        // Backward-compatible keys still sent if available.
        case fitnessGoal = "fitness_goal"
        case aiqoCoins = "aiqo_coins"
        case currentDailySteps = "current_daily_steps"
        case todayWorkout = "today_workout"
    }
}

struct CaptainUserContextInput {
    let fullName: String?
    let level: String?
    let weight: Double?
    let gender: String?
    let age: Int?
    let steps: Int?
    let caloriesBurned: Int?
    let workoutType: String?
    let distance: Double?
    let sleepHours: Double?
    let fitnessGoal: String?
    let currentDailySteps: Int?
    let aiqoCoins: Int?
    let todayWorkout: String?

    init(
        fullName: String? = nil,
        level: String? = nil,
        weight: Double? = nil,
        gender: String? = nil,
        age: Int? = nil,
        steps: Int? = nil,
        caloriesBurned: Int? = nil,
        workoutType: String? = nil,
        distance: Double? = nil,
        sleepHours: Double? = nil,
        fitnessGoal: String? = nil,
        currentDailySteps: Int? = nil,
        aiqoCoins: Int? = nil,
        todayWorkout: String? = nil
    ) {
        self.fullName = fullName
        self.level = level
        self.weight = weight
        self.gender = gender
        self.age = age
        self.steps = steps
        self.caloriesBurned = caloriesBurned
        self.workoutType = workoutType
        self.distance = distance
        self.sleepHours = sleepHours
        self.fitnessGoal = fitnessGoal
        self.currentDailySteps = currentDailySteps
        self.aiqoCoins = aiqoCoins
        self.todayWorkout = todayWorkout
    }
}

struct CaptainRequest: Encodable {
    let userId: String
    let message: String
    let userContext: CaptainUserContext
    let conversationId: String?
    let source: CaptainSource

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case message
        case userContext = "user_context"
        case conversationId = "conversation_id"
        case source
    }
}

// MARK: - Errors

enum CaptainServiceError: LocalizedError {
    case missingToken
    case invalidURL
    case invalidResponse
    case server(statusCode: Int, body: String?)
    case apiFailure
    case decodeFailed

    var errorDescription: String? {
        switch self {
        case .missingToken:
            return "APP_TOKEN مفقود. تأكد من Info.plist."
        case .invalidURL:
            return "CAPTAIN_ENDPOINT غلط. تأكد من Info.plist."
        case .invalidResponse:
            return "رد السيرفر مو صحيح."
        case .server(let statusCode, let body):
            if let body, !body.isEmpty {
                return "Captain service failed (\(statusCode)): \(body)"
            }
            return "Captain service failed (\(statusCode))"
        case .apiFailure:
            return "Captain service رجّع ok=false"
        case .decodeFailed:
            return "ما كدرت أفك JSON مال الرد."
        }
    }
}

// MARK: - Config (Info.plist)

enum AppConfig {
    private static let endpointKey = "CAPTAIN_ENDPOINT"
    private static let tokenKey = "APP_TOKEN"

    static var captainEndpoint: URL {
        let raw = (Bundle.main.object(forInfoDictionaryKey: endpointKey) as? String ?? "")
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        if let url = URL(string: trimmed), !trimmed.isEmpty {
            return url
        }

        // fallback (غيره إذا تريد)
        return URL(string: "https://aiqo-proxy.appaiqo5.workers.dev/")!
    }

    static func appToken() throws -> String {
        let raw = (Bundle.main.object(forInfoDictionaryKey: tokenKey) as? String ?? "")
        let token = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { throw CaptainServiceError.missingToken }
        return token
    }
}

// MARK: - Reply Sanitizer

struct CaptainReplySanitizer {
    static func shorten(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "ماكو رد هسه، جرّب بعد شوي." }

        let lines = trimmed
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if lines.isEmpty { return "ماكو رد هسه، جرّب بعد شوي." }
        return lines.prefix(5).joined(separator: "\n")
    }
}

// MARK: - Identity / Memory (Local)

final class CaptainIdentityStore {
    static let shared = CaptainIdentityStore()

    private enum Keys {
        static let userId = "aiqo.captain.userId"
        static let conversationId = "aiqo.captain.conversationId"
    }

    private let defaults = UserDefaults.standard
    private init() {}

    var userID: String {
        if let existing = defaults.string(forKey: Keys.userId), !existing.isEmpty {
            return existing
        }
        let newId = UUID().uuidString
        defaults.set(newId, forKey: Keys.userId)
        return newId
    }

    var conversationID: String? {
        get { defaults.string(forKey: Keys.conversationId) }
        set {
            let trimmed = newValue?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let trimmed, !trimmed.isEmpty {
                defaults.set(trimmed, forKey: Keys.conversationId)
            } else {
                defaults.removeObject(forKey: Keys.conversationId)
            }
        }
    }
}

final class CaptainMemoryStore {
    static let shared = CaptainMemoryStore()
    private init() {}

    var userId: String { CaptainIdentityStore.shared.userID }
    var conversationId: String? {
        get { CaptainIdentityStore.shared.conversationID }
        set { CaptainIdentityStore.shared.conversationID = newValue }
    }
}

// MARK: - Network

final class CaptainService {
    static let shared = CaptainService()

    private let session: URLSession
    init(session: URLSession = .shared) { self.session = session }

    /// ترجع String جاهز للعرض + تحدّث conversationId تلقائياً
    func send(userMessage: String) async throws -> String {
        try await sendUserText(userMessage)
    }

    /// مسار واضح لشات الكابتن: يرسل نص المستخدم فقط داخل message
    func sendUserText(_ text: String) async throws -> String {
        let response = try await sendUserTextRaw(text)
        return CaptainReplySanitizer.shorten(response.replyText)
    }

    /// مسار واضح لبرومبتات الكوتش (مو شات المستخدم)
    func sendCoachPrompt(_ prompt: String) async throws -> String {
        let userId = CaptainMemoryStore.shared.userId
        let response = try await sendRaw(
            message: prompt,
            userId: userId,
            conversationId: nil,
            userContext: nil,
            source: .coach
        )
        return CaptainReplySanitizer.shorten(response.replyText)
    }

    /// Raw call لشات الكابتن مع تحديث conversationId
    func sendUserTextRaw(
        _ text: String,
        userId: String? = nil,
        conversationId: String? = nil,
        userContext: CaptainUserContextInput? = nil
    ) async throws -> CaptainResponse {
        let resolvedUserId = userId ?? CaptainMemoryStore.shared.userId
        let resolvedConversationId = conversationId ?? CaptainMemoryStore.shared.conversationId
        let response = try await sendRaw(
            message: text,
            userId: resolvedUserId,
            conversationId: resolvedConversationId,
            userContext: userContext,
            source: .captain
        )
        if let newConv = response.conversationId, !newConv.isEmpty {
            CaptainMemoryStore.shared.conversationId = newConv
        }
        return response
    }

    /// Raw call إذا تحتاجه
    func sendRaw(
        message: String,
        userId: String,
        conversationId: String?,
        userContext: CaptainUserContextInput? = nil,
        source: CaptainSource = .captain
    ) async throws -> CaptainResponse {
        let endpoint = AppConfig.captainEndpoint

        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.timeoutInterval = 30
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(try AppConfig.appToken())", forHTTPHeaderField: "Authorization")

        let payload = CaptainRequest(
            userId: userId,
            message: message,
            userContext: await makeUserContext(from: userContext),
            conversationId: conversationId,
            source: source
        )

        req.httpBody = try JSONEncoder().encode(payload)
#if DEBUG
        if let bodyData = req.httpBody, let bodyText = String(data: bodyData, encoding: .utf8) {
            print("CaptainService request body: \(bodyText)")
        }
#endif

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw CaptainServiceError.invalidResponse
        }

        let rawBody = String(data: data, encoding: .utf8)
        let parsedBody = CaptainResponseParser.parse(data: data)

        if !(200...299).contains(http.statusCode) {
            if let parsedBody, !parsedBody.replyText.isEmpty {
                return parsedBody
            }

            let summary = CaptainResponseParser.parseErrorSummary(data: data) ?? rawBody
            throw CaptainServiceError.server(statusCode: http.statusCode, body: summary)
        }

        if let parsedBody {
            if parsedBody.ok == false { throw CaptainServiceError.apiFailure }
            return parsedBody
        }

        do {
            let decoded = try JSONDecoder().decode(CaptainResponse.self, from: data)
            if decoded.ok == false { throw CaptainServiceError.apiFailure }
            return decoded
        } catch {
            throw CaptainServiceError.decodeFailed
        }
    }

    private func makeUserContext(from input: CaptainUserContextInput?) async -> CaptainUserContext {
        let profile = UserProfileStore.shared.current
        let appGroupDefaults = UserDefaults(suiteName: AppGroupKeys.appGroupID)
        let defaults = UserDefaults.standard
        let hkContext = await fetchEnrichedHealthContext()

        let fullName = normalizedText(input?.fullName)
            ?? normalizedText(profile.name)
            ?? "User"

        let storedLevelNumber = max(1, defaults.integer(forKey: "aiqo.user.level"))
        let level = normalizedText(input?.level)
            ?? levelLabel(for: storedLevelNumber)
            ?? "beginner"

        let storedWeightText = normalizedText(defaults.string(forKey: "captain_user_weight"))
        let storedWeight = storedWeightText.flatMap(Double.init)
        let weight = resolvedDouble(input?.weight, fallback: positiveOrNil(Double(profile.weightKg)))
            ?? resolvedDouble(storedWeight, fallback: nil)
            ?? 0.0

        let storedGender = normalizedText(defaults.string(forKey: "user_gender"))
        let gender = normalizedGender(input?.gender)
            ?? normalizedGender(storedGender)
            ?? "male"

        let age = resolvedOptionalInt(input?.age, fallback: positiveOrNil(profile.age))

        let steps = resolvedOptionalInt(
            input?.steps ?? input?.currentDailySteps,
            fallback: hkContext.steps ?? positiveOrNil(appGroupDefaults?.integer(forKey: "aiqo_steps"))
        )

        let caloriesBurned = resolvedOptionalInt(
            input?.caloriesBurned,
            fallback: hkContext.caloriesBurned ?? positiveOrNil(appGroupDefaults?.integer(forKey: "aiqo_active_cal"))
        )

        let workoutType = normalizedText(input?.workoutType)
            ?? normalizedText(input?.todayWorkout)
            ?? normalizedText(hkContext.workoutType)
            ?? "بدون تمرين"

        let distance = resolvedOptionalDouble(
            input?.distance,
            fallback: hkContext.distance ?? positiveOrNil(appGroupDefaults?.double(forKey: "aiqo_km"))
        )

        let sleepHours = resolvedOptionalDouble(input?.sleepHours, fallback: hkContext.sleepHours)

        let fitnessGoal = normalizedText(input?.fitnessGoal) ?? normalizedText(profile.goalText)
        let aiqoCoins = resolvedOptionalInt(
            input?.aiqoCoins,
            fallback: positiveOrNil(appGroupDefaults?.integer(forKey: AppGroupKeys.userCoins))
        )

        return CaptainUserContext(
            fullName: fullName,
            level: level,
            weight: weight,
            gender: gender,
            age: age,
            steps: steps,
            caloriesBurned: caloriesBurned,
            workoutType: workoutType,
            distance: distance,
            sleepHours: sleepHours,
            fitnessGoal: fitnessGoal,
            aiqoCoins: aiqoCoins,
            currentDailySteps: steps,
            todayWorkout: workoutType
        )
    }

    private func fetchEnrichedHealthContext() async -> (
        steps: Int?,
        caloriesBurned: Int?,
        workoutType: String?,
        distance: Double?,
        sleepHours: Double?
    ) {
        guard HKHealthStore.isHealthDataAvailable() else {
            return (nil, nil, nil, nil, nil)
        }

        let healthStore = HKHealthStore()
        let stepType = HKObjectType.quantityType(forIdentifier: .stepCount)
        let activeEnergyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)
        let distanceType = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
        let workoutType = HKObjectType.workoutType()

        var readTypes = Set<HKObjectType>()
        if let stepType { readTypes.insert(stepType) }
        if let activeEnergyType { readTypes.insert(activeEnergyType) }
        if let distanceType { readTypes.insert(distanceType) }
        if let sleepType { readTypes.insert(sleepType) }
        readTypes.insert(workoutType)

        do {
            try await healthStore.requestAuthorization(toShare: Set<HKSampleType>(), read: readTypes)
        } catch {
            return (nil, nil, nil, nil, nil)
        }

        async let stepsTask = sumToday(
            in: healthStore,
            type: .stepCount,
            unit: .count()
        )
        async let caloriesTask = sumToday(
            in: healthStore,
            type: .activeEnergyBurned,
            unit: .kilocalorie()
        )
        async let distanceTask = sumToday(
            in: healthStore,
            type: .distanceWalkingRunning,
            unit: .meter()
        )
        async let sleepHoursTask = sleepHoursToday(in: healthStore)
        async let workoutTask = fetchTodayWorkoutName(from: healthStore)

        let steps = positiveOrNil(Int((await stepsTask).rounded()))
        let calories = positiveOrNil(Int((await caloriesTask).rounded()))
        let distanceKm = positiveOrNil((await distanceTask) / 1000.0)
        let sleepHours = positiveOrNil(await sleepHoursTask)
        let workoutName = await workoutTask

        return (
            steps,
            calories,
            normalizedText(workoutName) ?? "بدون تمرين",
            distanceKm,
            sleepHours
        )
    }

    private func sleepHoursToday(in store: HKHealthStore) async -> Double {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return 0 }

        let now = Date()
        let dayStart = Calendar.current.startOfDay(for: now)
        let dayEnd = now

        let fetchStart = Calendar.current.date(byAdding: .hour, value: -18, to: dayStart) ?? dayStart
        let predicate = HKQuery.predicateForSamples(
            withStart: fetchStart,
            end: dayEnd,
            options: []
        )

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                let sleepSamples = (samples as? [HKCategorySample]) ?? []

                let relevant = sleepSamples.filter {
                    if #available(iOS 16.0, *) {
                        return $0.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                               $0.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                               $0.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue ||
                               $0.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
                    } else {
                        return $0.value == HKCategoryValueSleepAnalysis.asleep.rawValue
                    }
                }

                let seconds = relevant.reduce(0.0) { partial, sample in
                    let start = max(sample.startDate, dayStart)
                    let end = min(sample.endDate, dayEnd)
                    return end > start ? partial + end.timeIntervalSince(start) : partial
                }

                continuation.resume(returning: seconds / 3600.0)
            }
            store.execute(query)
        }
    }

    private func resolvedOptionalInt(_ primary: Int?, fallback: Int?) -> Int? {
        if let primary, primary >= 0 { return primary }
        if let fallback, fallback >= 0 { return fallback }
        return nil
    }

    private func resolvedOptionalDouble(_ primary: Double?, fallback: Double?) -> Double? {
        if let primary, primary >= 0 { return primary }
        if let fallback, fallback >= 0 { return fallback }
        return nil
    }

    private func resolvedDouble(_ primary: Double?, fallback: Double?) -> Double? {
        if let primary, primary >= 0 { return primary }
        if let fallback, fallback >= 0 { return fallback }
        return nil
    }

    private func positiveOrNil(_ value: Int?) -> Int? {
        guard let value, value > 0 else { return nil }
        return value
    }

    private func positiveOrNil(_ value: Double?) -> Double? {
        guard let value, value > 0 else { return nil }
        return value
    }

    private func levelLabel(for level: Int) -> String? {
        switch level {
        case 1...7:
            return "beginner"
        case 8...19:
            return "intermediate"
        case 20...:
            return "advanced"
        default:
            return nil
        }
    }

    private func normalizedGender(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if value == "female" { return "female" }
        if value == "male" { return "male" }
        return nil
    }

    private func fetchTodayWorkoutName(from store: HKHealthStore) async -> String {
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)

        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: now,
            options: .strictStartDate
        )
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                guard let workout = (samples as? [HKWorkout])?.first else {
                    continuation.resume(returning: "بدون تمرين")
                    return
                }
                continuation.resume(returning: Self.workoutName(for: workout.workoutActivityType))
            }
            store.execute(query)
        }
    }

    private func sumToday(
        in store: HKHealthStore,
        type identifier: HKQuantityTypeIdentifier,
        unit: HKUnit
    ) async -> Double {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else { return 0 }

        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: now,
            options: .strictStartDate
        )

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, _ in
                let value = statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    private static func workoutName(for type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return "Running"
        case .walking: return "Walking"
        case .cycling: return "Cycling"
        case .swimming: return "Swimming"
        case .traditionalStrengthTraining: return "Strength Training"
        case .functionalStrengthTraining: return "Functional Strength"
        case .highIntensityIntervalTraining: return "HIIT"
        case .yoga: return "Yoga"
        case .pilates: return "Pilates"
        case .dance: return "Dance"
        default:
            return "Workout"
        }
    }

    private func normalizedText(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

// MARK: - Notifications Deep-link State

final class CaptainNotificationHandler: ObservableObject {
    static let shared = CaptainNotificationHandler()

    @Published var pendingNotificationMessage: String?
    @Published var shouldNavigateToCaptain: Bool = false

    private let pendingMessageKey = "aiqo.captain.pendingMessage"

    private init() {
        pendingNotificationMessage = UserDefaults.standard.string(forKey: pendingMessageKey)
    }

    func handleIncomingNotification(userInfo: [AnyHashable: Any]) {
        guard let source = userInfo["source"] as? String, source == "captain_hamoudi" else { return }

        let text = userInfo["messageText"] as? String
        ?? userInfo["notificationText"] as? String
        ?? userInfo["text"] as? String

        guard let messageText = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !messageText.isEmpty else { return }

        UserDefaults.standard.set(messageText, forKey: pendingMessageKey)

        DispatchQueue.main.async {
            self.pendingNotificationMessage = messageText
            self.shouldNavigateToCaptain = true

            NotificationCenter.default.post(
                name: .captainLaunchFromNotification,
                object: nil,
                userInfo: ["prompt": messageText]
            )
        }
    }

    func clearPendingMessage() {
        pendingNotificationMessage = nil
        shouldNavigateToCaptain = false
        UserDefaults.standard.removeObject(forKey: pendingMessageKey)
    }

    func hasPendingMessage() -> Bool {
        if let message = pendingNotificationMessage,
           !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        if let stored = UserDefaults.standard.string(forKey: pendingMessageKey),
           !stored.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        return false
    }
}

final class CaptainNavigationHelper {
    static let shared = CaptainNavigationHelper()
    private init() {}

    func navigateToCaptainScreen() {
        Task { @MainActor in
            MainTabRouter.shared.navigate(to: .captain)
        }
        NotificationCenter.default.post(name: .navigateToCaptainScreen, object: nil)
    }
}

extension Notification.Name {
    static let captainLaunchFromNotification = Notification.Name("captainLaunchFromNotification")
    static let navigateToCaptainScreen = Notification.Name("navigateToCaptainScreen")
}
