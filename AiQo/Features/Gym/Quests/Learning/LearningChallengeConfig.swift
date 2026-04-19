import Foundation

enum LearningCourseLanguage: String, Codable, Hashable, Sendable {
    case arabic
    case english

    var displayKey: String {
        switch self {
        case .arabic: return "gym.quest.learning.language.arabic"
        case .english: return "gym.quest.learning.language.english"
        }
    }

    init(_ language: LearningCourse.Language) {
        switch language {
        case .arabic: self = .arabic
        case .english: self = .english
        }
    }
}

/// Presentation-layer adapter over `LearningCourse`. Views keep using this type so
/// no view-signature churn is required when the catalog grows beyond Stage 1.
///
/// All fields are derived from the underlying `course` — `LearningCourse` is the
/// single source of truth; `LearningCourseOption` is just the projection used by the
/// options sheet, detail sheet, and proof submission view.
struct LearningCourseOption: Hashable, Sendable, Identifiable {
    let course: LearningCourse

    var id: String { course.id }

    /// Course title rendered verbatim in its native language (so an Arabic course title
    /// still reads correctly in the English-app chrome and vice versa).
    var title: String {
        switch course.language {
        case .arabic: return course.titleAr
        case .english: return course.titleEn
        }
    }

    var providerDisplayKey: String { course.platform.providerDisplayKey }
    var canonicalProviderName: String { course.platform.canonicalName }
    var courseURL: URL { course.sourceURL }
    var language: LearningCourseLanguage { LearningCourseLanguage(course.language) }
    var allowedCertificateDomains: [String] { course.platform.certificateDomains }

    /// Short benefit-focused blurb. Picks the app-language variant with a fallback to
    /// Arabic (the canonical description).
    var descriptionText: String {
        if AppSettingsStore.shared.appLanguage == .english, let en = course.descriptionEn {
            return en
        }
        return course.descriptionAr
    }

    func isURLFromAllowedDomain(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return allowedCertificateDomains.contains { host == $0 || host.hasSuffix("." + $0) }
    }
}

struct LearningChallengeConfig: Hashable, Sendable {
    let options: [LearningCourseOption]

    func option(withId id: String?) -> LearningCourseOption? {
        guard let id else { return nil }
        return options.first { $0.id == id }
    }

    static let stageOneDefault: LearningChallengeConfig = .init(
        options: LearningCourseCatalog.stage1.map { LearningCourseOption(course: $0) }
    )
}

enum LearningChallengeRegistry {
    static func config(for questId: String) -> LearningChallengeConfig {
        switch questId {
        case QuestDefinition.learningSparkQuestID:
            return .stageOneDefault
        default:
            return .stageOneDefault
        }
    }
}
