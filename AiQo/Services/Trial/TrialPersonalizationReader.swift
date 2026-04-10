import Foundation

struct TrialPersonalization {
    let firstName: String?
    let goal: CaptainPrimaryGoal?
    let sport: CaptainSportPreference?
    let workoutTime: CaptainWorkoutTimePreference?
    let bedtime: Date?
    let wakeTime: Date?
}

enum TrialPersonalizationReader {

    static func current() -> TrialPersonalization {
        let snapshot = CaptainPersonalizationStore.shared.currentSnapshot()
        let fullName = UserProfileStore.shared.current.name
        let firstName = fullName.components(separatedBy: " ").first

        return TrialPersonalization(
            firstName: firstName?.isEmpty == true ? nil : firstName,
            goal: snapshot?.primaryGoal,
            sport: snapshot?.favoriteSport,
            workoutTime: snapshot?.preferredWorkoutTime,
            bedtime: snapshot?.bedtime,
            wakeTime: snapshot?.wakeTime
        )
    }

    /// Morning brief hour based on the user's preferred workout time.
    /// earlyMorning -> 5:30, morning -> 8:00, afternoon -> 9:00, evening/night -> 9:30
    static func morningBriefTime(for preference: CaptainWorkoutTimePreference?) -> (hour: Int, minute: Int) {
        switch preference {
        case .earlyMorning: return (5, 30)
        case .morning:      return (8, 0)
        case .afternoon:    return (9, 0)
        case .evening:      return (9, 30)
        case .night:        return (9, 30)
        case .none:         return (8, 30)
        }
    }
}
