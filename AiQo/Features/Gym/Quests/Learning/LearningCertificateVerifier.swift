import Foundation

enum LearningCertificateVerifierError: LocalizedError {
    case missingAPIKey
    case invalidEndpoint
    case networkUnavailable
    case requestFailed
    case badStatusCode(Int)
    case emptyResponse
    case invalidJSON

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Certificate verification unavailable: CAPTAIN_API_KEY missing."
        case .invalidEndpoint:
            return "Certificate verifier endpoint could not be constructed."
        case .networkUnavailable:
            return "No internet connection available."
        case .requestFailed:
            return "Verification request failed."
        case .badStatusCode(let code):
            return "Verification request returned HTTP \(code)."
        case .emptyResponse:
            return "Verification response was empty."
        case .invalidJSON:
            return "Verification response was not valid JSON."
        }
    }
}

struct LearningCertificateVerificationInput: Sendable {
    let questTitle: String
    let expectedCourseTitle: String
    let expectedProvider: String
    let userDisplayName: String?
    let certificateImageData: Data
    let certificateURLString: String
    let languageCode: String
}

@available(*, deprecated, message: "Replaced by on-device CertificateVerifier. Retained for rollback via LEARNING_VERIFICATION_ON_DEVICE_ENABLED feature flag.")
struct LearningCertificateVerifier: Sendable {
    private let session: URLSession
    private let endpointBase: String
    private let model: String
    private let requestTimeout: TimeInterval

    init(
        session: URLSession? = nil,
        endpointBase: String = "https://generativelanguage.googleapis.com/v1beta/models",
        model: String = "gemini-2.5-flash",
        requestTimeout: TimeInterval = 35
    ) {
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = requestTimeout
            config.timeoutIntervalForResource = requestTimeout + 5
            config.waitsForConnectivity = false
            config.requestCachePolicy = .reloadIgnoringLocalCacheData
            self.session = URLSession(configuration: config)
        }
        self.endpointBase = endpointBase
        self.model = model
        self.requestTimeout = requestTimeout
    }

    func verify(_ input: LearningCertificateVerificationInput) async throws -> LearningProofVerificationResult {
        let apiKey = try resolvedAPIKey()

        guard let url = URL(string: "\(endpointBase)/\(model):generateContent") else {
            throw LearningCertificateVerifierError.invalidEndpoint
        }

        let body = requestBody(for: input)

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = requestTimeout
        urlRequest.cachePolicy = .reloadIgnoringLocalCacheData
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "X-goog-api-key")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw isNetworkUnavailable(error)
                ? LearningCertificateVerifierError.networkUnavailable
                : LearningCertificateVerifierError.requestFailed
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LearningCertificateVerifierError.requestFailed
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw LearningCertificateVerifierError.badStatusCode(httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(GeminiGenerateContentResponse.self, from: data)
        let text = decoded.outputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw LearningCertificateVerifierError.emptyResponse
        }

        let json = extractJSONObject(from: text)
        guard let raw = json,
              let parsed = try? JSONDecoder().decode(CertificateVerdict.self, from: raw) else {
            throw LearningCertificateVerifierError.invalidJSON
        }

        return buildResult(from: parsed, input: input)
    }

    // MARK: - Request body

    private func requestBody(for input: LearningCertificateVerificationInput) -> [String: Any] {
        let prompt = promptText(for: input)
        let imagePart: [String: Any] = [
            "inlineData": [
                "mimeType": "image/jpeg",
                "data": input.certificateImageData.base64EncodedString()
            ]
        ]
        let textPart: [String: Any] = ["text": prompt]

        return [
            "systemInstruction": [
                "parts": [
                    ["text": systemInstruction(languageCode: input.languageCode)]
                ]
            ],
            "contents": [
                [
                    "role": "user",
                    "parts": [textPart, imagePart]
                ]
            ],
            "generationConfig": [
                "responseMimeType": "application/json",
                "temperature": 0.1,
                "maxOutputTokens": 600
            ]
        ]
    }

    private func systemInstruction(languageCode: String) -> String {
        """
        You are a strict certificate verifier. Look at a provided certificate image and \
        assess whether it is a genuine completion certificate that matches an expected \
        course/provider. Return ONLY a single minified JSON object matching this schema:
        {
          "verdict": "verified" | "rejected" | "pending",
          "confidence": number between 0 and 1,
          "extractedName": string | null,
          "extractedCourseTitle": string | null,
          "extractedProvider": string | null,
          "extractedCertificateURL": string | null,
          "rejectionReason": string | null,
          "notes": string | null
        }

        Rules:
        - "verified" ONLY when the image is clearly a completion certificate AND the course title \
          and provider match the expected values (allow light paraphrasing and localization), AND \
          no fraud flags are detected (screenshot of unrelated page, edited-looking text, \
          language does not indicate completion).
        - "rejected" when mismatched course/provider, missing completion indicator, visible \
          tampering, or image clearly unrelated to a certificate.
        - "pending" only when the image is too unclear to decide.
        - rejectionReason must be a short human-readable explanation when verdict is "rejected" \
          or "pending", otherwise null.
        - Respond in the language code "\(languageCode)" for rejectionReason/notes when possible.
        - Do NOT include any text outside the JSON.
        """
    }

    private func promptText(for input: LearningCertificateVerificationInput) -> String {
        var lines = [
            "Expected course title: \"\(input.expectedCourseTitle)\"",
            "Expected provider: \"\(input.expectedProvider)\"",
            "Certificate URL entered by the user: \"\(input.certificateURLString)\"",
            "Challenge: \"\(input.questTitle)\""
        ]
        if let name = input.userDisplayName, !name.isEmpty {
            lines.append("Expected user name hint (may be partial): \"\(name)\"")
        }
        lines.append("")
        lines.append("""
            Inspect the attached certificate image. Extract any visible fields \
            (user name, course title, provider, completion date, verification URL, verification code). \
            Compare against the expected values. Flag obvious fraud signs. Return the JSON verdict now.
            """)
        return lines.joined(separator: "\n")
    }

    // MARK: - Result assembly

    private func buildResult(
        from verdict: CertificateVerdict,
        input: LearningCertificateVerificationInput
    ) -> LearningProofVerificationResult {
        let normalizedVerdict = verdict.normalizedStatus
        let confidence = verdict.confidence ?? 0
        let minimumAcceptableConfidence = 0.62

        var status: LearningProofVerificationStatus = normalizedVerdict
        var rejectionReason = verdict.rejectionReason

        let titleMatches = LearningMatchHeuristics.fuzzyContains(
            candidate: verdict.extractedCourseTitle,
            expected: input.expectedCourseTitle
        )
        let providerMatches = LearningMatchHeuristics.fuzzyContains(
            candidate: verdict.extractedProvider,
            expected: input.expectedProvider
        )

        if status == .verified {
            if confidence < minimumAcceptableConfidence {
                status = .pending
                rejectionReason = rejectionReason ?? "Low confidence; please resubmit a clearer certificate."
            } else if !(titleMatches && providerMatches) {
                status = .rejected
                rejectionReason = rejectionReason ?? "Course title or provider did not match the expected value."
            }
        }

        return LearningProofVerificationResult(
            status: status,
            confidence: verdict.confidence,
            extractedName: verdict.extractedName,
            extractedCourseTitle: verdict.extractedCourseTitle,
            extractedProvider: verdict.extractedProvider,
            extractedCertificateURL: verdict.extractedCertificateURL ?? input.certificateURLString,
            rejectionReason: rejectionReason,
            notes: verdict.notes
        )
    }

    // MARK: - Helpers

    private func resolvedAPIKey() throws -> String {
        if let key = Bundle.main.object(forInfoDictionaryKey: "CAPTAIN_API_KEY") as? String,
           Self.isValidKey(key) {
            return key
        }
        if let key = ProcessInfo.processInfo.environment["CAPTAIN_API_KEY"],
           Self.isValidKey(key) {
            return key
        }
        throw LearningCertificateVerifierError.missingAPIKey
    }

    private static func isValidKey(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && !trimmed.hasPrefix("$(") && trimmed != "YOUR_API_KEY_HERE"
    }

    private func isNetworkUnavailable(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet,
                 NSURLErrorCannotConnectToHost,
                 NSURLErrorCannotFindHost,
                 NSURLErrorTimedOut,
                 NSURLErrorNetworkConnectionLost:
                return true
            default:
                return false
            }
        }
        return false
    }

    private func extractJSONObject(from raw: String) -> Data? {
        if let data = raw.data(using: .utf8),
           (try? JSONSerialization.jsonObject(with: data)) != nil {
            return data
        }

        // Strip markdown code fences that Gemini may emit in non-JSON mode.
        let cleaned = raw
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let first = cleaned.firstIndex(of: "{"),
           let last = cleaned.lastIndex(of: "}"),
           first < last {
            let slice = String(cleaned[first...last])
            return slice.data(using: .utf8)
        }

        return nil
    }
}

