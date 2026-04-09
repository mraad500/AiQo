import Foundation
import SwiftData

enum CaptainPrimaryGoal: String, CaseIterable, Identifiable, Codable, Sendable {
    case loseWeight
    case gainWeight
    case cutFat
    case buildMuscle
    case improveFitness

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .loseWeight:
            return NSLocalizedString("captainPersonalization.goal.loseWeight", value: "ينزل وزنه", comment: "")
        case .gainWeight:
            return NSLocalizedString("captainPersonalization.goal.gainWeight", value: "يصعد وزنه", comment: "")
        case .cutFat:
            return NSLocalizedString("captainPersonalization.goal.cutFat", value: "ينشف دهون", comment: "")
        case .buildMuscle:
            return NSLocalizedString("captainPersonalization.goal.buildMuscle", value: "بناء العضلات", comment: "")
        case .improveFitness:
            return NSLocalizedString("captainPersonalization.goal.improveFitness", value: "زيادة لياقة", comment: "")
        }
    }

    var canonicalGoalText: String {
        switch self {
        case .loseWeight:
            return "Lose Weight"
        case .gainWeight:
            return "Gain Weight"
        case .cutFat:
            return "Cut Fat"
        case .buildMuscle:
            return "Build Muscle"
        case .improveFitness:
            return "Improve Fitness"
        }
    }

    static func localizedValue(forStoredValue value: String) -> String? {
        allCases.first {
            $0.rawValue == value || $0.canonicalGoalText.caseInsensitiveCompare(value) == .orderedSame
        }?.localizedTitle
    }
}

enum CaptainSportPreference: String, CaseIterable, Identifiable, Codable, Sendable {
    case walking
    case running
    case gymResistance
    case football
    case swimming
    case cycling
    case boxing
    case yoga

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .walking:
            return NSLocalizedString("captainPersonalization.sport.walking", value: "المشي", comment: "")
        case .running:
            return NSLocalizedString("captainPersonalization.sport.running", value: "الجري", comment: "")
        case .gymResistance:
            return NSLocalizedString("captainPersonalization.sport.gymResistance", value: "الجيم / مقاومة", comment: "")
        case .football:
            return NSLocalizedString("captainPersonalization.sport.football", value: "كرة القدم", comment: "")
        case .swimming:
            return NSLocalizedString("captainPersonalization.sport.swimming", value: "السباحة", comment: "")
        case .cycling:
            return NSLocalizedString("captainPersonalization.sport.cycling", value: "الدراجة", comment: "")
        case .boxing:
            return NSLocalizedString("captainPersonalization.sport.boxing", value: "الملاكمة", comment: "")
        case .yoga:
            return NSLocalizedString("captainPersonalization.sport.yoga", value: "اليوغا", comment: "")
        }
    }

    var canonicalValue: String {
        switch self {
        case .walking:
            return "Walking"
        case .running:
            return "Running"
        case .gymResistance:
            return "Gym / Resistance"
        case .football:
            return "Football"
        case .swimming:
            return "Swimming"
        case .cycling:
            return "Cycling"
        case .boxing:
            return "Boxing"
        case .yoga:
            return "Yoga"
        }
    }

    static func localizedValue(forStoredValue value: String) -> String? {
        allCases.first {
            $0.rawValue == value || $0.canonicalValue.caseInsensitiveCompare(value) == .orderedSame
        }?.localizedTitle
    }
}

