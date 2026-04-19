// ===============================================
// File: SentimentDetector.swift
// Phase 1 — Captain Hamoudi Brain V2
// Lightweight Arabic + English keyword-based
// sentiment detection. No ML. No network calls.
// ===============================================

import Foundation

// MARK: - Models

enum MessageSentiment: String, Codable, Sendable {
    case positive
    case negative
    case neutral
    case question
}

struct SentimentResult: Codable, Sendable {
    let sentiment: MessageSentiment
    let confidence: Double
    let detectedKeywords: [String]
}

// MARK: - Detector

final class SentimentDetector: Sendable {

    nonisolated static let shared = SentimentDetector()
    nonisolated private init() {}

    // MARK: - Keyword Lists

    nonisolated private static let questionKeywords: [String] = [
        // Arabic
        "\u{061F}", "شلون", "شنو", "ليش", "متى", "وين", "شكد", "هل", "كيف", "شگد",
        // English
        "?", "how", "what", "why", "when", "where", "should", "can i", "do i"
    ]

    nonisolated private static let positiveKeywords: [String] = [
        // Arabic
        "حلو", "زين", "تمام", "ممتاز", "يسلمو", "الحمدلله", "خوش", "احسن",
        "فرحان", "مبسوط", "نشيط", "حماس", "يلا", "شكراً", "ماشاءالله",
        // Emoji
        "💪", "🔥", "❤️", "😊", "👍", "🎉",
        // English
        "great", "good", "awesome", "thanks", "happy", "love", "amazing", "perfect", "nice"
    ]

    nonisolated private static let negativeKeywords: [String] = [
        // Arabic
        "تعبان", "مريض", "ملّيت", "زهگت", "ما اكدر", "صعب", "مو بمزاج", "كسلان",
        "ما رديت", "خايف", "قلقان", "ما نمت", "ضغط", "مضايق",
        // Emoji
        "😔", "😢", "😞", "😩", "😤",
        // English
        "tired", "sick", "bored", "can't", "hard", "hate", "bad", "sad", "stressed",
        "exhausted", "pain"
    ]

    // MARK: - Detection

    nonisolated func detect(message: String) -> SentimentResult {
        let normalized = message.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else {
            return SentimentResult(sentiment: .neutral, confidence: 0.3, detectedKeywords: [])
        }

        // Check for question first
        for keyword in Self.questionKeywords {
            if normalized.contains(keyword) {
                return SentimentResult(
                    sentiment: .question,
                    confidence: 0.85,
                    detectedKeywords: [keyword]
                )
            }
        }

        // Count positive and negative matches
        var matchedPositive: [String] = []
        var matchedNegative: [String] = []

        for keyword in Self.positiveKeywords {
            if normalized.contains(keyword) {
                matchedPositive.append(keyword)
            }
        }

        for keyword in Self.negativeKeywords {
            if normalized.contains(keyword) {
                matchedNegative.append(keyword)
            }
        }

        let positiveScore = matchedPositive.count
        let negativeScore = matchedNegative.count
        let allMatched = matchedPositive + matchedNegative

        // Determine sentiment
        let sentiment: MessageSentiment
        if positiveScore > negativeScore {
            sentiment = .positive
        } else if negativeScore > positiveScore {
            sentiment = .negative
        } else {
            sentiment = .neutral
        }

        // Confidence
        let totalMatches = positiveScore + negativeScore
        var confidence: Double
        if totalMatches == 0 {
            confidence = 0.3
        } else {
            confidence = 0.5 + Double(totalMatches) * 0.1
            confidence = min(confidence, 0.9)
        }

        return SentimentResult(
            sentiment: sentiment,
            confidence: confidence,
            detectedKeywords: allMatched
        )
    }
}
