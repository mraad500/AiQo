import SwiftUI
import UIKit
import AVKit
import Combine

struct RoutePickerView: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.activeTintColor = .systemMint
        picker.tintColor = .white
        return picker
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}

enum VibeMode: String, CaseIterable, Identifiable, Codable {
    case awakening = "Awakening"
    case deepFocus = "Deep Focus"
    case egoDeath = "Ego-Death (Zen)"
    case energy = "Energy"
    case recovery = "Recovery"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .awakening:
            return "Bright frequency lift"
        case .deepFocus:
            return "Precision and clarity"
        case .egoDeath:
            return "Stillness and dissolve"
        case .energy:
            return "Brain ignition and warmup"
        case .recovery:
            return "Slow reset and repair"
        }
    }

    var systemIcon: String {
        switch self {
        case .awakening:
            return "sun.max.fill"
        case .deepFocus:
            return "scope"
        case .egoDeath:
            return "sparkles"
        case .energy:
            return "bolt.fill"
        case .recovery:
            return "moon.stars.fill"
        }
    }

    var accentColors: [Color] {
        switch self {
        case .awakening:
            return [
                Color(red: 1.00, green: 0.82, blue: 0.42),
                Color(red: 1.00, green: 0.61, blue: 0.38)
            ]
        case .deepFocus:
            return [
                Color(red: 0.46, green: 0.90, blue: 0.78),
                Color(red: 0.28, green: 0.74, blue: 0.63)
            ]
        case .egoDeath:
            return [
                Color(red: 0.76, green: 0.62, blue: 0.98),
                Color(red: 0.56, green: 0.45, blue: 0.92)
            ]
        case .energy:
            return [
                Color(red: 1.00, green: 0.67, blue: 0.24),
                Color(red: 0.63, green: 0.93, blue: 0.29)
            ]
        case .recovery:
            return [
                Color(red: 0.12, green: 0.18, blue: 0.34),
                Color(red: 0.05, green: 0.08, blue: 0.17)
            ]
        }
    }

    var aiqoTrackName: String {
        switch self {
        case .awakening:
            return "SerotoninFlow"
        case .deepFocus:
            return "GammaFlow"
        case .egoDeath:
            return "ThetaTrance"
        case .energy:
            return "SoundOfEnergy"
        case .recovery:
            return "Hypnagogic_state"
        }
    }

    var spotifyURI: String {
        switch self {
        case .awakening:
            return "spotify:playlist:37i9dQZF1DX3rxVfibe1L0"
        case .deepFocus:
            return "spotify:playlist:37i9dQZF1DWZeKCadgRdKQ"
        case .egoDeath:
            return "spotify:playlist:37i9dQZF1DWU0ScTcjJBdj"
        case .energy:
            return "spotify:playlist:37i9dQZF1DX76Wlfdnj7AP"
        case .recovery:
            return "spotify:playlist:37i9dQZF1DX4sWSpwq3LiO"
        }
    }
}

enum VibePlaybackSource: String, CaseIterable, Identifiable {
    case aiqoSounds = "AiQo Sounds"
    case spotify = "Spotify"

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .aiqoSounds: return "vibe.aiqoSounds".localized
        case .spotify: return "vibe.spotify".localized
        }
    }
}

@MainActor
final class VibeControlViewModel: ObservableObject {
    @Published private(set) var selectedMode: VibeMode
    @Published private(set) var lastActivatedMode: VibeMode?
    @Published var selectedSource: VibePlaybackSource {
        didSet {
            UserDefaults.standard.set(selectedSource.rawValue, forKey: Self.sourceDefaultsKey)
        }
    }
    @Published var mixWithOthers: Bool {
        didSet {
            UserDefaults.standard.set(mixWithOthers, forKey: Self.mixDefaultsKey)
        }
    }
    @Published var nativeIntensity: Double {
        didSet {
            UserDefaults.standard.set(nativeIntensity, forKey: Self.intensityDefaultsKey)
        }
    }

    init(selectedMode: VibeMode = .deepFocus) {
        self.selectedMode = selectedMode
        self.selectedSource = VibePlaybackSource(
            rawValue: UserDefaults.standard.string(forKey: Self.sourceDefaultsKey) ?? ""
        ) ?? .aiqoSounds
        self.mixWithOthers = UserDefaults.standard.object(forKey: Self.mixDefaultsKey) as? Bool ?? true
        self.nativeIntensity = UserDefaults.standard.object(forKey: Self.intensityDefaultsKey) as? Double ?? 0.55
    }

    var title: String { "vibe.title".localized }

    var subtitle: String {
        switch selectedSource {
        case .aiqoSounds:
            return "AiQo background ambient audio"
        case .spotify:
            return "Spotify playlist control"
        }
    }

    func select(_ mode: VibeMode) {
        guard selectedMode != mode else { return }
        selectedMode = mode
    }

    func markLastActivatedMode() {
        lastActivatedMode = selectedMode
    }

    private static let sourceDefaultsKey = "com.aiqo.vibe.source"
    private static let mixDefaultsKey = "com.aiqo.vibe.mixWithOthers"
    private static let intensityDefaultsKey = "com.aiqo.vibe.nativeIntensity"
}
