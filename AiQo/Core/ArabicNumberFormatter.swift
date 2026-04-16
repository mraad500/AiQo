import Foundation

extension Int {
    private var appLanguageLocale: Locale {
        AppSettingsStore.shared.appLanguage == .arabic
            ? Locale(identifier: "ar_AE")
            : Locale(identifier: "en_US_POSIX")
    }

    /// Returns Eastern Arabic numerals (٠١٢٣٤٥٦٧٨٩) when Arabic mode is active.
    var arabicFormatted: String {
        let formatter = NumberFormatter()
        formatter.locale = appLanguageLocale
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

extension Double {
    private var appLanguageLocale: Locale {
        AppSettingsStore.shared.appLanguage == .arabic
            ? Locale(identifier: "ar_AE")
            : Locale(identifier: "en_US_POSIX")
    }

    /// Returns Eastern Arabic numerals (٠١٢٣٤٥٦٧٨٩) when Arabic mode is active.
    var arabicFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.locale = appLanguageLocale
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }

    /// Metric-friendly formatting: whole numbers show no decimal, fractional numbers
    /// show at most 1 digit. Respects Arabic/English locale.
    ///
    ///     0.160507.aiqoMetricString  // "0.2"
    ///     214.0.aiqoMetricString     // "214"
    ///     1.999.aiqoMetricString     // "2"
    ///     0.0.aiqoMetricString       // "0"
    var aiqoMetricString: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        formatter.roundingMode = .halfUp
        formatter.locale = appLanguageLocale
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}