// MARK: - Gemini response decoding

private struct GeminiGenerateContentResponse: Decodable {
    struct Candidate: Decodable {
        struct Content: Decodable {
            struct Part: Decodable {
                let text: String?
            }
            let parts: [Part]?
        }
        let content: Content?
    }

    let candidates: [Candidate]?

    var outputText: String {
        (candidates ?? [])
            .compactMap { $0.content }
            .flatMap { $0.parts ?? [] }
            .compactMap { $0.text }
            .joined()
    }
}

// MARK: - Verdict payload

private struct CertificateVerdict: Decodable {
    let verdict: String?
    let confidence: Double?
    let extractedName: String?
    let extractedCourseTitle: String?
    let extractedProvider: String?
    let extractedCertificateURL: String?
    let rejectionReason: String?
    let notes: String?

    var normalizedStatus: LearningProofVerificationStatus {
        switch verdict?.lowercased() {
        case "verified": return .verified
        case "rejected": return .rejected
        case "pending": return .pending
        default: return .pending
        }
    }
}

// MARK: - Matching heuristics

enum LearningMatchHeuristics {
    static func normalize(_ value: String) -> String {
        let lowered = value.lowercased()
        let filtered = lowered.unicodeScalars.filter {
            CharacterSet.alphanumerics.contains($0) || $0 == " "
        }
        let collapsed = String(String.UnicodeScalarView(filtered))
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return collapsed
    }

    static func fuzzyContains(candidate: String?, expected: String) -> Bool {
        guard let candidate, !candidate.isEmpty else { return false }
        let a = normalize(candidate)
        let b = normalize(expected)
        guard !a.isEmpty, !b.isEmpty else { return false }

        if a.contains(b) || b.contains(a) { return true }

        // Token overlap: at least 60% of expected tokens appear in candidate.
        let candidateTokens = Set(a.split(separator: " ").map(String.init))
        let expectedTokens = b.split(separator: " ").map(String.init)
        guard !expectedTokens.isEmpty else { return false }
        let matched = expectedTokens.filter { candidateTokens.contains($0) }.count
        return Double(matched) / Double(expectedTokens.count) >= 0.6
    }
}
