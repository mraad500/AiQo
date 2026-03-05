import Foundation
import SwiftUI
internal import Combine

enum CaptainPlanChat {
    struct ChatMessage: Identifiable, Equatable {
        let id: UUID
        let text: String
        let isUser: Bool
        let timestamp: Date

        init(
            id: UUID = UUID(),
            text: String,
            isUser: Bool,
            timestamp: Date = Date()
        ) {
            self.id = id
            self.text = text
            self.isUser = isUser
            self.timestamp = timestamp
        }
    }

    @MainActor
    final class CaptainChatViewModel: ObservableObject {
        @Published var messages: [ChatMessage]
        @Published var isCaptainTyping = false
        @Published private(set) var detectedWeight: Double?
        @Published private(set) var detectedGoal: CaptainWorkoutGoal?
        @Published private(set) var shouldShowPinPlanButton = false

        private var responseTask: Task<Void, Never>?

        init() {
            messages = [
                ChatMessage(
                    text: "هلا بطل! أنا كابتن حمّودي. حتى أسويلك خطة تليق بيك وتوصلك للقمة، كلي شقد وزنك الحالي وشنو هدفك؟",
                    isUser: false
                )
            ]
        }

        deinit {
            responseTask?.cancel()
        }

        func sendMessage(_ text: String) {
            let cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanedText.isEmpty else { return }

            messages.append(.init(text: cleanedText, isUser: true))
            isCaptainTyping = true

            responseTask?.cancel()
            responseTask = Task { [weak self] in
                guard let self else { return }
                let reply = await self.generateAppleIntelligenceResponse(for: cleanedText)
                guard !Task.isCancelled else { return }
                self.messages.append(.init(text: reply, isUser: false))
                self.isCaptainTyping = false
            }
        }

        func generateAppleIntelligenceResponse(for userText: String) async -> String {
            try? await Task.sleep(nanoseconds: 1_000_000_000)

            let normalized = normalizeUserText(userText)

            if detectedWeight == nil, let extractedWeight = extractWeight(from: normalized) {
                detectedWeight = extractedWeight
            }

            if detectedGoal == nil, let extractedGoal = extractGoal(from: normalized) {
                detectedGoal = extractedGoal
            }

            if let weight = detectedWeight, let goal = detectedGoal {
                shouldShowPinPlanButton = true

                if containsAgreement(in: normalized) {
                    return "تمام بطل، كلشي صار جاهز. اضغط زر «موافق، ثبّت الخطة بالجدول» وأنا أثبتها فوراً."
                }

                if asksForPlanDetails(in: normalized) {
                    return "حلو! رتبتلك بداية الخطة: \(goal.suggestedWorkouts[0])، وبعدها \(goal.suggestedWorkouts[1]). إذا موافق اضغط زر التثبيت."
                }

                return "عاشت إيدك. سجّلت وزنك \(formattedWeight(weight)) كغم وهدفك \(goal.title). جهزتلك خطة على هذا الأساس، إذا موافق اضغط «موافق، ثبّت الخطة بالجدول»."
            }

            if detectedWeight == nil {
                return "حبيبي حتى أضبطها مضبوط، اكتب وزنك الحالي بالأرقام (مثال: 78)."
            }

            if detectedGoal == nil {
                return "تمام بطل، سجّلت وزنك \(formattedWeight(detectedWeight ?? 0)) كغم. هسه كلي هدفك: تنشيف، تضخيم عضل، لو لياقة عامة؟"
            }

            return "تمام، كمل وياي خطوة بخطوة حتى أثبتلك الخطة."
        }

        func markPlanPinned() {
            shouldShowPinPlanButton = false
            messages.append(
                .init(
                    text: "ممتاز بطل، ثبتتلك الخطة بالجدول اليومي. راح أظل أتابع تقدمك.",
                    isUser: false
                )
            )
        }

        private func normalizeUserText(_ text: String) -> String {
            let lowercased = text.lowercased()
            let arabicToLatinDigits: [Character: Character] = [
                "٠": "0", "١": "1", "٢": "2", "٣": "3", "٤": "4",
                "٥": "5", "٦": "6", "٧": "7", "٨": "8", "٩": "9",
                "٫": ".", "٬": "."
            ]

            return String(lowercased.map { arabicToLatinDigits[$0] ?? $0 })
        }

        private func extractWeight(from text: String) -> Double? {
            guard let regex = try? NSRegularExpression(pattern: #"\d+(?:\.\d+)?"#) else {
                return nil
            }

            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            let matches = regex.matches(in: text, range: range)

            for match in matches {
                guard let valueRange = Range(match.range, in: text) else { continue }
                let candidate = String(text[valueRange])
                guard let value = Double(candidate), (30...250).contains(value) else { continue }
                return value
            }

            return nil
        }

        private func extractGoal(from text: String) -> CaptainWorkoutGoal? {
            if text.contains("تنشيف") || text.contains("تنزيل") || text.contains("دهون") || text.contains("نزول وزن") {
                return .loseWeight
            }

            if text.contains("عضل") || text.contains("تضخيم") || text.contains("ضخامة") || text.contains("muscle") {
                return .buildMuscle
            }

            if text.contains("لياقة") || text.contains("fitness") || text.contains("نشاط") || text.contains("صحة") {
                return .fitness
            }

            return nil
        }

        private func containsAgreement(in text: String) -> Bool {
            let terms = [
                "موافق", "وافق", "تمام", "يلا", "امشي", "ثبّت", "ثبت", "ok", "okay", "yes"
            ]
            return terms.contains { text.contains($0) }
        }

        private func asksForPlanDetails(in text: String) -> Bool {
            let terms = [
                "شنو الخطة", "شنو البرنامج", "اصيل الخطة", "تفاصيل", "plan", "details"
            ]
            return terms.contains { text.contains($0) }
        }

        private func formattedWeight(_ weight: Double) -> String {
            if weight == floor(weight) {
                return String(Int(weight))
            }
            return String(format: "%.1f", weight)
        }
    }
}
