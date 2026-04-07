import Foundation
import os.log

/// يستخرج المعلومات من محادثة الكابتن ويحفظها بالذاكرة
struct MemoryExtractor: Sendable {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "AiQo",
        category: "MemoryExtractor"
    )

    /// عداد الرسائل لتحديد متى نستخدم LLM
    private static let llmExtractionInterval = 3

    // MARK: - استخراج رئيسي

    /// يستخرج الذكريات من رسالة المستخدم ورد الكابتن
    @MainActor
    static func extract(
        userMessage: String,
        assistantReply: String,
        store: MemoryStore,
        messageCount: Int
    ) async {
        guard store.isEnabled else { return }

        // A) Rule-based extraction — سريع ومجاني
        extractWithRules(userMessage: userMessage, store: store)

        // B) LLM extraction — كل 3 رسائل
        if messageCount % llmExtractionInterval == 0 {
            await extractWithLLM(
                userMessage: userMessage,
                assistantReply: assistantReply,
                store: store
            )
        }
    }

    // MARK: - Rule-based Extraction

    @MainActor
    private static func extractWithRules(userMessage: String, store: MemoryStore) {
        let text = userMessage

        // الوزن
        if let match = text.range(of: #"(\d{2,3})\s*(كيلو|كغم|kg)"#, options: .regularExpression) {
            let numberRange = text[match].range(of: #"\d{2,3}"#, options: .regularExpression)
            if let numberRange {
                let weight = String(text[numberRange])
                store.set("weight", value: weight, category: "body", source: "extracted")
            }
        }

        // Weight (English)
        if let match = text.range(of: #"(?:weigh|weight)\s*(?:is\s*)?(\d{2,3})\s*(?:kg|kilos?|lbs?|pounds?)?"#, options: [.regularExpression, .caseInsensitive]) {
            let numberRange = text[match].range(of: #"\d{2,3}"#, options: .regularExpression)
            if let numberRange {
                let weight = String(text[numberRange])
                store.set("weight", value: weight, category: "body", source: "extracted")
            }
        }

        // الطول
        if let match = text.range(of: #"(\d{2,3})\s*(سم|cm)"#, options: .regularExpression) {
            let numberRange = text[match].range(of: #"\d{2,3}"#, options: .regularExpression)
            if let numberRange {
                let height = String(text[numberRange])
                store.set("height", value: height, category: "body", source: "extracted")
            }
        }

        // Height (English)
        if let match = text.range(of: #"(\d{2,3})\s*(?:cm|centimeters?)\s*(?:tall)?"#, options: [.regularExpression, .caseInsensitive]) {
            let numberRange = text[match].range(of: #"\d{2,3}"#, options: .regularExpression)
            if let numberRange {
                let height = String(text[numberRange])
                store.set("height", value: height, category: "body", source: "extracted")
            }
        }

        // العمر
        if let match = text.range(of: #"(عمري|عندي)\s*(\d{1,2})\s*(سنة|سنه)"#, options: .regularExpression) {
            let numberRange = text[match].range(of: #"\d{1,2}"#, options: .regularExpression)
            if let numberRange {
                let age = String(text[numberRange])
                store.set("age", value: age, category: "identity", source: "extracted")
            }
        }

        // Age (English)
        if let match = text.range(of: #"(?:i'?m|i am|age)\s*(\d{1,2})\s*(?:years?\s*old)?"#, options: [.regularExpression, .caseInsensitive]) {
            let numberRange = text[match].range(of: #"\d{1,2}"#, options: .regularExpression)
            if let numberRange {
                let age = String(text[numberRange])
                store.set("age", value: age, category: "identity", source: "extracted")
            }
        }

        // إصابة
        let injuryKeywords = ["ركبتي", "ظهري", "كتفي", "رقبتي", "إصابة", "ألم", "عملية", "مفصل"]
        for keyword in injuryKeywords {
            if text.contains(keyword) {
                let sentence = extractSentenceContaining(keyword: keyword, in: text)
                store.set("injury_\(keyword)", value: sentence, category: "injury", source: "extracted")
                break
            }
        }

        // Injury (English)
        let englishInjuryKeywords = ["knee", "back", "shoulder", "neck", "injury", "pain", "surgery", "joint"]
        for keyword in englishInjuryKeywords {
            if text.localizedCaseInsensitiveContains(keyword) {
                let sentence = extractSentenceContaining(keyword: keyword, in: text)
                store.set("injury_\(keyword)", value: sentence, category: "injury", source: "extracted")
                break
            }
        }

        // هدف
        let goalPatterns = [
            (#"(أبي|أريد|أبغى|هدفي|ودّي|ودي)\s*.{0,30}(تنشيف|تضخيم|نزول وزن|زيادة وزن|عضل|كارديو|مرونة)"#, "goal"),
        ]
        for (pattern, key) in goalPatterns {
            if let match = text.range(of: pattern, options: .regularExpression) {
                store.set(key, value: String(text[match]), category: "goal", source: "extracted")
            }
        }

        // Goal (English)
        let englishGoalPatterns = [
            (#"(?:i want to|my goal is|trying to|i need to)\s*.{0,30}(?:lose weight|build muscle|gain weight|get lean|bulk|cut|cardio|flexibility|endurance)"#, "goal"),
        ]
        for (pattern, key) in englishGoalPatterns {
            if let match = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                store.set(key, value: String(text[match]), category: "goal", source: "extracted")
            }
        }

        // نوم
        if let match = text.range(of: #"(\d{1,2})\s*(ساعة|ساعات)\s*(نوم)?"#, options: .regularExpression) {
            let numberRange = text[match].range(of: #"\d{1,2}"#, options: .regularExpression)
            if let numberRange {
                let hours = String(text[numberRange])
                store.set("sleep_hours", value: hours, category: "sleep", source: "extracted")
            }
        }

        // الاسم — إذا قال "اسمي X" أو "أنا X"
        let namePatterns = [#"اسمي\s+(\S+)"#, #"أنا\s+(\S+)"#, #"نادني\s+(\S+)"#]
        for pattern in namePatterns {
            if let match = text.range(of: pattern, options: .regularExpression) {
                let fullMatch = String(text[match])
                let parts = fullMatch.split(separator: " ")
                if parts.count >= 2 {
                    let name = String(parts[1])
                    // لا تكتب فوق اسم explicit
                    let existing = store.get("user_name")
                    if existing == nil {
                        store.set("user_name", value: name, category: "identity", source: "extracted")
                    }
                }
            }
        }

        // Name (English)
        let englishNamePatterns = [#"(?:my name is|i'?m|call me)\s+(\w+)"#]
        for pattern in englishNamePatterns {
            if let match = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                let fullMatch = String(text[match])
                let parts = fullMatch.split(separator: " ")
                if let lastName = parts.last {
                    let name = String(lastName)
                    let existing = store.get("user_name")
                    if existing == nil {
                        store.set("user_name", value: name, category: "identity", source: "extracted")
                    }
                }
            }
        }
    }

    // MARK: - LLM Extraction

    private static func extractWithLLM(
        userMessage: String,
        assistantReply: String,
        store: MemoryStore
    ) async {
        // Privacy-first: sanitize all outgoing text before it leaves the device
        let sanitizer = PrivacySanitizer()
        let sanitizedUserMessage = sanitizer.sanitizeText(userMessage, knownUserName: nil)
        let compactUserMessage = compactSanitizedSnippet(sanitizedUserMessage, limit: 240)
        guard !compactUserMessage.isEmpty else { return }

        let allowedKeys = [
            "user_name", "goal", "weight", "height", "age", "injury", "mood",
            "preferred_workout", "diet_preference", "sleep_hours",
            "fitness_level", "workout_feedback", "available_equipment",
            "training_days", "medical_condition", "water_intake",
            "record_project_feedback"
        ]
        let systemPrompt = "Extract only new durable user facts from the sanitized message. Return a flat JSON object with allowed keys only, or {}."

        let userContent = compactJSONString(
            from: [
                "allowed_keys": allowedKeys,
                "user_message": compactUserMessage
            ]
        )

        do {
            let config = try resolveLLMConfig()
            var request = URLRequest(url: config.endpointURL)
            request.httpMethod = "POST"
            request.timeoutInterval = 15
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let body: [String: Any] = [
                "systemInstruction": [
                    "parts": [["text": systemPrompt]]
                ],
                "contents": [
                    [
                        "role": "user",
                        "parts": [["text": userContent]]
                    ]
                ],
                "generationConfig": [
                    "maxOutputTokens": 160,
                    "temperature": 0.1,
                    "responseMimeType": "application/json"
                ]
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                logger.warning("memory_extractor_llm bad status")
                return
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let candidates = json["candidates"] as? [[String: Any]],
                  let firstCandidate = candidates.first,
                  let candidateContent = firstCandidate["content"] as? [String: Any],
                  let parts = candidateContent["parts"] as? [[String: Any]],
                  let content = parts.first?["text"] as? String else {
                return
            }

            // Parse JSON response
            let cleanContent = content
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard let contentData = cleanContent.data(using: .utf8),
                  let extracted = try JSONSerialization.jsonObject(with: contentData) as? [String: String] else {
                return
            }

            let categoryMap: [String: String] = [
                "user_name": "identity", "goal": "goal", "weight": "body",
                "height": "body", "age": "identity", "injury": "injury",
                "mood": "mood", "preferred_workout": "preference",
                "diet_preference": "nutrition", "sleep_hours": "sleep",
                "fitness_level": "body", "workout_feedback": "insight",
                "available_equipment": "preference", "training_days": "preference",
                "medical_condition": "injury", "water_intake": "nutrition",
                "record_project_feedback": "active_record_project"
            ]

            await MainActor.run {
                for (key, value) in extracted {
                    guard let category = categoryMap[key], !value.isEmpty else { continue }
                    store.set(key, value: value, category: category, source: "llm_extracted", confidence: 0.8)
                }
            }

            logger.info("memory_extractor_llm extracted=\(extracted.count) keys")
        } catch {
            logger.warning("memory_extractor_llm_error error=\(error.localizedDescription)")
        }
    }

    // MARK: - Helpers

    private static func extractSentenceContaining(keyword: String, in text: String) -> String {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".،!؟\n"))
        return sentences.first(where: { $0.contains(keyword) })?.trimmingCharacters(in: .whitespaces) ?? keyword
    }

    private struct LLMConfig {
        let endpointURL: URL
        let apiKey: String
    }

    private static func resolveLLMConfig() throws -> LLMConfig {
        let info = Bundle.main.infoDictionary ?? [:]
        let env = ProcessInfo.processInfo.environment

        let apiKey = normalized(env["CAPTAIN_API_KEY"])
            ?? normalized(info["CAPTAIN_API_KEY"] as? String)
            ?? normalized(env["COACH_BRAIN_LLM_API_KEY"])
            ?? normalized(info["COACH_BRAIN_LLM_API_KEY"] as? String)

        guard let apiKey else {
            throw URLError(.userAuthenticationRequired)
        }
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent?key=\(apiKey)") else {
            throw URLError(.badURL)
        }

        return LLMConfig(endpointURL: url, apiKey: apiKey)
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !(trimmed.hasPrefix("$(") && trimmed.hasSuffix(")")) else { return nil }
        return trimmed
    }

    private static func compactSanitizedSnippet(_ text: String, limit: Int) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        return String(trimmed.prefix(limit))
    }

    private static func compactJSONString(from value: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }
}
