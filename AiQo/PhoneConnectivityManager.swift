// ===============================================
// File: PhoneConnectivityManager.swift
// Target: iOS
// ===============================================

import Foundation
import WatchConnectivity
import HealthKit
internal import Combine

@MainActor
final class PhoneConnectivityManager: NSObject, ObservableObject, WCSessionDelegate, HKWorkoutSessionDelegate, ConnectivityDebugProviding {
    enum VisionCoachEvent: String {
        case repDetected = "rep_detected"
        case challengeCompleted = "challenge_completed"
    }

    static let shared = PhoneConnectivityManager()

    private enum Constants {
        static let snapshotStoreKey = "aiqo.workout.snapshot"
        static let sessionIDStoreKey = "aiqo.workout.session-id"
        static let logLimit = 40
    }

    private let healthStore = HKHealthStore()
    private let defaults = UserDefaults.standard

    private var mirroredSession: HKWorkoutSession?
    private var latestWatchSequenceNumber = 0
    private var latestCommandSequenceNumber = 0
    private var lastLegacyPacketSequence = -1
    private var pendingCommandID: String?
    private var pendingCommandType: WorkoutControlCommandType?

    @Published var isReachable = false
    @Published var isPaired = false
    @Published var isWatchAppInstalled = false
    @Published var activationState: WCSessionActivationState = .notActivated

    @Published var currentHeartRate: Double = 0
    @Published var currentAverageHeartRate: Double = 0
    @Published var activeEnergy: Double = 0
    @Published var currentDuration: Double = 0
    @Published var currentDistance: Double = 0

    @Published private(set) var mirroredSessionID: String?
    @Published private(set) var currentWorkoutPhase: WorkoutSessionPhase = .idle
    @Published private(set) var workoutConnectionState: WorkoutConnectionState = .idle
    @Published private(set) var latestSnapshot: WorkoutSessionStateDTO?
    @Published private(set) var lastAcknowledgement: WorkoutSyncAcknowledgement?
    @Published private(set) var eventLog: [String] = []
    @Published private(set) var hasMirroredSession = false
    @Published private(set) var isCommandInFlight = false

    @Published var lastReceived: String = "None"
    @Published var lastSent: String = "None"
    @Published var lastError: String = "None"

    var activationStateText: String {
        switch activationState {
        case .notActivated: return "notActivated"
        case .inactive: return "inactive"
        case .activated: return "activated"
        @unknown default: return "unknown"
        }
    }

    var reachabilityText: String {
        "wc=\(isReachable) mirrored=\(hasMirroredSession)"
    }

    var lastAcknowledgementText: String {
        if let lastAcknowledgement {
            let result = lastAcknowledgement.failureReason ?? "ok"
            return "\(lastAcknowledgement.commandId) -> \(result)"
        }
        return "None"
    }

    var connectionStateText: String {
        workoutConnectionState.rawValue
    }

    var currentWorkoutStateText: String {
        currentWorkoutPhase.rawValue
    }

    var currentWorkoutId: String? {
        mirroredSessionID
    }

    private override init() {
        super.init()
        restorePersistedSnapshot()
        configureWCSession()
        configureWorkoutMirroring()
    }

    func launchWatchAppForWorkout(
        activityType: HKWorkoutActivityType,
        locationType: HKWorkoutSessionLocationType
    ) {
        guard HKHealthStore.isHealthDataAvailable() else {
            lastError = "HealthKit not available"
            return
        }

        if hasMirroredSession, !currentWorkoutPhase.isTerminal {
            lastError = "A workout is already active"
            logEvent("launch skipped: mirrored workout already active")
            return
        }

        prepareForFreshWorkoutLaunch()

        let config = HKWorkoutConfiguration()
        config.activityType = activityType
        config.locationType = locationType

        workoutConnectionState = .launching
        logEvent("authorization requested")
        logEvent("launching watch app for workout")

        healthStore.startWatchApp(with: config) { [weak self] success, error in
            Task { @MainActor [weak self] in
                guard let self else { return }

                if let error {
                    self.lastError = "startWatchApp error: \(error.localizedDescription)"
                    self.workoutConnectionState = .failed
                    self.logEvent("startWatchApp failed: \(error.localizedDescription)")
                } else if success {
                    self.lastError = "None"
                    self.workoutConnectionState = .awaitingMirror
                    self.logEvent("watch app launched, awaiting mirrored session")
                } else {
                    self.lastError = "startWatchApp returned false"
                    self.workoutConnectionState = .failed
                    self.logEvent("startWatchApp returned false")
                }
            }
        }
    }

