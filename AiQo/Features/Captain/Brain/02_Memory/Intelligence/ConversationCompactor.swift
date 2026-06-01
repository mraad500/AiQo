import Foundation

/// A faithful, bounded, structured snapshot of the part of the CURRENT chat
/// session that no longer fits in the verbatim model window.
///
/// Every line is extracted or clipped from something the user or the Captain
/// actually said — the digest never *generates* prose, so it can never
/// introduce a fact that wasn't in the conversation. That is the whole point:
/// it is the anti-hallucination spine. When the live window slides forward, the
/// head of the conversation is preserved here as grounded state instead of
/// silently disappearing (which is what makes a long chat "forget" and then
/// fabricate to fill the gap).
///
/// This is deliberately NOT an LLM summary. An LLM summary of a long chat can
/// itself hallucinate, and it costs a round-trip on the hot path. A
/// deterministic extractive digest is both safer and free.
struct ConversationDigest: Codable, Sendable, Equatable {
    /// The first real thing the user asked for this session — anchors purpose.
    var openingIntent: String?
    /// Durable things the user stated or requested (deduped, recency-ordered).
    var userPoints: [String]
    /// Concrete things the Captain already did / promised (plans built,
    /// reminders set, advice given) so a later reply never contradicts or
    /// re-offers them — the #1 source of "the Captain repeats itself".
    var captainCommitments: [String]
    /// Explicit corrections ("no, I meant…") — highest priority, never dropped
    /// before user points, because a stale wrong fact is the worst failure.
    var corrections: [String]
    /// The freshest user→Captain exchange just before the window — a smooth seam
    /// so the model doesn't feel an abrupt cut between digest and live window.
    var lastExchange: String?
    /// How many messages this digest stands in for (telemetry + threshold UI).
    var coveredMessageCount: Int

    static let empty = ConversationDigest(
        openingIntent: nil,
        userPoints: [],
        captainCommitments: [],
        corrections: [],
        lastExchange: nil,
        coveredMessageCount: 0
    )

    var isEmpty: Bool {
        openingIntent == nil
            && userPoints.isEmpty
            && captainCommitments.isEmpty
            && corrections.isEmpty
            && lastExchange == nil
    }

    /// Renders the digest as the `[conversation_state]` prompt block in the
    /// user's language, or `nil` when empty. Pure formatting — introduces no new
    /// facts. Carries its own grounding lock so the rule travels with the data.
    func renderedBlock(language: AppLanguage) -> String? {
        guard !isEmpty else { return nil }
        return language == .english ? renderEnglish() : renderArabic()
    }

    private func renderArabic() -> String {
        var parts: [String] = []
        parts.append("[conversation_state] — ملخّص أمين لأول هالمحادثة (انضغط حتى ما تننسى، كله من كلام صار فعلاً)")

        if let openingIntent {
            parts.append("• هدف البداية: \(openingIntent)")
        }
        if !corrections.isEmpty {
            parts.append("• تصحيحات المستخدم (هاي تتغلب على أي معلومة أقدم تعارضها):\n"
                + corrections.map { "  - \($0)" }.joined(separator: "\n"))
        }
        if !userPoints.isEmpty {
            parts.append("• نقاط ذكرها أو طلبها المستخدم:\n"
                + userPoints.map { "  - \($0)" }.joined(separator: "\n"))
        }
        if !captainCommitments.isEmpty {
            parts.append("• أشياء انت (الكابتن) سويتها أو وعدت بيها سابقاً — لا تناقضها ولا تكررها من الصفر:\n"
                + captainCommitments.map { "  - \($0)" }.joined(separator: "\n"))
        }
        if let lastExchange {
            parts.append("• آخر تبادل قبل هالجزء:\n\(lastExchange)")
        }

        parts.append(
            """
            ⚠️ تأريض (مهم): كل اللي تعرفه عن أول هالمحادثة موجود فوق + بالرسائل الأخيرة الظاهرة. \
            أي تفصيل (رقم، اسم، تاريخ، خطة وعدت بيها) مو موجود بأي واحد منهم — لا تخترعه أبداً: \
            إما اسأل المستخدم بسطر قصير، أو خلّي ردك عام. كمّل الخيط بطبيعية، لا تبدأ من الصفر، \
            ولا تقول "ما أتذكر".
            """
        )
        return parts.joined(separator: "\n")
    }

