import Foundation

enum AiQoLog {
    static func bootstrap() {
        print("AiQoLog bootstrapped")
    }

    static func info(_ msg: String) { print("ℹ️ \(msg)") }
    static func error(_ msg: String) { print("❌ \(msg)") }
}
