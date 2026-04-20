import Foundation
import UIKit
// VNImageRequestHandler and VNRecognizeTextRequest are not Sendable in iOS 26 SDK,
// but we capture them in a @Sendable dispatch closure on purpose — the Vision
// framework guarantees thread-safety for perform(_:) from any queue. @preconcurrency
// treats these types as implicitly Sendable at the use sites in this file.
@preconcurrency import Vision

/// Stage A of the on-device certificate-verification pipeline.
///
/// Extracts Arabic + English text from a certificate image using `VNRecognizeTextRequest`.
/// 100% on-device — the image never leaves the phone. Available on all supported iOS
/// versions (Vision is mature since iOS 13).
enum CertificateOCR {

    struct Result: Sendable {
        /// All recognized observations joined by newline, in reading order.
        let extractedText: String
        /// Average confidence across the top observation per region (0.0 – 1.0).
        let confidence: Double
        /// Languages claimed by the strongest observations. Typically `["ar", "en"]`.
        let detectedLanguages: [String]
    }

    enum OCRError: LocalizedError {
        case imageUnreadable
        case noTextDetected

        var errorDescription: String? {
            switch self {
            case .imageUnreadable: return "Certificate image could not be read."
            case .noTextDetected: return "No text detected on the certificate."
            }
        }
    }

    static func extractText(from image: UIImage) async throws -> Result {
        guard let cgImage = image.cgImage else {
            throw OCRError.imageUnreadable
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let observations = request.results as? [VNRecognizedTextObservation],
                      !observations.isEmpty else {
                    continuation.resume(throwing: OCRError.noTextDetected)
                    return
                }

                var lines: [String] = []
                var confidences: [Double] = []
                var languageHits: Set<String> = []

                for observation in observations {
                    guard let top = observation.topCandidates(1).first else { continue }
                    let text = top.string.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { continue }

                    lines.append(text)
                    confidences.append(Double(top.confidence))
                    languageHits.formUnion(Self.guessLanguages(in: text))
                }

                guard !lines.isEmpty else {
                    continuation.resume(throwing: OCRError.noTextDetected)
                    return
                }

                let averageConfidence = confidences.isEmpty
                    ? 0
                    : confidences.reduce(0, +) / Double(confidences.count)

                let result = Result(
                    extractedText: lines.joined(separator: "\n"),
                    confidence: averageConfidence,
                    detectedLanguages: Array(languageHits).sorted()
                )
                continuation.resume(returning: result)
            }

            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["ar-SA", "en-US"]
            request.usesLanguageCorrection = true
            request.automaticallyDetectsLanguage = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Cheap language hint based on Unicode blocks — no NaturalLanguage dependency.
    /// Not authoritative; used only as metadata for the reasoner.
    private static func guessLanguages(in text: String) -> Set<String> {
        var hits: Set<String> = []
        for scalar in text.unicodeScalars {
            if scalar.value >= 0x0600, scalar.value <= 0x06FF {
                hits.insert("ar")
            } else if scalar.value >= 0x0041, scalar.value <= 0x007A {
                hits.insert("en")
            }
        }
        return hits
    }
}
