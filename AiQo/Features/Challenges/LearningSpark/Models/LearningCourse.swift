import Foundation

/// Canonical data model for a single learning course surfaced by the Learning Spark
/// challenge (and future expansions). Hard-coded static catalog for Stage 1 (exactly 2
/// courses — paradox-of-choice avoidance). Stage 2+ may add more rows; no dynamic filter
/// or search until that happens.
struct LearningCourse: Identifiable, Hashable, Sendable {
    enum Platform: String, Codable, Hashable, Sendable, CaseIterable {
        case edraak
        case coursera
        case rwaq
        case maharah
        case edx
        case youtube
    }

    enum Language: String, Codable, Hashable, Sendable {
        case arabic
        case english
    }

    let id: String
    let titleAr: String
    let titleEn: String
    let platform: Platform
    let language: Language
    let descriptionAr: String
    /// Optional English description. Falls back to `descriptionAr` when unset.
    let descriptionEn: String?
    let sourceURL: URL
    let isFree: Bool
    let stage: Int
    let estimatedHours: Int

    init(
        id: String,
        titleAr: String,
        titleEn: String,
        platform: Platform,
        language: Language,
        descriptionAr: String,
        descriptionEn: String? = nil,
        sourceURL: URL,
        isFree: Bool,
        stage: Int,
        estimatedHours: Int
    ) {
        // App Store compliance invariant: the catalog only carries free courses.
        precondition(isFree, "LearningCourse must be free (isFree == true).")
        self.id = id
        self.titleAr = titleAr
        self.titleEn = titleEn
        self.platform = platform
        self.language = language
        self.descriptionAr = descriptionAr
        self.descriptionEn = descriptionEn
        self.sourceURL = sourceURL
        self.isFree = isFree
        self.stage = stage
        self.estimatedHours = estimatedHours
    }
}

// Platform-level helpers are `nonisolated` so actors (CertificateVerifier,
// HamoudiVerificationReasoner) can read them without hopping to MainActor.
// These are pure lookups over an enum — no shared mutable state.
extension LearningCourse.Platform {
    /// Canonical display name used for on-device verification matching + debug.
    nonisolated var canonicalName: String {
        switch self {
        case .edraak: return "Edraak"
        case .coursera: return "Coursera"
        case .rwaq: return "Rwaq"
        case .maharah: return "Maharah"
        case .edx: return "edX"
        case .youtube: return "YouTube"
        }
    }

    /// Domains allowed for certificate URL validation and SFSafariViewController routing.
    nonisolated var certificateDomains: [String] {
        switch self {
        case .edraak: return ["edraak.org", "www.edraak.org"]
        case .coursera: return ["coursera.org", "www.coursera.org", "accounts.coursera.org"]
        case .rwaq: return ["rwaq.org", "www.rwaq.org"]
        case .maharah: return ["maharah.net", "www.maharah.net"]
        case .edx: return ["edx.org", "www.edx.org", "courses.edx.org"]
        case .youtube: return ["youtube.com", "www.youtube.com", "youtu.be", "m.youtube.com"]
        }
    }

    /// Localization key for the human-readable platform label.
    nonisolated var providerDisplayKey: String {
        "learning.platform.\(rawValue)"
    }
}

enum LearningCourseCatalog {
    /// Stage 1 — EXACTLY two courses by product decision. Do not add more here.
    ///
    /// **Do not remove** — even if a course is deprecated, prefer hiding via feature
    /// flag so we can roll forward without breaking progress records that reference
    /// the course ID.
    static let stage1: [LearningCourse] = [
        LearningCourse(
            id: "edraak.career-path",
            titleAr: "التخطيط لبناء مسار مهني",
            titleEn: "Planning a Career Path",
            platform: .edraak,
            language: .arabic,
            descriptionAr: "ابنِ خطة واضحة لمسارك المهني وطوّر قرارك الذاتي.",
            descriptionEn: "Build a clear career plan and sharpen your decision-making.",
            sourceURL: URL(string: "https://www.edraak.org/programs/course/miskskill-6-v1/")!,
            isFree: true,
            stage: 1,
            estimatedHours: 6
        ),
        LearningCourse(
            id: "coursera.learning-how-to-learn",
            titleAr: "تعلّم كيف تتعلّم",
            titleEn: "Learning How to Learn",
            platform: .coursera,
            language: .english,
            descriptionAr: "افهم كيف يعمل دماغك في التعلّم وادرس بذكاء أعلى.",
            descriptionEn: "Learn how your brain actually learns — study smarter, remember more.",
            sourceURL: URL(string: "https://www.coursera.org/learn/learning-how-to-learn")!,
            isFree: true,
            stage: 1,
            estimatedHours: 15
        )
    ]

    static func course(id: String) -> LearningCourse? {
        stage1.first(where: { $0.id == id })
    }
}
