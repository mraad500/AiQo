import Foundation

/// Detects current cultural context for tone / content adaptation.
/// Stateless — computed from Calendar + current Date.
enum CulturalContextEngine {

    struct State: Sendable, Codable {
        let isRamadan: Bool
        let isFastingHour: Bool       // Ramadan AND between Fajr and Maghrib
        let isJumuah: Bool            // Friday
        let isEid: EidState
        let isWeekend: Bool           // Fri/Sat in Gulf, Sat/Sun elsewhere
        let timeOfDay: BioSnapshot.TimeOfDay
        let region: Region

        enum EidState: String, Sendable, Codable {
            case none
            case eidFitr
            case eidAdha
        }

        enum Region: String, Sendable, Codable {
            case gulf, levant, maghreb, other
        }

        /// One-line human-readable description for prompt composition.
        var promptSummary: String {
            switch isEid {
            case .eidFitr: return "Eid al-Fitr"
            case .eidAdha: return "Eid al-Adha"
            case .none: break
            }
            if isRamadan && isFastingHour { return "Ramadan (fasting hour)" }
            if isRamadan { return "Ramadan (evening)" }
            if isJumuah { return "Friday (Jumu'ah)" }
            if isWeekend { return "Weekend" }
            return "Ordinary weekday"
        }
    }

    static func current(now: Date = Date()) -> State {
        let ramadan = isInRamadan(now: now)
        let fasting = ramadan && isFastingHour(now: now)
        let jumuah = isJumuah(now: now)
        let eid = currentEid(now: now)
        let weekend = isGulfWeekend(now: now)
        let tod = BioSnapshot.TimeOfDay.current(clock: { now })
        let region = State.Region.gulf  // Default; later tied to Locale

        return State(
            isRamadan: ramadan,
            isFastingHour: fasting,
            isJumuah: jumuah,
            isEid: eid,
            isWeekend: weekend,
            timeOfDay: tod,
            region: region
        )
    }

    // MARK: - Detection helpers

    /// Ramadan detection via Hijri calendar.
    private static func isInRamadan(now: Date) -> Bool {
        let hijri = Calendar(identifier: .islamicUmmAlQura)
        let month = hijri.component(.month, from: now)
        return month == 9  // 9th Hijri month = Ramadan
    }

    /// Fasting hour approximation: between Fajr (~04:30) and Maghrib (~19:00) local time.
    /// Real prayer-time APIs require network; this coarse window is sufficient for tone adjustment.
    private static func isFastingHour(now: Date) -> Bool {
        let hour = Calendar.current.component(.hour, from: now)
        return hour >= 4 && hour < 19
    }

    /// Jumu'ah = Friday.
    private static func isJumuah(now: Date) -> Bool {
        Calendar.current.component(.weekday, from: now) == 6  // 1=Sun, 6=Fri
    }

    /// Eid detection via Hijri calendar.
    private static func currentEid(now: Date) -> State.EidState {
        let hijri = Calendar(identifier: .islamicUmmAlQura)
        let month = hijri.component(.month, from: now)
        let day = hijri.component(.day, from: now)

        // Eid al-Fitr: 1-3 Shawwal (10th month)
        if month == 10 && day >= 1 && day <= 3 { return .eidFitr }

        // Eid al-Adha: 10-13 Dhu al-Hijjah (12th month)
        if month == 12 && day >= 10 && day <= 13 { return .eidAdha }

        return .none
    }

    /// Gulf weekend is Friday-Saturday.
    private static func isGulfWeekend(now: Date) -> Bool {
        let day = Calendar.current.component(.weekday, from: now)
        return day == 6 || day == 7
    }
}