    private func renderEnglish() -> String {
        var parts: [String] = []
        parts.append("[conversation_state] — faithful summary of the earlier part of THIS chat (compacted, all from things actually said)")

        if let openingIntent {
            parts.append("• Opening goal: \(openingIntent)")
        }
        if !corrections.isEmpty {
            parts.append("• User corrections (these override any older conflicting detail):\n"
                + corrections.map { "  - \($0)" }.joined(separator: "\n"))
        }
        if !userPoints.isEmpty {
            parts.append("• Points the user made or asked for:\n"
                + userPoints.map { "  - \($0)" }.joined(separator: "\n"))
        }
        if !captainCommitments.isEmpty {
            parts.append("• Things you (the Captain) already did or promised — do NOT contradict or re-offer them:\n"
                + captainCommitments.map { "  - \($0)" }.joined(separator: "\n"))
        }
        if let lastExchange {
            parts.append("• Last exchange before this section:\n\(lastExchange)")
        }

        parts.append(
            """
            ⚠️ GROUNDING (important): everything you know about the earlier part of this chat is above \
            plus the recent visible messages. If a detail (a number, a name, a date, a plan you promised) \
            is in NEITHER, do NOT invent it — either ask the user in one short line or keep the reply general. \
            Continue the thread naturally, never restart, and never say "I don't remember".
            """
        )
        return parts.joined(separator: "\n")
    }
}

/// Builds and rolls forward a `ConversationDigest` from real chat messages.
///
/// Stateless + deterministic. The view model calls `compact` each turn with the
/// messages that have fallen outside the verbatim window plus the digest it has
/// accumulated so far (the part already evicted from memory), so the merged
/// result always covers the entire head of the conversation with zero loss.
enum ConversationCompactor {

    // Tuning — bounded so the prompt stays lean even on a marathon session.
    static let maxUserPoints = 8
    static let maxCommitments = 6
    static let maxCorrections = 4
    static let lineClip = 150
    /// User turns shorter than this and made only of greetings/acks carry no
    /// durable signal and are skipped (a correction marker overrides this).
    static let minSignalLength = 6

