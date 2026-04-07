import Foundation

extension Int {
    /// Returns Eastern Arabic numerals (٠١٢٣٤٥٦٧٨٩) when Arabic mode is active.
    var arabicFormatted: String {
        guard AppSettingsStore.shared.appLanguage == .arabic else {
            return formatted(.number.locale(.autoupdatingCurrent))
        }
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "ar_AE")
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

extension Double {
    /// Returns Eastern Arabic numerals (٠١٢٣٤٥٦٧٨٩) when Arabic mode is active.
    var arabicFormatted: String {
        guard AppSettingsStore.shared.appLanguage == .arabic else {
            return formatted(.number.locale(.autoupdatingCurrent))
        }
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "ar_AE")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}
