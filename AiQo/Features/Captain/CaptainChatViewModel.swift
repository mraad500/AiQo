import Foundation
import os.log
import SwiftUI
internal import Combine

struct CaptainChatEntry: Identifiable, Equatable, Sendable {
    enum Sender: String, Sendable {
        case user
        case captain
    }

    let id: UUID
    let sender: Sender
    let text: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        sender: Sender,
        text: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sender = sender
        self.text = text
        self.createdAt = createdAt
    }
}

@MainActor
final class CaptainChatViewModel: ObservableObject {
    @Published var chatHistory: [CaptainChatEntry]
    @Published var inputText: String = ""
    @Published var isGeneratingResponse: Bool = false
    @Published var lastErrorMessage: String?

    private let intelligenceManager: CaptainIntelligenceManager
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "AiQo",
        category: "CaptainChat"
    )

    private var responseTask: Task<Void, Never>?
    private var activeRequestID: UUID?

    init(intelligenceManager: CaptainIntelligenceManager? = nil) {
        self.intelligenceManager = intelligenceManager ?? .shared
        self.chatHistory = [
            CaptainChatEntry(
                sender: .captain,
                text: "هلا! أنا كابتن حمّودي. اكتبلي هدفك اليوم ونبدي خطوة خطوة."
            )
        ]

        // Warm-up permissions to reduce first-response latency.
        Task {
            try? await self.intelligenceManager.requestHealthPermissions()
        }
    }

    func sendMessage() {
        sendMessage(inputText)
    }

    func sendMessage(_ rawText: String) {
        let message = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }

        inputText = ""
        lastErrorMessage = nil
        appendMessage(sender: .user, text: message)

        responseTask?.cancel()
        isGeneratingResponse = true

        let requestID = UUID()
        activeRequestID = requestID

        responseTask = Task { [weak self] in
            guard let self else { return }
            await self.generateReply(for: message, requestID: requestID)
        }
    }

    func requestHealthAccess() {
        Task {
            do {
                try await intelligenceManager.requestHealthPermissions()
            } catch {
                logger.error("HealthKit authorization failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func generateReply(for userMessage: String, requestID: UUID) async {
        defer {
            if activeRequestID == requestID {
                isGeneratingResponse = false
            }
        }

        do {
            let captainReply = try await intelligenceManager.generateCaptainResponse(for: userMessage)
            guard !Task.isCancelled, activeRequestID == requestID else { return }
            appendMessage(sender: .captain, text: captainReply)
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled, activeRequestID == requestID else { return }

            lastErrorMessage = error.localizedDescription
            appendMessage(sender: .captain, text: fallbackMessage(for: error))
            logger.error("Captain local generation failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func appendMessage(sender: CaptainChatEntry.Sender, text: String) {
        chatHistory.append(CaptainChatEntry(sender: sender, text: text))
    }

    private func fallbackMessage(for error: Error) -> String {
        if let captainError = error as? CaptainIntelligenceError {
            switch captainError {
            case .healthAuthorizationDenied:
                return "فعّل صلاحية Health وبعدها أضبطلك الخطة بدقة. هسه نبدأ بـ 10 دقايق مشي سريع وكوب مي."
            case .onDeviceModelUnavailable, .foundationModelsUnavailable:
                return "ميزة Apple Intelligence مو متاحة حالياً على هذا الجهاز. خلّينا نمشي 12 دقيقة ونرجع نقيم."
            case .unsupportedDeviceLanguage:
                return "لغة الجهاز الحالية غير مدعومة حالياً. غيّر اللغة أو اكتبلي بالعربي/الإنجليزي."
            default:
                return "صار خلل بسيط محلياً. سوي 3 جولات: 20 سكوات + 10 ضغط + 40 ثانية بلانك، وبعدها راسلني."
            }
        }

        return "صار خلل غير متوقع. سوي مشي خفيف 10-15 دقيقة، اشرب مي، وارجع ابعتلي."
    }
}
