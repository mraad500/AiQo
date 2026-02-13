import Foundation

enum L10n {

    // نصوص
    static func t(_ key: String, _ comment: String = "") -> String {
        NSLocalizedString(key, comment: comment)
    }

    // أرقام Int (خطوات، عدّات...)
    static func num<T: BinaryInteger>(_ n: T) -> String {
        let fmt = NumberFormatter()
        fmt.locale = .current
        fmt.numberStyle = .decimal
        return fmt.string(from: NSNumber(value: Int(n))) ?? "\(n)"
    }

    // أرقام Double (سعرات، ماء...)
    static func num(_ n: Double) -> String {
        let fmt = NumberFormatter()
        fmt.locale = .current
        fmt.maximumFractionDigits = 0
        return fmt.string(from: NSNumber(value: n)) ?? "\(Int(n))"
    }
}
