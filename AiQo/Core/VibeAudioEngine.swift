import Foundation
import AVFoundation
import MediaPlayer
import UIKit
import Combine

enum VibeDayPart: String, CaseIterable, Codable, Identifiable {
    case morning
    case noon
    case afternoon
    case night

    var id: String { rawValue }

    var title: String {
        switch self {
        case .morning:
            return "Morning"
        case .noon:
            return "Noon"
        case .afternoon:
            return "Afternoon"
        case .night:
            return "Night"
        }
    }

    static func current(for date: Date = Date(), calendar: Calendar = .current) -> VibeDayPart {
        let hour = calendar.component(.hour, from: date)

        switch hour {
        case 5..<11:
            return .morning
        case 11..<14:
            return .noon
        case 14..<19:
            return .afternoon
        default:
            return .night
        }
    }
}

struct VibeDayProfile: Codable, Equatable {
    var morning: VibeMode
    var noon: VibeMode
    var afternoon: VibeMode
    var night: VibeMode

    static let `default` = VibeDayProfile(
        morning: .awakening,
        noon: .deepFocus,
        afternoon: .deepFocus,
        night: .recovery
    )

    func mode(for dayPart: VibeDayPart) -> VibeMode {
        switch dayPart {
        case .morning:
            return morning
        case .noon:
            return noon
        case .afternoon:
            return afternoon
        case .night:
            return night
        }
    }

    func mode(for date: Date) -> VibeMode {
        mode(for: VibeDayPart.current(for: date))
    }

    mutating func set(_ mode: VibeMode, for dayPart: VibeDayPart) {
        switch dayPart {
        case .morning:
            morning = mode
        case .noon:
            noon = mode
        case .afternoon:
            afternoon = mode
        case .night:
            night = mode
        }
    }
}

struct VibeAudioState {
    var playbackState: VibePlaybackState = .stopped
    var currentMode: VibeMode?
    var currentDayPart: VibeDayPart?
    var mixWithOthers: Bool = false
    var intensity: Double = 0.55
    var detailText: String = "Ready"

    var isActive: Bool {
        playbackState != .stopped
    }
}

private struct TonePreset {
    let baseFrequency: Double
    let supportFrequency: Double
    let shimmerFrequency: Double
    let pulseFrequency: Double

    init(mode: VibeMode) {
        switch mode {
        case .awakening:
            baseFrequency = 220
            supportFrequency = 329.63
            shimmerFrequency = 440
            pulseFrequency = 0.18
        case .deepFocus:
            baseFrequency = 174
            supportFrequency = 261.63
            shimmerFrequency = 348
            pulseFrequency = 0.08
        case .egoDeath:
            baseFrequency = 136.1
            supportFrequency = 204.2
            shimmerFrequency = 272.2
            pulseFrequency = 0.05
        case .energy:
            baseFrequency = 196
            supportFrequency = 293.66
            shimmerFrequency = 392
            pulseFrequency = 0.22
        case .recovery:
            baseFrequency = 110
            supportFrequency = 165
            shimmerFrequency = 220
            pulseFrequency = 0.07
        }
    }
}

final class VibeAudioEngine: NSObject, ObservableObject {
    static let shared = VibeAudioEngine()

    @Published private(set) var currentState = VibeAudioState()
    @Published private(set) var currentProfile: VibeDayProfile
    @Published var lastErrorMessage: String?
    @Published var lastErrorCode: String?

    private let audioSession = AVAudioSession.sharedInstance()
    private let engine = AVAudioEngine()
    private let primaryPlayer = AVAudioPlayerNode()
    private let secondaryPlayer = AVAudioPlayerNode()
    private let primaryMixer = AVAudioMixerNode()
    private let secondaryMixer = AVAudioMixerNode()
    private let schedulerQueue = DispatchQueue(label: "com.aiqo.vibeaudio.scheduler", qos: .utility)

