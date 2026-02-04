import Foundation

public struct CommandAck: Codable {
    public let originalMessageId: String // معرف الرسالة التي نرد عليها
    public let success: Bool
    public let errorMessage: String?
    
    public init(id: String, success: Bool, error: String? = nil) {
        self.originalMessageId = id
        self.success = success
        self.errorMessage = error
    }
}
