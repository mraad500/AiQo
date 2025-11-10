import Foundation

enum Logger {
    static func bootstrap() {
        print("🔧 Logger bootstrapped")
    }
    static func info(_ msg: String) { print("ℹ️ \(msg)") }
    static func error(_ msg: String) { print("❌ \(msg)") }
}
