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

    private let chatEngine: CaptainOnDeviceChatEngine
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "AiQo",
        category: "CaptainChat"
    )

    private var responseTask: Task<Void, Never>?
    private var activeRequestID: UUID?

    init(chatEngine: CaptainOnDeviceChatEngine = CaptainOnDeviceChatEngine()) {
        self.chatEngine = chatEngine
        self.chatHistory = [
            CaptainChatEntry(
                sender: .captain,
                text: "هلا! أنا كابتن حمّودي. اكتبلي هدفك اليوم ونبدي خطوة خطوة."
            )
        ]
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

    private func generateReply(for userMessage: String, requestID: UUID) async {
        defer {
            if activeRequestID == requestID {
                isGeneratingResponse = false
            }
        }

        do {
            let captainReply = try await chatEngine.respond(to: userMessage)
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
        if let chatError = error as? CaptainOnDeviceChatError {
            switch chatError {
            case .modelUnavailable, .foundationModelsUnavailable:
                return "يا بطل، Apple Intelligence مو جاهز هسه على هذا الجهاز. جرّب بعد شوي."
            case .unsupportedLanguageOrLocale:
                return "يا بطل، لغة الجهاز أو الإعدادات الحالية مو مدعومة هسه. جرّب بعد تعديل اللغة."
            case .emptyResponse:
                return "يا بطل، الرد طلع فارغ. عيدها مرة ثانية وأنا أجاوبك بسرعة."
            }
        }

        return "يا بطل، صار خلل بسيط محلياً. لا تشيل هم، جرّب بعد شوي."
    }
}
