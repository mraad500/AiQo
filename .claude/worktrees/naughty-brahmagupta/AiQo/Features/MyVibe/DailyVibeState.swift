import Foundation

/// The 5 biological states that map to time-of-day windows.
/// Each state drives both a local bio-frequency track and a
/// matching Spotify playlist through the ``VibeOrchestrator``.
enum DailyVibeState: String, CaseIterable, Identifiable, Codable {
    case awakening
    case deepFocus
    case peakEnergy
    case recovery
    case egoDeath

    var id: String { rawValue }

    // MARK: - Display

    var title: String {
        switch self {
        case .awakening:  return "Awakening"
        case .deepFocus:  return "Deep Focus"
        case .peakEnergy: return "Peak Energy"
        case .recovery:   return "Recovery"
        case .egoDeath:   return "Ego Death"
        }
    }

    var frequencyLabel: String {
        switch self {
        case .awakening:  return "SerotoninFlow"
        case .deepFocus:  return "GammaFlow"
        case .peakEnergy: return "SoundOfEnergy"
        case .recovery:   return "ThetaTrance"
        case .egoDeath:   return "Hypnagogic_state"
        }
    }

    var subtitle: String {
        switch self {
        case .awakening:  return "Serotonin activation"
        case .deepFocus:  return "Gamma-wave clarity"
        case .peakEnergy: return "Dopamine ignition"
        case .recovery:   return "Theta-wave repair"
        case .egoDeath:   return "Hypnagogic dissolve"
        }
    }

    var systemIcon: String {
        switch self {
        case .awakening:  return "sunrise.fill"
        case .deepFocus:  return "scope"
        case .peakEnergy: return "bolt.fill"
        case .recovery:   return "leaf.fill"
        case .egoDeath:   return "moon.stars.fill"
        }
    }

    /// Maps to the existing ``VibeMode`` used by ``VibeAudioEngine``.
    var vibeMode: VibeMode {
        switch self {
        case .awakening:  return .awakening
        case .deepFocus:  return .deepFocus
        case .peakEnergy: return .energy
        case .recovery:   return .recovery
        case .egoDeath:   return .egoDeath
        }
    }

    /// Spotify playlist URI for this biological state.
    var spotifyURI: String { vibeMode.spotifyURI }

    /// Time-window description shown on the timeline.
    var timeWindow: String {
        switch self {
        case .awakening:  return "5 – 9 AM"
        case .deepFocus:  return "9 AM – 12 PM"
        case .peakEnergy: return "12 – 5 PM"
        case .recovery:   return "5 – 9 PM"
        case .egoDeath:   return "9 PM – 5 AM"
        }
    }

    // MARK: - Time Resolution

    /// Determines the current biological state from the hour of day.
    static func current(for date: Date = Date(), calendar: Calendar = .current) -> DailyVibeState {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 5..<9:   return .awakening
        case 9..<12:  return .deepFocus
        case 12..<17: return .peakEnergy
        case 17..<21: return .recovery
        default:      return .egoDeath
        }
    }
}