enum CaptainWorkoutTimePreference: String, CaseIterable, Identifiable, Codable, Sendable {
    case earlyMorning
    case morning
    case afternoon
    case evening
    case night

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .earlyMorning:
            return NSLocalizedString("captainPersonalization.workoutTime.earlyMorning", value: "الفجر / بدري", comment: "")
        case .morning:
            return NSLocalizedString("captainPersonalization.workoutTime.morning", value: "الصبح", comment: "")
        case .afternoon:
            return NSLocalizedString("captainPersonalization.workoutTime.afternoon", value: "الظهر", comment: "")
        case .evening:
            return NSLocalizedString("captainPersonalization.workoutTime.evening", value: "المساء", comment: "")
        case .night:
            return NSLocalizedString("captainPersonalization.workoutTime.night", value: "الليل", comment: "")
        }
    }

    var canonicalValue: String {
        switch self {
        case .earlyMorning:
            return "Early Morning"
        case .morning:
            return "Morning"
        case .afternoon:
            return "Afternoon"
        case .evening:
            return "Evening"
        case .night:
            return "Night"
        }
    }

    var reminderTime: CaptainReminderTime {
        switch self {
        case .earlyMorning:
            return CaptainReminderTime(hour: 6, minute: 30)
        case .morning:
            return CaptainReminderTime(hour: 8, minute: 0)
        case .afternoon:
            return CaptainReminderTime(hour: 13, minute: 0)
        case .evening:
            return CaptainReminderTime(hour: 18, minute: 0)
        case .night:
            return CaptainReminderTime(hour: 21, minute: 0)
        }
    }

    static func localizedValue(forStoredValue value: String) -> String? {
        allCases.first {
            $0.rawValue == value || $0.canonicalValue.caseInsensitiveCompare(value) == .orderedSame
        }?.localizedTitle
    }
}

struct CaptainReminderTime: Codable, Equatable, Sendable {
    let hour: Int
    let minute: Int
}

struct CaptainPersonalizationSnapshot: Codable, Equatable, Sendable {
    var primaryGoalRaw: String
    var favoriteSportRaw: String
    var preferredWorkoutTimeRaw: String
    var bedtime: Date
    var wakeTime: Date
    var recommendedWakeTime: Date
    var isAlarmSaved: Bool

    init(
        primaryGoal: CaptainPrimaryGoal,
        favoriteSport: CaptainSportPreference,
        preferredWorkoutTime: CaptainWorkoutTimePreference,
        bedtime: Date,
        wakeTime: Date,
        recommendedWakeTime: Date,
        isAlarmSaved: Bool
    ) {
        self.primaryGoalRaw = primaryGoal.rawValue
        self.favoriteSportRaw = favoriteSport.rawValue
        self.preferredWorkoutTimeRaw = preferredWorkoutTime.rawValue
        self.bedtime = bedtime
        self.wakeTime = wakeTime
        self.recommendedWakeTime = recommendedWakeTime
        self.isAlarmSaved = isAlarmSaved
    }

    var primaryGoal: CaptainPrimaryGoal {
        CaptainPrimaryGoal(rawValue: primaryGoalRaw) ?? .improveFitness
    }

    var favoriteSport: CaptainSportPreference {
        CaptainSportPreference(rawValue: favoriteSportRaw) ?? .walking
    }

    var preferredWorkoutTime: CaptainWorkoutTimePreference {
        CaptainWorkoutTimePreference(rawValue: preferredWorkoutTimeRaw) ?? .evening
    }
}

@Model
final class CaptainPersonalizationProfile {
    static let singletonID = "captain_personalization_current"

    @Attribute(.unique) var profileID: String
    var primaryGoalRaw: String
    var favoriteSportRaw: String
    var preferredWorkoutTimeRaw: String
    var bedtime: Date
    var wakeTime: Date
    var recommendedWakeTime: Date
    var isAlarmSaved: Bool
    var createdAt: Date
    var updatedAt: Date

