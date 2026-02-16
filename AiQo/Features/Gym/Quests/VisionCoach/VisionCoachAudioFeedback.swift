import AVFoundation
internal import Combine
import Foundation

final class VisionCoachAudioFeedback: ObservableObject {
    private let engine = AVAudioEngine()
    private let repPlayer = AVAudioPlayerNode()
    private let finalePlayer = AVAudioPlayerNode()
    private let timePitch = AVAudioUnitTimePitch()

    private var repSoundFile: AVAudioFile?
    private var finaleSoundFile: AVAudioFile?

    private var didPlayFinale = false

    private let firstRep = 1
    private let finaleRep = 70
    private let maxPitchRep = 69
    private let maxPitchCents: Float = 1_200

    init() {
        configureGraph()
        loadAudioFiles()
    }

    func resetSession() {
        didPlayFinale = false
        ensureAudioSession()
        startEngineIfNeeded()
    }

    func stop() {
        repPlayer.stop()
        finalePlayer.stop()
        engine.stop()
    }

    func handleRep(_ rep: Int) {
        guard rep >= firstRep else { return }

        ensureAudioSession()
        startEngineIfNeeded()

        if rep == finaleRep {
            playFinale()
            return
        }

        guard rep < finaleRep, !didPlayFinale else { return }
        playRepBeep(for: rep)
    }

    private func configureGraph() {
        engine.attach(repPlayer)
        engine.attach(finalePlayer)
        engine.attach(timePitch)

        engine.connect(repPlayer, to: timePitch, format: nil)
        engine.connect(timePitch, to: engine.mainMixerNode, format: nil)
        engine.connect(finalePlayer, to: engine.mainMixerNode, format: nil)
    }

    private func loadAudioFiles() {
        repSoundFile = audioFile(named: "rep_beep")
        finaleSoundFile = audioFile(named: "shield_unlock")
    }

    private func audioFile(named baseName: String) -> AVAudioFile? {
        for ext in ["mp3", "m4a", "wav"] {
            guard let url = Bundle.main.url(forResource: baseName, withExtension: ext) else {
                continue
            }

            do {
                return try AVAudioFile(forReading: url)
            } catch {
                continue
            }
        }

        return nil
    }

    private func playRepBeep(for rep: Int) {
        guard let repSoundFile else { return }

        timePitch.pitch = pitch(for: rep)
        repPlayer.scheduleFile(repSoundFile, at: nil, completionHandler: nil)

        if !repPlayer.isPlaying {
            repPlayer.play()
        }
    }

    private func playFinale() {
        guard !didPlayFinale else { return }
        didPlayFinale = true

        repPlayer.stop()

        guard let finaleSoundFile else { return }
        finalePlayer.stop()
        finalePlayer.scheduleFile(finaleSoundFile, at: nil, completionHandler: nil)
        finalePlayer.play()
    }

    private func pitch(for rep: Int) -> Float {
        let clamped = min(max(rep, firstRep), maxPitchRep)
        let span = Float(max(maxPitchRep - firstRep, 1))
        let progress = Float(clamped - firstRep) / span
        return progress * maxPitchCents
    }

    private func ensureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true, options: [])
        } catch {
            // Keep vision coach running even if audio session setup fails.
        }
    }

    private func startEngineIfNeeded() {
        guard !engine.isRunning else { return }

        do {
            try engine.start()
        } catch {
            // Keep vision coach running even if audio engine start fails.
        }
    }
}
