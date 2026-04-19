import Foundation
import UIKit
import Combine

@MainActor
final class LearningProofStore: ObservableObject {
    static let shared = LearningProofStore()

    @Published private(set) var recordsByQuestId: [String: LearningProofRecord]

    private let defaults: UserDefaults
    private let storageKey = "aiqo.quest.learningProof.records.v1"
    private let imagesDirectoryName = "LearningProofCertificates"
    private let fileManager: FileManager

    init(defaults: UserDefaults = .standard, fileManager: FileManager = .default) {
        self.defaults = defaults
        self.fileManager = fileManager
        self.recordsByQuestId = Self.load(defaults: defaults, storageKey: storageKey)
    }

    func record(for questId: String) -> LearningProofRecord {
        recordsByQuestId[questId] ?? LearningProofRecord(questId: questId)
    }

    /// Persists which course option the user is pursuing.
    ///
    /// If the user switches to a different option and has a non-verified in-flight proof,
    /// the pending proof (image, URL, status) is cleared so the previously submitted
    /// evidence cannot be mis-applied to the newly selected course.
    /// A verified proof is preserved as-is because the challenge is already complete.
    func selectCourseOption(questId: String, optionId: String) {
        var record = self.record(for: questId)

        let shouldResetProof =
            record.selectedCourseOptionId != optionId
            && record.lastResult.status != .verified

        if shouldResetProof {
            if let previous = record.certificateImageRelativePath {
                deleteImage(relativePath: previous)
            }
            record.certificateImageRelativePath = nil
            record.certificateURL = nil
            record.submissionDate = nil
            record.lastVerificationDate = nil
            record.lastResult = .notSubmitted
        }

        record.selectedCourseOptionId = optionId
        recordsByQuestId[questId] = record
        persist()
    }

    func saveCertificateImage(_ image: UIImage, for questId: String) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.85) else { return nil }
        guard let directory = imagesDirectoryURL() else { return nil }

        let filename = "\(questId)-\(Int(Date().timeIntervalSince1970)).jpg"
        let destination = directory.appendingPathComponent(filename)
        do {
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try data.write(to: destination, options: .atomic)
            return filename
        } catch {
            return nil
        }
    }

    func loadCertificateImage(_ relativePath: String?) -> UIImage? {
        guard let relativePath, let directory = imagesDirectoryURL() else { return nil }
        let url = directory.appendingPathComponent(relativePath)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    func certificateImageData(_ relativePath: String?) -> Data? {
        guard let relativePath, let directory = imagesDirectoryURL() else { return nil }
        let url = directory.appendingPathComponent(relativePath)
        return try? Data(contentsOf: url)
    }

    func updateRecord(_ record: LearningProofRecord) {
        recordsByQuestId[record.questId] = record
        persist()
    }

    func markSubmission(
        questId: String,
        certificateImageRelativePath: String?,
        certificateURL: String?,
        submissionDate: Date = Date()
    ) {
        var record = self.record(for: questId)
        // Remove previous image file if we are replacing it with a new one.
        if let previous = record.certificateImageRelativePath,
           previous != certificateImageRelativePath {
            deleteImage(relativePath: previous)
        }
        record.certificateImageRelativePath = certificateImageRelativePath
        record.certificateURL = certificateURL
        record.submissionDate = submissionDate
        record.lastResult = LearningProofVerificationResult(
            status: .pending,
            confidence: nil,
            extractedName: nil,
            extractedCourseTitle: nil,
            extractedProvider: nil,
            extractedCertificateURL: certificateURL,
            rejectionReason: nil,
            notes: nil
        )
        recordsByQuestId[questId] = record
        persist()
    }

    func applyVerificationResult(
        questId: String,
        result: LearningProofVerificationResult,
        date: Date = Date()
    ) {
        var record = self.record(for: questId)
        record.lastVerificationDate = date
        record.lastResult = result
        recordsByQuestId[questId] = record
        persist()
    }

    func resetForRetry(questId: String) {
        var record = self.record(for: questId)
        if let previous = record.certificateImageRelativePath {
            deleteImage(relativePath: previous)
        }
        record = LearningProofRecord(questId: questId)
        recordsByQuestId[questId] = record
        persist()
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(recordsByQuestId) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private func imagesDirectoryURL() -> URL? {
        guard let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let directory = base.appendingPathComponent(imagesDirectoryName, isDirectory: true)
        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    private func deleteImage(relativePath: String) {
        guard let directory = imagesDirectoryURL() else { return }
        let url = directory.appendingPathComponent(relativePath)
        try? fileManager.removeItem(at: url)
    }

    private static func load(
        defaults: UserDefaults,
        storageKey: String
    ) -> [String: LearningProofRecord] {
        guard let data = defaults.data(forKey: storageKey) else { return [:] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([String: LearningProofRecord].self, from: data)) ?? [:]
    }
}