    init(snapshot: CaptainPersonalizationSnapshot) {
        self.profileID = Self.singletonID
        self.primaryGoalRaw = snapshot.primaryGoalRaw
        self.favoriteSportRaw = snapshot.favoriteSportRaw
        self.preferredWorkoutTimeRaw = snapshot.preferredWorkoutTimeRaw
        self.bedtime = snapshot.bedtime
        self.wakeTime = snapshot.wakeTime
        self.recommendedWakeTime = snapshot.recommendedWakeTime
        self.isAlarmSaved = snapshot.isAlarmSaved
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    func apply(_ snapshot: CaptainPersonalizationSnapshot) {
        primaryGoalRaw = snapshot.primaryGoalRaw
        favoriteSportRaw = snapshot.favoriteSportRaw
        preferredWorkoutTimeRaw = snapshot.preferredWorkoutTimeRaw
        bedtime = snapshot.bedtime
        wakeTime = snapshot.wakeTime
        recommendedWakeTime = snapshot.recommendedWakeTime
        isAlarmSaved = snapshot.isAlarmSaved
        updatedAt = Date()
    }

    var snapshot: CaptainPersonalizationSnapshot {
        CaptainPersonalizationSnapshot(
            primaryGoal: CaptainPrimaryGoal(rawValue: primaryGoalRaw) ?? .improveFitness,
            favoriteSport: CaptainSportPreference(rawValue: favoriteSportRaw) ?? .walking,
            preferredWorkoutTime: CaptainWorkoutTimePreference(rawValue: preferredWorkoutTimeRaw) ?? .evening,
            bedtime: bedtime,
            wakeTime: wakeTime,
            recommendedWakeTime: recommendedWakeTime,
            isAlarmSaved: isAlarmSaved
        )
    }
}

enum CaptainPersonalizationReminderMapper {
    static func sleepReminderTime(
        bedtime: Date,
        calendar: Calendar = .current
    ) -> CaptainReminderTime {
        let reminderDate = calendar.date(byAdding: .minute, value: -30, to: bedtime)
            ?? bedtime.addingTimeInterval(-30 * 60)
        let components = calendar.dateComponents([.hour, .minute], from: reminderDate)
        return CaptainReminderTime(
            hour: components.hour ?? 22,
            minute: components.minute ?? 30
        )
    }
}

enum CaptainPersonalizationTimeFormatter {
    private static let storageFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    static func memoryString(_ date: Date) -> String {
        storageFormatter.string(from: date)
    }

    static func localizedString(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}

final class CaptainPersonalizationStore {
    static let shared = CaptainPersonalizationStore()

    private let queue = DispatchQueue(label: "AiQo.CaptainPersonalizationStore")
    private let defaults: UserDefaults
    private let cacheKey = "aiqo.captainPersonalization.snapshot"
    private var container: ModelContainer?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func configure(container: ModelContainer) {
        queue.sync {
            self.container = container
        }
    }

    func currentSnapshot() -> CaptainPersonalizationSnapshot? {
        queue.sync {
            fetchSnapshotFromSwiftData() ?? cachedSnapshot()
        }
    }

    @discardableResult
    func save(_ snapshot: CaptainPersonalizationSnapshot) -> Bool {
        queue.sync {
            cache(snapshot)

            guard let container else {
                return false
            }

            let context = ModelContext(container)
            let recordID = CaptainPersonalizationProfile.singletonID
            let descriptor = FetchDescriptor<CaptainPersonalizationProfile>(
                predicate: #Predicate { $0.profileID == recordID }
            )

            do {
                if let existing = try context.fetch(descriptor).first {
                    existing.apply(snapshot)
                } else {
                    context.insert(CaptainPersonalizationProfile(snapshot: snapshot))
                }
                try context.save()
                return true
            } catch {
                #if DEBUG
                print("[CaptainPersonalizationStore] Save failed: \(error)")
                #endif
                return false
            }
        }
    }

    func workoutReminderTime() -> CaptainReminderTime? {
        currentSnapshot()?.preferredWorkoutTime.reminderTime
    }

    func sleepReminderTime(calendar: Calendar = .current) -> CaptainReminderTime? {
        guard let bedtime = currentSnapshot()?.bedtime else {
            return nil
        }

        return CaptainPersonalizationReminderMapper.sleepReminderTime(
            bedtime: bedtime,
            calendar: calendar
        )
    }

    private func fetchSnapshotFromSwiftData() -> CaptainPersonalizationSnapshot? {
        guard let container else { return nil }

        let context = ModelContext(container)
        let recordID = CaptainPersonalizationProfile.singletonID
        let descriptor = FetchDescriptor<CaptainPersonalizationProfile>(
            predicate: #Predicate { $0.profileID == recordID }
        )

        do {
            return try context.fetch(descriptor).first?.snapshot
        } catch {
            #if DEBUG
            print("[CaptainPersonalizationStore] Fetch failed: \(error)")
            #endif
            return nil
        }
    }

    private func cache(_ snapshot: CaptainPersonalizationSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: cacheKey)
    }

    private func cachedSnapshot() -> CaptainPersonalizationSnapshot? {
        guard let data = defaults.data(forKey: cacheKey) else { return nil }
        return try? JSONDecoder().decode(CaptainPersonalizationSnapshot.self, from: data)
    }
}