    private var graphFormat: AVAudioFormat?
    private var bufferCache: [VibeMode: AVAudioPCMBuffer] = [:]
    private var activeSlot: AudioSlot = .primary
    private var observerTokens: [NSObjectProtocol] = []
    private var remoteCommandTokens: [(command: MPRemoteCommand, token: Any)] = []
    private var schedulerTimer: DispatchSourceTimer?
    private var crossfadeTimer: DispatchSourceTimer?
    private var lastKnownDayPart: VibeDayPart?
    private var shouldResumeAfterInterruption = false
    private var accumulatedElapsedTime: TimeInterval = 0
    private var playbackStartDate: Date?

    private enum AudioSlot {
        case primary
        case secondary
    }

    private override init() {
        if let data = UserDefaults.standard.data(forKey: Self.profileDefaultsKey),
           let decoded = try? JSONDecoder().decode(VibeDayProfile.self, from: data) {
            currentProfile = decoded
        } else {
            currentProfile = .default
        }

        super.init()
        registerAudioNotifications()
    }

    deinit {
        observerTokens.forEach(NotificationCenter.default.removeObserver)
        cancelTimers()
        removeRemoteCommandTargets()
    }

    func start(profile: VibeDayProfile, mixWithOthers: Bool) {
        clearError()
        currentProfile = profile
        persistProfile(profile)

        do {
            try configureAudioSession(mixWithOthers: mixWithOthers)
            try configureGraphIfNeeded()
            installRemoteCommandTargetsIfNeeded()

            let dayPart = VibeDayPart.current()
            let mode = currentProfile.mode(for: dayPart)
            lastKnownDayPart = dayPart
            currentState.mixWithOthers = mixWithOthers

            if currentState.playbackState == .stopped {
                primeActiveLoop(for: mode)
            } else {
                crossfade(to: mode)
            }

            currentState.currentMode = mode
            currentState.currentDayPart = dayPart
            currentState.playbackState = .playing
            currentState.detailText = mixWithOthers
                ? "AiQo Sounds is active and can mix with other audio."
                : "AiQo Sounds is active in the background."

            startScheduler()
            resetElapsedTimeForPlaybackIfNeeded()
            updateNowPlaying()
        } catch {
            reportError(
                "AiQo Sounds couldn't start: \(error.localizedDescription)",
                code: "vibe_audio_start_failed"
            )
        }
    }

    func stop() {
        cancelTimers()
        primaryPlayer.stop()
        primaryPlayer.reset()
        secondaryPlayer.stop()
        secondaryPlayer.reset()
        primaryMixer.outputVolume = 0
        secondaryMixer.outputVolume = 0
        engine.pause()

        do {
            try audioSession.setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            reportError(
                "AiQo Sounds couldn't fully release the audio session: \(error.localizedDescription)",
                code: "vibe_audio_session_deactivate_failed"
            )
        }

        accumulatedElapsedTime = 0
        playbackStartDate = nil
        shouldResumeAfterInterruption = false
        currentState.playbackState = .stopped
        currentState.detailText = "Ready"
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        MPNowPlayingInfoCenter.default().playbackState = .stopped
        removeRemoteCommandTargets()
    }

    func pause() {
        guard currentState.playbackState == .playing else { return }

        pausePlayers()
        currentState.playbackState = .paused
        currentState.detailText = "Paused"
        pauseElapsedTimeTracking()
        stopScheduler()
        updateNowPlaying()
    }

    func resume() {
        guard currentState.playbackState != .playing else { return }

        do {
            try configureAudioSession(mixWithOthers: currentState.mixWithOthers)
            try configureGraphIfNeeded()
            installRemoteCommandTargetsIfNeeded()
            applyScheduledModeIfNeeded(force: true)
            resumePlayers()
            currentState.playbackState = .playing
            currentState.detailText = currentState.mixWithOthers
                ? "AiQo Sounds is active and can mix with other audio."
                : "AiQo Sounds is active in the background."
            resetElapsedTimeForPlaybackIfNeeded()
            startScheduler()
            updateNowPlaying()
        } catch {
            reportError(
                "AiQo Sounds couldn't resume: \(error.localizedDescription)",
                code: "vibe_audio_resume_failed"
            )
        }
    }

