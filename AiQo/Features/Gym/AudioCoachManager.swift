import AVFoundation
import Foundation
import UIKit

@MainActor
final class AudioCoachManager {
    struct Zone2Target: Equatable {
        let lowerBoundBPM: Int
        let upperBoundBPM: Int

        nonisolated static let captainHamoudiDefault = Zone2Target(lowerBoundBPM: 118, upperBoundBPM: 137)
    }

    static let startCueDelaySeconds = 5
    static let warmUpDurationSeconds = 300
    static let feedbackCooldown: TimeInterval = 120

    private enum Cue {
        case startOfExercise
        case slowDownZone2
        case speedUpZone2

        var assetName: String {
            switch self {
            case .startOfExercise:
                return "Start of exercise"
            case .slowDownZone2:
                return "slow_down_zone2"
            case .speedUpZone2:
                return "speed_up_zone2"
            }
        }
    }

    private var currentWorkout: GymWorkoutKind = .standard
    private var zone2Target: Zone2Target = .captainHamoudiDefault
    private var hasPlayedStartCue = false
    private var lastZone2CueAt: Date?
    private var player: AVAudioPlayer?
    private var playbackToken = UUID()
    private var pendingDeactivation: DispatchWorkItem?

    func reset(
        for currentWorkout: GymWorkoutKind,
        zone2Target: Zone2Target = .captainHamoudiDefault
    ) {
        stop()
        self.currentWorkout = currentWorkout
        self.zone2Target = zone2Target
        hasPlayedStartCue = false
        lastZone2CueAt = nil
    }

    func handleTimerTick(elapsedTime: TimeInterval, heartRate: Double, isRunning: Bool) {
        guard currentWorkout == .cardioWithCaptainHamoudi else { return }
        guard isRunning else { return }

        let elapsedSeconds = Int(elapsedTime.rounded(.down))

        if !hasPlayedStartCue && elapsedSeconds >= Self.startCueDelaySeconds {
            play(.startOfExercise)
            hasPlayedStartCue = true
        }

        // Dynamic spoken Zone 2 coaching now comes from CaptainVoiceService.
    }

    func handleDynamicZone2Coaching(
        heartRate: Double,
        distanceMeters: Double,
        isRunning: Bool
    ) {
        guard currentWorkout == .cardioWithCaptainHamoudi else { return }
        guard isRunning else { return }
        guard heartRate > 0 else { return }

        let bpm = Int(heartRate.rounded())
        guard bpm < zone2Target.lowerBoundBPM || bpm > zone2Target.upperBoundBPM else { return }

        let now = Date()
        if let lastZone2CueAt, now.timeIntervalSince(lastZone2CueAt) < Self.feedbackCooldown {
            return
        }

        lastZone2CueAt = now

        let distanceKM = max(0, distanceMeters) / 1000.0
        let zoneBounds = zone2Target.lowerBoundBPM...zone2Target.upperBoundBPM

        Task { @MainActor in
            await CaptainVoiceService.shared.generateAndSpeakWorkoutPrompt(
                liveHR: bpm,
                zoneBounds: zoneBounds,
                distance: distanceKM
            )
        }
    }

    func stop() {
        pendingDeactivation?.cancel()
        pendingDeactivation = nil
        player?.stop()
        player = nil
        deactivateAudioSessionIfNeeded()
    }

    private func playZone2CueIfNeeded(_ cue: Cue) {
        let now = Date()
        if let lastZone2CueAt, now.timeIntervalSince(lastZone2CueAt) < Self.feedbackCooldown {
            return
        }

        play(cue)
        lastZone2CueAt = now
    }

    private func play(_ cue: Cue) {
        guard let data = loadAudioData(named: cue.assetName) else { return }
        configureAudioSessionForDucking()

        pendingDeactivation?.cancel()
        player?.stop()

        do {
            let nextPlayer = try AVAudioPlayer(data: data)
            nextPlayer.prepareToPlay()
            nextPlayer.play()
            player = nextPlayer
            scheduleAudioSessionDeactivation(after: nextPlayer.duration)
        } catch {
            deactivateAudioSessionIfNeeded()
        }
    }

    private func loadAudioData(named assetName: String) -> Data? {
        if let asset = NSDataAsset(name: assetName, bundle: .main) {
            return asset.data
        }

        for fileExtension in ["mp3", "m4a", "wav"] {
            guard let url = Bundle.main.url(forResource: assetName, withExtension: fileExtension) else {
                continue
            }

            if let data = try? Data(contentsOf: url) {
                return data
            }
        }

        return nil
    }

    private func configureAudioSessionForDucking() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playback,
                mode: .default,
                options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers]
            )
            try session.setActive(true)
        } catch {
            // Silent fallback keeps the workout flow alive even if audio fails.
        }
    }

    private func scheduleAudioSessionDeactivation(after duration: TimeInterval) {
        let token = UUID()
        playbackToken = token

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard self.playbackToken == token else { return }
            guard self.player?.isPlaying != true else { return }

            self.player = nil
            self.deactivateAudioSessionIfNeeded()
        }

        pendingDeactivation = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.15, execute: workItem)
    }

    private func deactivateAudioSessionIfNeeded() {
        guard !AiQoAudioManager.shared.isPlaying else { return }

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            // Session deactivation failures are safe to ignore.
        }
    }
}