    /// Merges `priorDigest` (already-compacted, evicted head) with the freshly
    /// dropped messages (oldest → newest) into one bounded digest.
    static func compact(
        droppedMessages: [ChatMessage],
        priorDigest: ConversationDigest?
    ) -> ConversationDigest {
        var digest = priorDigest ?? .empty

        let usable = droppedMessages.filter { msg in
            !msg.isEphemeral
                && !msg.isSystemNote
                && !msg.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard !usable.isEmpty else { return digest }

        var userPoints = digest.userPoints
        var commitments = digest.captainCommitments
        var corrections = digest.corrections

        for msg in usable {
            let clipped = clip(msg.text)
            guard !clipped.isEmpty else { continue }

            if msg.isUser {
                if digest.openingIntent == nil, isSignal(msg.text) {
                    digest.openingIntent = clipped
                    continue
                }
                if containsAny(msg.text, markers: Self.correctionMarkers) {
                    corrections.append(clipped)
                } else if isSignal(msg.text) {
                    userPoints.append(clipped)
                }
            } else if containsAny(msg.text, markers: Self.commitmentMarkers) {
                commitments.append(clipped)
            }
        }

        digest.userPoints = dedupedSuffix(userPoints, cap: maxUserPoints)
        digest.captainCommitments = dedupedSuffix(commitments, cap: maxCommitments)
        digest.corrections = dedupedSuffix(corrections, cap: maxCorrections)
        digest.lastExchange = buildLastExchange(from: usable) ?? digest.lastExchange
        digest.coveredMessageCount += usable.count

        return digest
    }

    // MARK: - Extraction helpers

    /// True when a user turn carries durable signal (not a bare greeting/ack).
    private static func isSignal(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= minSignalLength else { return false }
        let normalized = normalize(trimmed)
        // Pure greeting/ack with nothing else → no signal.
        return !Self.lowSignalPhrases.contains(normalized)
    }

    /// Most recent `cap` entries, deduped on a normalized key, order preserved.
    private static func dedupedSuffix(_ lines: [String], cap: Int) -> [String] {
        var seen = Set<String>()
        var unique: [String] = []
        for line in lines {
            let key = normalize(line)
            guard !key.isEmpty, seen.insert(key).inserted else { continue }
            unique.append(line)
        }
        return unique.count > cap ? Array(unique.suffix(cap)) : unique
    }

    /// Compact "user said X → Captain replied Y" seam from the freshest pair.
    private static func buildLastExchange(from messages: [ChatMessage]) -> String? {
        let lastUser = messages.last(where: { $0.isUser }).map { clip($0.text) }
        let lastCaptain = messages.last(where: { !$0.isUser }).map { clip($0.text) }
        switch (lastUser, lastCaptain) {
        case let (user?, captain?):
            return "  المستخدم: \(user)\n  الكابتن: \(captain)"
        case let (user?, nil):
            return "  المستخدم: \(user)"
        case let (nil, captain?):
            return "  الكابتن: \(captain)"
        default:
            return nil
        }
    }

    private static func clip(_ text: String) -> String {
        let collapsed = text
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard collapsed.count > lineClip else { return collapsed }
        return String(collapsed.prefix(lineClip)).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }

    private static func normalize(_ text: String) -> String {
        text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: "ـ", with: "")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private static func containsAny(_ text: String, markers: [String]) -> Bool {
        let normalized = normalize(text)
        return markers.contains { normalized.contains($0) }
    }

    // MARK: - Marker sets (normalized: diacritic-folded, tatweel-stripped, lowercased)

    /// Phrases that signal the user is correcting an earlier statement. Kept as
    /// multi-word phrases (not bare "no"/"مو") to avoid false positives on
    /// ordinary negation.
    private static let correctionMarkers: [String] = [
        "قصدي", "اقصد", "أقصد", "مو هيك", "مو هذا", "غلط", "بدل ما", "بدّل",
        "صح هو", "صحح", "تصحيح", "لا مو", "لا قصدي", "خطأ", "مو صح",
        "i meant", "i mean", "actually", "correction", "instead of",
        "not what i", "thats wrong", "that's wrong", "my mistake", "to be clear"
    ]

    /// Phrases that signal the Captain made a concrete commitment worth keeping.
    private static let commitmentMarkers: [String] = [
        "رتبتلك", "سويتلك", "جهزتلك", "بنيتلك", "حطيتلك", "اقترحلك", "نصيحتي",
        "راح اذكرك", "راح أذكرك", "ذكرتك", "دزيتلك", "حفظت", "خليته ببالي",
        "خطتك", "خطة", "اعطيتك", "عطيتك",
        "i built", "i set", "i'll remind", "ill remind", "i saved", "i scheduled",
        "here is your", "here's your", "your plan", "i recommend", "i suggest",
        "i prepared", "i put together"
    ]

    /// Greeting/ack-only user turns that should not be stored as durable points.
    private static let lowSignalPhrases: Set<String> = [
        "هلا", "هلو", "اهلا", "أهلا", "مرحبا", "السلام عليكم", "صباح الخير",
        "مساء الخير", "شلونك", "زين", "تمام", "ماشي", "اوكي", "اوك", "اي",
        "نعم", "لا", "شكرا", "مشكور", "عاشت ايدك", "ok", "okay", "yes", "no",
        "yeah", "thanks", "thank you", "hi", "hello", "hey", "good morning",
        "cool", "great", "nice", "sure"
    ]
}
