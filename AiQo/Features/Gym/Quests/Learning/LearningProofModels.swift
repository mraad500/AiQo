import Foundation

enum LearningProofVerificationStatus: String, Codable, Hashable, Sendable {
    case notSubmitted
    case pending
    case verified
    case rejected
    /// On-device verification completed but the evidence was ambiguous — surfaced to the
    /// user as "بانتظار المراجعة" / "Pending Review". Retryable via the State-D retry button.
    case needsReview
}

struct LearningProofVerificationResult: Codable, Hashable, Sendable {
    let status: LearningProofVerificationStatus
    let confidence: Double?
    let extractedName: String?
    let extractedCourseTitle: String?
    let extractedProvider: String?
    let extractedCertificateURL: String?
    let rejectionReason: String?
    let notes: String?

    static let notSubmitted = LearningProofVerificationResult(
        status: .notSubmitted,
        confidence: nil,
        extractedName: nil,
        extractedCourseTitle: nil,
        extractedProvider: nil,
        extractedCertificateURL: nil,
        rejectionReason: nil,
        notes: nil
    )
}

struct LearningProofRecord: Codable, Hashable, Sendable {
    var questId: String
    /// ID of the `LearningCourseOption` the user picked inside the options sheet.
    /// Nil when the user has not chosen a course path yet.
    var selectedCourseOptionId: String?
    var certificateImageRelativePath: String?
    var certificateURL: String?
    var submissionDate: Date?
    var lastVerificationDate: Date?
    var lastResult: LearningProofVerificationResult

    init(
        questId: String,
        selectedCourseOptionId: String? = nil,
        certificateImageRelativePath: String? = nil,
        certificateURL: String? = nil,
        submissionDate: Date? = nil,
        lastVerificationDate: Date? = nil,
        lastResult: LearningProofVerificationResult = .notSubmitted
    ) {
        self.questId = questId
        self.selectedCourseOptionId = selectedCourseOptionId
        self.certificateImageRelativePath = certificateImageRelativePath
        self.certificateURL = certificateURL
        self.submissionDate = submissionDate
        self.lastVerificationDate = lastVerificationDate
        self.lastResult = lastResult
    }

    private enum CodingKeys: String, CodingKey {
        case questId
        case selectedCourseOptionId
        case certificateImageRelativePath
        case certificateURL
        case submissionDate
        case lastVerificationDate
        case lastResult
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        questId = try container.decode(String.self, forKey: .questId)
        selectedCourseOptionId = try container.decodeIfPresent(String.self, forKey: .selectedCourseOptionId)
        certificateImageRelativePath = try container.decodeIfPresent(String.self, forKey: .certificateImageRelativePath)
        certificateURL = try container.decodeIfPresent(String.self, forKey: .certificateURL)
        submissionDate = try container.decodeIfPresent(Date.self, forKey: .submissionDate)
        lastVerificationDate = try container.decodeIfPresent(Date.self, forKey: .lastVerificationDate)
        lastResult = try container.decodeIfPresent(LearningProofVerificationResult.self, forKey: .lastResult)
            ?? .notSubmitted
    }
}