    func `switch`(to mode: VibeMode) {
        let dayPart = VibeDayPart.current()
        var updatedProfile = currentProfile
        updatedProfile.set(mode, for: dayPart)
        currentProfile = updatedProfile
        persistProfile(updatedProfile)
        lastKnownDayPart = dayPart

        guard currentState.playbackState != .stopped else {
            currentState.currentMode = mode
            currentState.currentDayPart = dayPart
            currentState.detailText = "Ready"
            updateNowPlaying()
            return
        }

        if currentState.playbackState == .paused {
            preparePausedLoop(for: mode)
        } else {
            crossfade(to: mode)
        }
        currentState.currentMode = mode
        currentState.currentDayPart = dayPart
        updateNowPlaying()
    }

    func `switch`(to dayPart: VibeDayPart) {
        lastKnownDayPart = dayPart
        self.`switch`(to: currentProfile.mode(for: dayPart))
    }

    func setIntensity(_ value: Double) {
        let clamped = min(max(value, 0), 1)
        currentState.intensity = clamped
        applyIntensityToCurrentMixers()
        updateNowPlaying()
    }

    func clearError() {
        lastErrorMessage = nil
        lastErrorCode = nil
    }

    private func configureAudioSession(mixWithOthers: Bool) throws {
        var options: AVAudioSession.CategoryOptions = [.allowAirPlay, .allowBluetoothHFP, .allowBluetoothA2DP]

        if mixWithOthers {
            options.insert(.mixWithOthers)
        }

        try audioSession.setCategory(.playback, mode: .default, options: options)
        try audioSession.setActive(true)
    }

    private func configureGraphIfNeeded() throws {
        guard graphFormat == nil else {
            if !engine.isRunning {
                try engine.start()
            }
            return
        }

        let sampleRate = max(audioSession.sampleRate, 44_100)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) ?? engine.mainMixerNode.outputFormat(forBus: 0)

        engine.attach(primaryPlayer)
        engine.attach(secondaryPlayer)
        engine.attach(primaryMixer)
        engine.attach(secondaryMixer)

        engine.connect(primaryPlayer, to: primaryMixer, format: format)
        engine.connect(secondaryPlayer, to: secondaryMixer, format: format)
        engine.connect(primaryMixer, to: engine.mainMixerNode, format: format)
        engine.connect(secondaryMixer, to: engine.mainMixerNode, format: format)

        primaryMixer.outputVolume = 0
        secondaryMixer.outputVolume = 0
        graphFormat = format