    func startWorkoutOnWatch(activityTypeRaw: Int, locationTypeRaw: Int) {
        let activityType = HKWorkoutActivityType(rawValue: UInt(activityTypeRaw)) ?? .other
        let locationType = HKWorkoutSessionLocationType(rawValue: locationTypeRaw) ?? .unknown
        launchWatchAppForWorkout(activityType: activityType, locationType: locationType)
    }

    func stopWorkoutOnWatch() {
        sendWorkoutCommand(.stop)
    }

    func pauseWorkoutOnWatch() {
        sendWorkoutCommand(.pause)
    }

    func resumeWorkoutOnWatch() {
        sendWorkoutCommand(.resume)
    }

    func endWorkoutOnWatch() {
        sendWorkoutCommand(.end)
    }

    func requestLatestSnapshot() {
        sendWorkoutCommand(.requestSnapshot)
    }

    func sendVisionCoachEvent(_ event: VisionCoachEvent) {
        guard WCSession.default.activationState == .activated else { return }

        let payload = ["event": event.rawValue]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: nil) { [weak self] error in
                Task { @MainActor [weak self] in
                    self?.lastError = error.localizedDescription
                    self?.logEvent("vision event send error: \(error.localizedDescription)")
                }
            }
        } else {
            WCSession.default.transferUserInfo(payload)
        }
    }

    private func configureWCSession() {
        guard WCSession.isSupported() else {
            logEvent("WCSession not supported")
            return
        }

        let session = WCSession.default
        session.delegate = self
        session.activate()
        logEvent("WCSession activation requested")
    }

    private func configureWorkoutMirroring() {
        if #available(iOS 17.0, *) {
            healthStore.workoutSessionMirroringStartHandler = { [weak self] mirroredSession in
                Task { @MainActor [weak self] in
                    self?.attachMirroredSession(mirroredSession)
                }
            }
            logEvent("workoutSessionMirroringStartHandler installed")
        } else {
            logEvent("mirroring APIs unavailable, legacy transport only")
        }
    }

    private func attachMirroredSession(_ session: HKWorkoutSession) {
        if mirroredSessionID != nil, shouldReplaceStaleSessionContext {
            clearSessionContextForNextWorkout(resetMetrics: false)
        }

        mirroredSession = session
        hasMirroredSession = true
        workoutConnectionState = .mirrored
        session.delegate = self
        lastError = "None"
        logEvent("mirrored session received")

        if let mirroredSessionID {
            sendWorkoutCommand(.requestSnapshot, explicitSessionID: mirroredSessionID)
        }
    }

    private func detachMirroredSession(markDisconnected: Bool) {
        mirroredSession?.delegate = nil
        mirroredSession = nil
        hasMirroredSession = false
        isCommandInFlight = false
        pendingCommandID = nil
        pendingCommandType = nil

        if markDisconnected, !currentWorkoutPhase.isTerminal {
            workoutConnectionState = .disconnected
        }
    }

    private func sendWorkoutCommand(
        _ type: WorkoutControlCommandType,
        explicitSessionID: String? = nil
    ) {
        guard #available(iOS 17.0, *), let mirroredSession else {
            lastError = "Mirrored workout session unavailable"
            logEvent("command \(type.rawValue) skipped: no mirrored session")
            return
        }

        if isCommandInFlight, type != .requestSnapshot {
            lastError = "A workout command is still pending"
            return
        }

        let sessionID = explicitSessionID ?? mirroredSessionID
        guard let sessionID else {
            lastError = "Missing workout session identifier"
            logEvent("command \(type.rawValue) skipped: missing session id")
            return
        }

        if type == .pause && currentWorkoutPhase == .paused {
            logEvent("pause command ignored locally because session is already paused")
            return
        }

        if type == .resume && currentWorkoutPhase == .running {
            logEvent("resume command ignored locally because session is already running")
            return
        }

        if (type == .stop || type == .end), currentWorkoutPhase.isTerminal {
            logEvent("\(type.rawValue) command ignored locally because session already ended")
            return
        }

        let command = WorkoutControlCommand(
            commandId: UUID().uuidString,
            commandType: type,
            sessionId: sessionID,
            issuedAt: Date()
        )

        latestCommandSequenceNumber += 1
        let payload = WorkoutSyncPayload(
            version: WorkoutSyncPayload.currentVersion,
            sessionId: sessionID,
            sequenceNumber: latestCommandSequenceNumber,
            timestamp: Date(),
            sourceDevice: .phone,
            kind: .command,
            state: nil,
            command: command,
            acknowledgement: nil
        )

        do {
            let data = try WorkoutSyncCodec.encode(payload)
            lastSent = "command=\(type.rawValue) seq=\(payload.sequenceNumber)"
            logEvent("command sent: \(type.rawValue)")

            if type != .requestSnapshot {
                pendingCommandID = command.commandId
                pendingCommandType = type
                isCommandInFlight = true
            }

            Task { [weak self] in
                do {
                    try await Self.sendToRemoteSession(data, via: mirroredSession)
                } catch {
                    await MainActor.run {
                        guard let self else { return }
                        if self.pendingCommandID == command.commandId {
                            self.pendingCommandID = nil
                            self.pendingCommandType = nil
                            self.isCommandInFlight = false
                        }
                        self.lastError = error.localizedDescription
                        self.workoutConnectionState = .disconnected
                        self.logEvent("command send failed: \(error.localizedDescription)")
                    }
                }
            }
        } catch {
            lastError = error.localizedDescription
            logEvent("command encoding failed: \(error.localizedDescription)")
        }
    }

    private static func sendToRemoteSession(_ data: Data, via session: HKWorkoutSession) async throws {
        if #available(iOS 17.0, *) {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await session.sendToRemoteWorkoutSession(data: data)
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: 2_000_000_000)
                    throw NSError(
                        domain: "AiQo.WorkoutMirroring",
                        code: -7,
                        userInfo: [NSLocalizedDescriptionKey: "Remote workout command timed out"]
                    )
                }

                guard try await group.next() != nil else {
                    group.cancelAll()
                    return
                }
                group.cancelAll()
            }
        }
    }

    private func restorePersistedSnapshot() {
        guard let data = defaults.data(forKey: Constants.snapshotStoreKey) else { return }

        do {
            let snapshot = try JSONDecoder().decode(WorkoutSessionStateDTO.self, from: data)
            latestSnapshot = snapshot
            currentWorkoutPhase = snapshot.currentState
            currentHeartRate = snapshot.heartRate ?? 0
            currentAverageHeartRate = snapshot.averageHeartRate ?? 0
            activeEnergy = snapshot.activeEnergy ?? 0
            currentDistance = snapshot.distance ?? 0
            currentDuration = snapshot.elapsedTime
            if snapshot.currentState.isTerminal {
                mirroredSessionID = nil
                workoutConnectionState = .ended
                clearPersistedSnapshot()
            } else {
                mirroredSessionID = defaults.string(forKey: Constants.sessionIDStoreKey)
                workoutConnectionState = .awaitingMirror
            }
            logEvent("recovered persisted snapshot")
        } catch {
            defaults.removeObject(forKey: Constants.snapshotStoreKey)
            defaults.removeObject(forKey: Constants.sessionIDStoreKey)
        }
    }

    private func prepareForFreshWorkoutLaunch() {
        if !shouldReplaceStaleSessionContext {
            return
        }

        clearSessionContextForNextWorkout(resetMetrics: true)
        logEvent("prepared for new workout launch")
    }

    private var shouldReplaceStaleSessionContext: Bool {
        !hasMirroredSession || currentWorkoutPhase.isTerminal || workoutConnectionState == .ended || workoutConnectionState == .failed
    }

    private func clearSessionContextForNextWorkout(resetMetrics: Bool) {
        detachMirroredSession(markDisconnected: false)
        latestWatchSequenceNumber = 0
        pendingCommandID = nil
        pendingCommandType = nil
        mirroredSessionID = nil
        currentWorkoutPhase = .idle
        workoutConnectionState = .idle
        latestSnapshot = nil
        lastAcknowledgement = nil
        clearPersistedSnapshot()

        if resetMetrics {
            currentHeartRate = 0
            currentAverageHeartRate = 0
            activeEnergy = 0
            currentDistance = 0
            currentDuration = 0
        }
    }

    private func persist(snapshot: WorkoutSessionStateDTO, sessionID: String) {
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: Constants.snapshotStoreKey)
            defaults.set(sessionID, forKey: Constants.sessionIDStoreKey)
        }
    }

    private func clearPersistedSnapshot() {
        defaults.removeObject(forKey: Constants.snapshotStoreKey)
        defaults.removeObject(forKey: Constants.sessionIDStoreKey)
    }

    private func applySnapshot(_ snapshot: WorkoutSessionStateDTO, sessionID: String, sequenceNumber: Int) {
        if let existingSessionID = mirroredSessionID, existingSessionID != sessionID {
            guard shouldReplaceStaleSessionContext else {
                logEvent("ignoring snapshot for active session \(sessionID)")
                return
            }

            logEvent("replacing stale session \(existingSessionID) with \(sessionID)")
            clearSessionContextForNextWorkout(resetMetrics: false)
        }

        if sequenceNumber < latestWatchSequenceNumber {
            logEvent("ignoring out-of-order snapshot seq=\(sequenceNumber)")
            return
        }

        latestWatchSequenceNumber = sequenceNumber
        mirroredSessionID = sessionID
        latestSnapshot = snapshot
        currentWorkoutPhase = snapshot.currentState
        currentHeartRate = snapshot.heartRate ?? 0
        currentAverageHeartRate = snapshot.averageHeartRate ?? 0
        activeEnergy = snapshot.activeEnergy ?? 0
        currentDistance = snapshot.distance ?? 0
        currentDuration = snapshot.elapsedTime
        hasMirroredSession = true
        workoutConnectionState = snapshot.connectionState == .disconnected ? .disconnected : .mirrored
        lastError = "None"
        persist(snapshot: snapshot, sessionID: sessionID)

        if snapshot.currentState.isTerminal {
            isCommandInFlight = false
            pendingCommandID = nil
            pendingCommandType = nil
            mirroredSessionID = nil
            workoutConnectionState = .ended
            detachMirroredSession(markDisconnected: false)
            clearPersistedSnapshot()
        }

        logEvent("payload received: snapshot seq=\(sequenceNumber)")
    }

    private func applyAcknowledgement(_ acknowledgement: WorkoutSyncAcknowledgement, sequenceNumber: Int) {
        lastAcknowledgement = acknowledgement
        lastAcknowledgement?.appliedState = acknowledgement.appliedState
        lastReceived = "ack=\(acknowledgement.commandId) seq=\(sequenceNumber)"

        if acknowledgement.commandId == pendingCommandID {
            pendingCommandID = nil
            pendingCommandType = nil
            isCommandInFlight = false
        }

        if let failureReason = acknowledgement.failureReason {
            lastError = failureReason
            logEvent("command acknowledged with failure: \(failureReason)")
        } else {
            lastError = "None"
            logEvent("command acknowledged")
        }
    }

    private func handleWorkoutPayload(_ payload: WorkoutSyncPayload) {
        lastReceived = "kind=\(payload.kind.rawValue) seq=\(payload.sequenceNumber)"

        switch payload.kind {
        case .snapshot:
            guard let state = payload.state else {
                logEvent("snapshot payload missing state")
                return
            }
            applySnapshot(state, sessionID: payload.sessionId, sequenceNumber: payload.sequenceNumber)

        case .acknowledgement:
            guard let acknowledgement = payload.acknowledgement else {
                logEvent("ack payload missing acknowledgement body")
                return
            }
            applyAcknowledgement(acknowledgement, sequenceNumber: payload.sequenceNumber)

        case .command:
            logEvent("unexpected command payload received on phone")
        }
    }

    private func handleLegacyIncomingData(_ message: [String: Any]) {
        if let sequence = Self.intValue(for: "packetSeq", in: message) {
            if sequence < lastLegacyPacketSequence {
                return
            }
            lastLegacyPacketSequence = sequence
        }

        lastReceived = message.description

        if let hr = Self.doubleValue(for: "heartRate", in: message) {
            currentHeartRate = hr
        }
        if let avg = Self.doubleValue(for: "averageHeartRate", in: message) {
            currentAverageHeartRate = avg
        }
        if let energy = Self.doubleValue(for: "activeEnergy", in: message) {
            activeEnergy = energy
        }
        if let duration = Self.doubleValue(for: "duration", in: message) {
            currentDuration = duration
        }
        if let distance = Self.doubleValue(for: "distance", in: message) {
            currentDistance = distance
        }
        logEvent("legacy payload received over WCSession")
    }

    private func logEvent(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let entry = "\(timestamp) | \(message)"
        eventLog.insert(entry, at: 0)
        if eventLog.count > Constants.logLimit {
            eventLog.removeLast(eventLog.count - Constants.logLimit)
        }
    }

    private static func doubleValue(for key: String, in message: [String: Any]) -> Double? {
        if let value = message[key] as? Double {
            return value
        }
        if let value = message[key] as? Int {
            return Double(value)
        }
        if let value = message[key] as? NSNumber {
            return value.doubleValue
        }
        return nil
    }

    private static func intValue(for key: String, in message: [String: Any]) -> Int? {
        if let value = message[key] as? Int {
            return value
        }
        if let value = message[key] as? NSNumber {
            return value.intValue
        }
        if let value = message[key] as? Double {
            return Int(value)
        }
        return nil
    }

    func session(
        _ session: WCSession,
        activationDidCompleteWith state: WCSessionActivationState,
        error: Error?
    ) {
        activationState = state
        isReachable = session.isReachable
        isPaired = session.isPaired
        isWatchAppInstalled = session.isWatchAppInstalled

        if let error {
            logEvent("WCSession activation error: \(error.localizedDescription)")
        } else {
            logEvent("WCSession activated")
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        isReachable = session.isReachable
        logEvent("WCSession reachability changed: \(session.isReachable)")
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        isPaired = session.isPaired
        isWatchAppInstalled = session.isWatchAppInstalled
        logEvent("watch state changed")
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleLegacyIncomingData(message)
    }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        handleLegacyIncomingData(message)
        replyHandler(["status": "received"])
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        handleLegacyIncomingData(userInfo)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        handleLegacyIncomingData(applicationContext)
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        logEvent("WCSession became inactive")
    }

    func sessionDidDeactivate(_ session: WCSession) {
        logEvent("WCSession deactivated, reactivating")
        WCSession.default.activate()
    }

    func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        currentWorkoutPhase = Self.phase(for: toState)
        if currentWorkoutPhase.isTerminal {
            mirroredSessionID = nil
            workoutConnectionState = .ended
            detachMirroredSession(markDisconnected: false)
            clearPersistedSnapshot()
        }
        logEvent("mirrored session state: \(fromState.rawValue) -> \(toState.rawValue)")
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        lastError = error.localizedDescription
        workoutConnectionState = .failed
        logEvent("mirrored session failure: \(error.localizedDescription)")
    }

    func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didReceiveDataFromRemoteWorkoutSession data: [Data]
    ) {
        for item in data {
            do {
                let payload = try WorkoutSyncCodec.decode(item)
                handleWorkoutPayload(payload)
            } catch {
                lastError = error.localizedDescription
                logEvent("payload decode failure: \(error.localizedDescription)")
            }
        }
    }

    func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didDisconnectFromRemoteDeviceWithError error: Error?
    ) {
        let reason = error?.localizedDescription ?? "no error"
        detachMirroredSession(markDisconnected: !currentWorkoutPhase.isTerminal)
        workoutConnectionState = currentWorkoutPhase.isTerminal ? .ended : .disconnected
        logEvent("remote device disconnected: \(reason)")
    }

    private static func phase(for state: HKWorkoutSessionState) -> WorkoutSessionPhase {
        switch state {
        case .notStarted:
            return .idle
        case .prepared:
            return .preparing
        case .running:
            return .running
        case .paused:
            return .paused
        case .stopped:
            return .stopping
        case .ended:
            return .ended
        @unknown default:
            return .idle
        }
    }
}
