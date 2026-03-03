import AVFoundation
import Foundation
import UIKit
internal import Combine

@MainActor
final class AiQoAudioManager: ObservableObject {
    static let shared = AiQoAudioManager()

    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var playbackState: VibePlaybackState = .stopped
    @Published private(set) var detailText: String = "AiQo ambient ready"
    @Published private(set) var currentTrackName: String?
    @Published var lastErrorMessage: String?
    @Published var lastErrorCode: String?

    private static let defaultFileExtension = "m4a"
    private static let supportedExtensions = ["m4a", "mp3", "aac", "wav"]

    private let audioSession = AVAudioSession.sharedInstance()
    private let queuePlayer = AVQueuePlayer()

    private var playerLooper: AVPlayerLooper?
    private var observerTokens: [NSObjectProtocol] = []
    private var shouldResumeAfterInterruption = false
    private var mixWithOthers = true

    private init() {
        configurePlayer()
        configureAudioSession()
        registerAudioSessionNotifications()
    }

    deinit {
        observerTokens.forEach(NotificationCenter.default.removeObserver)
    }

    func playAmbient(trackName: String) {
        playAmbient(trackName: trackName, fileExtension: Self.defaultFileExtension)
    }

    func playAmbient(trackName: String, fileExtension: String) {
        clearError()
        configureAudioSession()

        if currentTrackName == trackName, playerLooper != nil {
            switch playbackState {
            case .playing:
                return
            case .paused:
                queuePlayer.playImmediately(atRate: 1)
                isPlaying = true
                playbackState = .playing
                detailText = playbackDescription(for: trackName)
                return
            case .stopped:
                break
            }
        }

        stopCurrentLoop(resetTrackSelection: true)

        guard let url = resolveAmbientTrackURL(trackName: trackName, preferredExtension: fileExtension) else {
            reportError(
                "AiQo Audio: \(trackName).\(fileExtension) file not found",
                code: "ambient_track_missing"
            )
            return
        }

        currentTrackName = trackName
        let templateItem = AVPlayerItem(url: url)
        playerLooper = AVPlayerLooper(player: queuePlayer, templateItem: templateItem)
        queuePlayer.seek(to: .zero)

        queuePlayer.playImmediately(atRate: 1)
        isPlaying = true
        playbackState = .playing
        detailText = playbackDescription(for: trackName)
    }

    func pauseAmbient() {
        guard playbackState != .stopped else { return }
        queuePlayer.pause()
        isPlaying = false
        playbackState = .paused
        detailText = pausedDescription(for: currentTrackName)
    }

    func stopAmbient() {
        stopCurrentLoop()
        isPlaying = false
        playbackState = .stopped
        detailText = "AiQo ambient ready"

        do {
            try audioSession.setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            print("AiQo Audio: Failed to deactivate audio session - \(error.localizedDescription)")
        }
    }

    func setVolume(_ volume: Float) {
        queuePlayer.volume = min(max(volume, 0), 1)
    }

    func setMixWithOthers(_ enabled: Bool) {
        mixWithOthers = enabled
        configureAudioSession()

        if playbackState == .playing {
            detailText = playbackDescription(for: currentTrackName)
        }
    }

    func clearError() {
        lastErrorMessage = nil
        lastErrorCode = nil
    }

    private func configurePlayer() {
        queuePlayer.actionAtItemEnd = .none
        queuePlayer.automaticallyWaitsToMinimizeStalling = false
        queuePlayer.volume = 1
    }

    private func configureAudioSession() {
        do {
            var options: AVAudioSession.CategoryOptions = []

            if mixWithOthers {
                options.insert(.mixWithOthers)
            }

            try audioSession.setCategory(.playback, mode: .default, options: options)
            try audioSession.setActive(true)
        } catch {
            reportError(
                "AiQo Audio: Failed to configure audio session - \(error.localizedDescription)",
                code: "audio_session_configuration_failed"
            )
        }
    }

    private func stopCurrentLoop(resetTrackSelection: Bool = false) {
        queuePlayer.pause()
        queuePlayer.seek(to: .zero)
        playerLooper?.disableLooping()
        playerLooper = nil
        queuePlayer.removeAllItems()

        if resetTrackSelection {
            currentTrackName = nil
        }
    }

    private func resolveAmbientTrackURL(trackName: String, preferredExtension: String) -> URL? {
        if let bundledURL = bundledTrackURL(trackName: trackName, preferredExtension: preferredExtension) {
            return bundledURL
        }

        return dataAssetTrackURL(trackName: trackName, fileExtension: preferredExtension)
    }

    private func bundledTrackURL(trackName: String, preferredExtension: String) -> URL? {
        if let url = Bundle.main.url(forResource: trackName, withExtension: preferredExtension) {
            return url
        }

        for fileExtension in Self.supportedExtensions where fileExtension != preferredExtension {
            if let url = Bundle.main.url(forResource: trackName, withExtension: fileExtension) {
                return url
            }
        }

        return nil
    }

    private func dataAssetTrackURL(trackName: String, fileExtension: String) -> URL? {
        guard let asset = NSDataAsset(name: trackName, bundle: .main) else {
            return nil
        }

        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AiQoAudio", isDirectory: true)
        let fileURL = directoryURL.appendingPathComponent("\(trackName).\(fileExtension)")

        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

            // AVPlayer needs a file URL, so materialize data-asset audio once into a temp file.
            try asset.data.write(to: fileURL, options: .atomic)

            return fileURL
        } catch {
            print("AiQo Audio: Failed to load \(trackName) data asset - \(error.localizedDescription)")
            return nil
        }
    }

    private func registerAudioSessionNotifications() {
        let interruptionToken = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated {
                self?.handleAudioSessionInterruption(notification)
            }
        }

        observerTokens.append(interruptionToken)
    }

    private func handleAudioSessionInterruption(_ notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let rawType = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: rawType)
        else {
            return
        }

        switch type {
        case .began:
            shouldResumeAfterInterruption = isPlaying
            queuePlayer.pause()
            isPlaying = false
            playbackState = .paused
            detailText = interruptionDescription(for: currentTrackName)
        case .ended:
            let rawOptions = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: rawOptions)

            if shouldResumeAfterInterruption && options.contains(.shouldResume) {
                queuePlayer.playImmediately(atRate: 1)
                isPlaying = true
                playbackState = .playing
                detailText = playbackDescription(for: currentTrackName)
            } else if playbackState != .stopped {
                detailText = pausedDescription(for: currentTrackName)
            }

            shouldResumeAfterInterruption = false
        @unknown default:
            shouldResumeAfterInterruption = false
        }
    }

    private func playbackDescription(for trackName: String?) -> String {
        let trackLabel = displayName(for: trackName)
        return mixWithOthers
            ? "\(trackLabel) is looping and mixing with other audio."
            : "\(trackLabel) is looping in the background."
    }

    private func pausedDescription(for trackName: String?) -> String {
        "\(displayName(for: trackName)) is paused."
    }

    private func interruptionDescription(for trackName: String?) -> String {
        "\(displayName(for: trackName)) paused due to an audio interruption."
    }

    private func displayName(for trackName: String?) -> String {
        guard let trackName, !trackName.isEmpty else {
            return "AiQo ambient"
        }

        return trackName.replacingOccurrences(of: "_", with: " ")
    }

    private func reportError(_ message: String, code: String) {
        print(message)
        lastErrorMessage = message
        lastErrorCode = code
        isPlaying = false
        playbackState = .stopped
        detailText = "AiQo ambient ready"
    }
}