        try engine.start()
    }

    private func primeActiveLoop(for mode: VibeMode) {
        let player = player(for: activeSlot)
        let mixer = mixer(for: activeSlot)

        player.stop()
        player.reset()
        scheduleLoop(for: mode, on: player)
        mixer.outputVolume = Float(currentState.intensity)
        otherMixer(for: activeSlot).outputVolume = 0
        if !player.isPlaying {
            player.play()
        }
    }

    private func preparePausedLoop(for mode: VibeMode) {
        let player = player(for: activeSlot)
        let mixer = mixer(for: activeSlot)

        player.stop()
        player.reset()
        scheduleLoop(for: mode, on: player)
        mixer.outputVolume = Float(currentState.intensity)
        otherMixer(for: activeSlot).outputVolume = 0
    }

    private func crossfade(to mode: VibeMode) {
        guard currentState.currentMode != mode else {
            if currentState.playbackState != .stopped {
                primeActiveLoop(for: mode)
            }
            return
        }

        let incomingSlot = inactiveSlot(for: activeSlot)
        let outgoingSlot = activeSlot
        let incomingPlayer = player(for: incomingSlot)
        let outgoingPlayer = player(for: outgoingSlot)
        let incomingMixer = mixer(for: incomingSlot)
        let outgoingMixer = mixer(for: outgoingSlot)

        incomingPlayer.stop()
        incomingPlayer.reset()
        scheduleLoop(for: mode, on: incomingPlayer)
        incomingMixer.outputVolume = 0

        if !incomingPlayer.isPlaying {
            incomingPlayer.play()
        }

        crossfadeTimer?.cancel()
        crossfadeTimer = nil

        let targetVolume = Float(currentState.intensity)
        let steps = 24
        let interval = 2.0 / Double(steps)
        var step = 0
        let timer = DispatchSource.makeTimerSource(queue: schedulerQueue)
        timer.schedule(deadline: .now(), repeating: interval)
        timer.setEventHandler { [weak self] in
            guard let self else { return }

            step += 1
            let progress = min(Double(step) / Double(steps), 1)

            Task { @MainActor in
                incomingMixer.outputVolume = targetVolume * Float(progress)
                outgoingMixer.outputVolume = targetVolume * Float(1 - progress)

                if progress >= 1 {
                    self.crossfadeTimer?.cancel()
                    self.crossfadeTimer = nil
                    outgoingPlayer.stop()
                    outgoingPlayer.reset()
                    outgoingMixer.outputVolume = 0
                    self.activeSlot = incomingSlot
                }
            }
        }
        crossfadeTimer = timer
        timer.resume()
    }

    private func scheduleLoop(for mode: VibeMode, on player: AVAudioPlayerNode) {
        guard let buffer = buffer(for: mode) else {
            reportError("AiQo Sounds couldn't prepare the audio buffer.", code: "vibe_audio_buffer_missing")
            return
        }

        player.scheduleBuffer(buffer, at: nil, options: [.loops], completionHandler: nil)
    }

    private func buffer(for mode: VibeMode) -> AVAudioPCMBuffer? {
        if let cached = bufferCache[mode] {
            return cached
        }

        guard let format = graphFormat else { return nil }
        let frameCount = AVAudioFrameCount(format.sampleRate * 8)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }

        buffer.frameLength = frameCount
        let preset = TonePreset(mode: mode)
        let leftDetune = preset.baseFrequency * 0.995
        let rightDetune = preset.baseFrequency * 1.005
        let supportLeft = preset.supportFrequency * 0.998
        let supportRight = preset.supportFrequency * 1.002
        let shimmer = preset.shimmerFrequency
        let pulse = preset.pulseFrequency

        guard let leftChannel = buffer.floatChannelData?[0] else {
            return nil
        }

        let rightChannel = buffer.format.channelCount > 1 ? buffer.floatChannelData?[1] : leftChannel

        for frame in 0..<Int(frameCount) {
            let time = Double(frame) / format.sampleRate
            let pulseEnvelope = 0.78 + (0.22 * sin(2 * .pi * pulse * time))
            let shimmerEnvelope = 0.5 + (0.5 * sin(2 * .pi * 0.03 * time))

            let leftSample =
                (0.36 * sin(2 * .pi * leftDetune * time)) +
                (0.20 * sin(2 * .pi * supportLeft * time)) +
                (0.08 * sin(2 * .pi * shimmer * time))

            let rightSample =
                (0.36 * sin(2 * .pi * rightDetune * time)) +
                (0.20 * sin(2 * .pi * supportRight * time)) +
                (0.08 * sin(2 * .pi * shimmer * 1.01 * time))

            leftChannel[frame] = Float(leftSample * pulseEnvelope * shimmerEnvelope * 0.18)
            rightChannel?[frame] = Float(rightSample * pulseEnvelope * shimmerEnvelope * 0.18)
        }

        bufferCache[mode] = buffer
        return buffer
    }

    private func startScheduler() {
        stopScheduler()

        let timer = DispatchSource.makeTimerSource(queue: schedulerQueue)
        timer.schedule(deadline: .now() + 30, repeating: 30)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                self.applyScheduledModeIfNeeded(force: false)
            }
        }
        schedulerTimer = timer
        timer.resume()
    }

    private func stopScheduler() {
        schedulerTimer?.cancel()
        schedulerTimer = nil
    }

    private func applyScheduledModeIfNeeded(force: Bool) {
        guard currentState.playbackState != .stopped else { return }

        let currentDayPart = VibeDayPart.current()
        guard force || currentDayPart != lastKnownDayPart else { return }

        lastKnownDayPart = currentDayPart
        let mode = currentProfile.mode(for: currentDayPart)
        currentState.currentDayPart = currentDayPart
        currentState.currentMode = mode

        if currentState.playbackState == .paused {
            preparePausedLoop(for: mode)
        } else {
            crossfade(to: mode)
        }
        updateNowPlaying()
    }

    private func installRemoteCommandTargetsIfNeeded() {
        guard remoteCommandTokens.isEmpty else { return }

        let center = MPRemoteCommandCenter.shared()
        center.playCommand.isEnabled = true
        center.pauseCommand.isEnabled = true
        center.togglePlayPauseCommand.isEnabled = true
        center.stopCommand.isEnabled = true

        remoteCommandTokens.append((center.playCommand, center.playCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            Task { @MainActor in
                self.resume()
            }
            return .success
        }))

        remoteCommandTokens.append((center.pauseCommand, center.pauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            Task { @MainActor in
                self.pause()
            }
            return .success
        }))

        remoteCommandTokens.append((center.togglePlayPauseCommand, center.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            Task { @MainActor in
                if self.currentState.playbackState == .playing {
                    self.pause()
                } else {
                    self.resume()
                }
            }
            return .success
        }))

        remoteCommandTokens.append((center.stopCommand, center.stopCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            Task { @MainActor in
                self.stop()
            }
            return .success
        }))
    }

    private func removeRemoteCommandTargets() {
        guard !remoteCommandTokens.isEmpty else { return }

        let center = MPRemoteCommandCenter.shared()
        for pair in remoteCommandTokens {
            pair.command.removeTarget(pair.token)
        }

        center.playCommand.isEnabled = false
        center.pauseCommand.isEnabled = false
        center.togglePlayPauseCommand.isEnabled = false
        center.stopCommand.isEnabled = false
        remoteCommandTokens.removeAll()
    }

    private func updateNowPlaying() {
        guard currentState.playbackState != .stopped else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            MPNowPlayingInfoCenter.default().playbackState = .stopped
            return
        }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: "My Vibe",
            MPMediaItemPropertyArtist: "AiQo Sounds",
            MPMediaItemPropertyAlbumTitle: currentState.currentDayPart?.title ?? "Day Mode",
            MPMediaItemPropertyPlaybackDuration: 0,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentElapsedTime,
            MPNowPlayingInfoPropertyPlaybackRate: currentState.playbackState == .playing ? 1 : 0
        ]

        if let mode = currentState.currentMode {
            info[MPMediaItemPropertyTitle] = "My Vibe • \(mode.rawValue)"
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        switch currentState.playbackState {
        case .playing:
            MPNowPlayingInfoCenter.default().playbackState = .playing
        case .paused:
            MPNowPlayingInfoCenter.default().playbackState = .paused
        case .stopped:
            MPNowPlayingInfoCenter.default().playbackState = .stopped
        }
    }

    private func registerAudioNotifications() {
        let notificationCenter = NotificationCenter.default

        observerTokens.append(
            notificationCenter.addObserver(
                forName: AVAudioSession.interruptionNotification,
                object: audioSession,
                queue: .main
            ) { [weak self] notification in
                self?.handleInterruption(notification)
            }
        )

        observerTokens.append(
            notificationCenter.addObserver(
                forName: AVAudioSession.routeChangeNotification,
                object: audioSession,
                queue: .main
            ) { [weak self] notification in
                self?.handleRouteChange(notification)
            }
        )
    }

    private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let rawType = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: rawType) else {
            return
        }

        switch type {
        case .began:
            shouldResumeAfterInterruption = currentState.playbackState == .playing
            pause()
            currentState.detailText = "Paused for an interruption"
        case .ended:
            guard let rawOptions = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else {
                return
            }

            let options = AVAudioSession.InterruptionOptions(rawValue: rawOptions)
            if options.contains(.shouldResume), shouldResumeAfterInterruption {
                resume()
            }
            shouldResumeAfterInterruption = false
        @unknown default:
            break
        }
    }

    private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let rawReason = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: rawReason) else {
            return
        }

        switch reason {
        case .oldDeviceUnavailable:
            if currentState.playbackState == .playing {
                pause()
                currentState.detailText = "Paused after audio route changed"
                updateNowPlaying()
            }
        case .newDeviceAvailable:
            currentState.detailText = currentState.playbackState == .playing
                ? "Audio route updated"
                : currentState.detailText
        default:
            break
        }
    }

    private func pausePlayers() {
        if primaryPlayer.isPlaying {
            primaryPlayer.pause()
        }

        if secondaryPlayer.isPlaying {
            secondaryPlayer.pause()
        }
    }

    private func resumePlayers() {
        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                reportError(
                    "AiQo Sounds couldn't restart the engine: \(error.localizedDescription)",
                    code: "vibe_audio_engine_restart_failed"
                )
                return
            }
        }

        if player(for: activeSlot).lastRenderTime != nil || currentState.currentMode != nil {
            player(for: activeSlot).play()
        }

        if mixer(for: inactiveSlot(for: activeSlot)).outputVolume > 0.001 {
            player(for: inactiveSlot(for: activeSlot)).play()
        }
    }

    private func resetElapsedTimeForPlaybackIfNeeded() {
        if playbackStartDate == nil {
            playbackStartDate = Date()
        }
    }

    private func pauseElapsedTimeTracking() {
        accumulatedElapsedTime = currentElapsedTime
        playbackStartDate = nil
    }

    private var currentElapsedTime: TimeInterval {
        let liveElapsed = playbackStartDate.map { Date().timeIntervalSince($0) } ?? 0
        return accumulatedElapsedTime + liveElapsed
    }

    private func persistProfile(_ profile: VibeDayProfile) {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: Self.profileDefaultsKey)
        }
    }

    private func applyIntensityToCurrentMixers() {
        let target = Float(currentState.intensity)
        let total = primaryMixer.outputVolume + secondaryMixer.outputVolume

        guard total > 0 else { return }

        let primaryRatio = primaryMixer.outputVolume / total
        let secondaryRatio = secondaryMixer.outputVolume / total
        primaryMixer.outputVolume = target * primaryRatio
        secondaryMixer.outputVolume = target * secondaryRatio
    }

    private func player(for slot: AudioSlot) -> AVAudioPlayerNode {
        switch slot {
        case .primary:
            return primaryPlayer
        case .secondary:
            return secondaryPlayer
        }
    }

    private func mixer(for slot: AudioSlot) -> AVAudioMixerNode {
        switch slot {
        case .primary:
            return primaryMixer
        case .secondary:
            return secondaryMixer
        }
    }

    private func otherMixer(for slot: AudioSlot) -> AVAudioMixerNode {
        mixer(for: inactiveSlot(for: slot))
    }

    private func inactiveSlot(for slot: AudioSlot) -> AudioSlot {
        switch slot {
        case .primary:
            return .secondary
        case .secondary:
            return .primary
        }
    }

    private func cancelTimers() {
        schedulerTimer?.cancel()
        schedulerTimer = nil
        crossfadeTimer?.cancel()
        crossfadeTimer = nil
    }

    private func reportError(_ message: String, code: String) {
        lastErrorMessage = message
        lastErrorCode = code
    }

    private static let profileDefaultsKey = "com.aiqo.vibeAudio.profile"
}
