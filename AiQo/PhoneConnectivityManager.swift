// ===============================================
// File: PhoneConnectivityManager.swift
// Target: iOS
// ===============================================

import Foundation
import WatchConnectivity
@preconcurrency import HealthKit
import Combine
import os

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
        static let awardedWatchWorkoutsKey = "aiqo.watch.awarded-workouts"
        static let awardedWatchWorkoutsLimit = 30
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
    private var commandWatchdog: Task<Void, Never>?

    /// How long an issued control command may stay in-flight before we clear
    /// the pending flag locally. Without this, a lost watch acknowledgement
    /// leaves controls permanently disabled (the "stuck ending" bug).
    private static let commandAckTimeoutSeconds: UInt64 = 8

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
    @Published private(set) var latestSnapshotContext: WorkoutSyncSnapshot?
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

    var watchStartConnectionStatus: WatchConnectionStatus {
        guard WCSession.isSupported() else {
            return .disconnected
        }

        let session = WCSession.default
        if hasMirroredSession || session.isReachable || isReachable {
            return .connected
        }

        guard session.isPaired, session.isWatchAppInstalled else {
            return .disconnected
        }

        switch session.activationState {
        case .activated:
            return .connected
        case .inactive, .notActivated:
            return .checking
        @unknown default:
            return .checking
        }
    }

    var canStartWorkoutFromPhone: Bool {
        watchStartConnectionStatus == .connected
    }

    /// True only when a real, OS-delivered mirrored `HKWorkoutSession` is held.
    /// A snapshot restored from `UserDefaults` sets `hasMirroredSession` but
    /// leaves this nil — that distinction is what stops a stale persisted run
    /// from masquerading as a live workout and blocking new launches.
    private var hasLiveMirroredSession: Bool {
        mirroredSession != nil
    }

    var currentWorkoutId: String? {
        mirroredSessionID
    }

    var pendingQueueCount: Int {
        isCommandInFlight ? 1 : 0
    }

    private override init() {
        super.init()
        restorePersistedSnapshot()
        configureWCSession()
        configureWorkoutMirroring()
    }

    func refreshFromCompanionApplicationContext() {
        guard WCSession.isSupported() else { return }
        applyApplicationContextIfAvailable(WCSession.default.receivedApplicationContext, source: "refresh")
    }

    func refreshWatchConnectivityState() {
        guard WCSession.isSupported() else { return }

        let session = WCSession.default
        applyWatchSessionStatus(from: session)

        if session.activationState != .activated {
            session.activate()
            logEvent("WCSession activation refreshed")
        }
    }

    @discardableResult
    func launchWatchAppForWorkout(
        activityType: HKWorkoutActivityType,
        locationType: HKWorkoutSessionLocationType
    ) -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            lastError = "HealthKit not available"
            return false
        }

        if let availabilityError = watchAvailabilityError() {
            lastError = availabilityError
            workoutConnectionState = .failed
            logEvent("launch skipped: \(availabilityError)")
            return false
        }

        if hasLiveMirroredSession, !currentWorkoutPhase.isTerminal {
            lastError = "A workout is already active"
            logEvent("launch skipped: mirrored workout already active")
            return false
        }

        prepareForFreshWorkoutLaunch()

        let startRequest = WorkoutCompanionStartRequest(
            companionCommand: .startWorkout,
            requestedAt: Date(),
            activityTypeRaw: activityType.rawValue,
            locationTypeRaw: locationType.rawValue
        )

        workoutConnectionState = .launching
        logEvent("authorization requested")

        // `startWatchApp(with:)` does nothing unless the iOS app is authorized
        // to SHARE workouts. The onboarding HealthKit prompt is skippable, so we
        // must request it here every time — pressing Start is explicit intent,
        // and the call is a no-op when authorization already exists.
        let shareTypes: Set<HKSampleType> = [HKObjectType.workoutType()]
        let readTypes = Set(
            [HKQuantityTypeIdentifier.heartRate,
             .activeEnergyBurned,
             .distanceWalkingRunning,
             .distanceCycling]
                .compactMap { HKObjectType.quantityType(forIdentifier: $0) }
        )

        healthStore.requestAuthorization(toShare: shareTypes, read: readTypes) { [weak self] _, authError in
            Task { @MainActor [weak self] in
                guard let self else { return }

                if let authError {
                    self.logEvent("healthkit auth error: \(authError.localizedDescription)")
                }

                let config = HKWorkoutConfiguration()
                config.activityType = activityType
                config.locationType = locationType

                self.logEvent("launching watch app for workout")
                self.healthStore.startWatchApp(with: config) { [weak self] success, error in
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
                            if self.sendStartRequestToWatch(startRequest) {
                                self.lastSent = "start=\(activityType.rawValue)"
                            }
                        } else {
                            self.lastError = "startWatchApp returned false"
                            self.workoutConnectionState = .failed
                            self.logEvent("startWatchApp returned false")
                        }
                    }
                }
            }
        }

        return true
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

    /// Forces the phone's mirror state to terminal when the watch never
    /// confirmed an end (lost acknowledgement / terminal snapshot). The end
    /// command was already dispatched; this just stops the phone from waiting
    /// forever and releases the session so a new workout can be launched.
    func reconcileLostWorkoutEnd() {
        guard !currentWorkoutPhase.isTerminal else { return }
        logEvent("reconciling lost workout end — forcing terminal state locally")
        cancelCommandWatchdog()
        isCommandInFlight = false
        pendingCommandID = nil
        mirroredSessionID = nil
        clearPersistedSnapshot()
        currentWorkoutPhase = .ended
        workoutConnectionState = .ended
        detachMirroredSession(markDisconnected: false)
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

    private func watchAvailabilityError() -> String? {
        guard WCSession.isSupported() else {
            return "WatchConnectivity is not supported on this iPhone."
        }

        let session = WCSession.default
        applyWatchSessionStatus(from: session)

        if session.activationState != .activated {
            session.activate()
            logEvent("WCSession activation refreshed before launch")
        }

        if !session.isPaired {
            return "Apple Watch is not paired with this iPhone."
        }

        if !session.isWatchAppInstalled {
            return "AiQo Watch app is not installed on the paired Apple Watch."
        }

        return nil
    }

    private func sendStartRequestToWatch(_ request: WorkoutCompanionStartRequest) -> Bool {
        guard WCSession.isSupported() else {
            logEvent("start request skipped: WCSession unsupported")
            return false
        }

        let session = WCSession.default
        guard session.activationState == .activated else {
            session.activate()
            logEvent("start request queued after WCSession activation")
            return false
        }

        let payload = request.dictionaryRepresentation
        session.transferUserInfo(payload)
        logEvent("start request queued via transferUserInfo")

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { [weak self] error in
                Task { @MainActor [weak self] in
                    self?.lastError = error.localizedDescription
                    self?.logEvent("start request sendMessage failed: \(error.localizedDescription)")
                }
            }
            logEvent("start request sent via sendMessage")
        }

        return true
    }

    private func configureWCSession() {
        guard WCSession.isSupported() else {
            logEvent("WCSession not supported")
            return
        }

        let session = WCSession.default
        session.delegate = self
        applyWatchSessionStatus(from: session)
        session.activate()
        logEvent("WCSession activation requested")
    }

    private func applyWatchSessionStatus(from session: WCSession) {
        activationState = session.activationState
        isReachable = session.isReachable
        isPaired = session.isPaired
        isWatchAppInstalled = session.isWatchAppInstalled
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
        cancelCommandWatchdog()
        isCommandInFlight = false
        pendingCommandID = nil

        if markDisconnected, !currentWorkoutPhase.isTerminal {
            workoutConnectionState = .disconnected
        }
    }

    private func sendWorkoutCommand(
        _ type: WorkoutControlCommandType,
        explicitSessionID: String? = nil
    ) {
        if isCommandInFlight, type != .requestSnapshot {
            lastError = "A workout command is still pending"
            return
        }

        let sessionID = explicitSessionID ?? mirroredSessionID
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
            sessionId: sessionID ?? "",
            issuedAt: Date()
        )
        let companionMessage = WorkoutCompanionMessage.controlCommand(
            id: command.commandId,
            commandType: type,
            sessionId: sessionID
        )

        let sentOverWCSession = sendCompanionMessage(companionMessage, guaranteed: true)
        var sentOverMirroring = false

        if type != .requestSnapshot {
            pendingCommandID = command.commandId
            isCommandInFlight = true
        }

        if let sessionID,
           #available(iOS 17.0, *),
           let mirroredSession {
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
                sentOverMirroring = true

                Task { [weak self] in
                    do {
                        try await Self.sendToRemoteSession(data, via: mirroredSession)
                    } catch {
                        await MainActor.run {
                            guard let self else { return }
                            self.workoutConnectionState = .disconnected
                            if !sentOverWCSession {
                                if self.pendingCommandID == command.commandId {
                                    self.pendingCommandID = nil
                                    self.isCommandInFlight = false
                                }
                                self.lastError = error.localizedDescription
                            }
                            self.logEvent("mirrored command send failed: \(error.localizedDescription)")
                        }
                    }
                }
            } catch {
                if !sentOverWCSession {
                    if pendingCommandID == command.commandId {
                        pendingCommandID = nil
                        isCommandInFlight = false
                    }
                    lastError = error.localizedDescription
                }
                logEvent("command encoding failed: \(error.localizedDescription)")
            }
        }

        guard sentOverMirroring || sentOverWCSession else {
            if pendingCommandID == command.commandId {
                pendingCommandID = nil
                isCommandInFlight = false
            }
            lastError = "Unable to reach the watch workout session"
            logEvent("command \(type.rawValue) skipped: no remote transport available")
            return
        }

        let transports = [sentOverMirroring ? "mirror" : nil, sentOverWCSession ? "wc" : nil]
            .compactMap { $0 }
            .joined(separator: "+")
        lastSent = "command=\(type.rawValue) via=\(transports)"
        logEvent("command dispatched: \(type.rawValue) via \(transports)")

        if type != .requestSnapshot {
            armCommandWatchdog(commandID: command.commandId, type: type)
        }
    }

    private func armCommandWatchdog(commandID: String, type: WorkoutControlCommandType) {
        pendingCommandType = type
        commandWatchdog?.cancel()
        commandWatchdog = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.commandAckTimeoutSeconds * 1_000_000_000)
            guard !Task.isCancelled, let self else { return }
            self.handleCommandWatchdogFired(commandID: commandID, type: type)
        }
    }

    private func cancelCommandWatchdog() {
        commandWatchdog?.cancel()
        commandWatchdog = nil
        pendingCommandType = nil
    }

    /// No acknowledgement arrived for an in-flight command. Release the pending
    /// flag so controls are usable again. The terminal finalize for end/stop is
    /// owned by `LiveWorkoutSession`'s end watchdog; here we only unblock.
    private func handleCommandWatchdogFired(commandID: String, type: WorkoutControlCommandType) {
        guard isCommandInFlight, pendingCommandID == commandID else { return }
        logEvent("command \(type.rawValue) timed out without acknowledgement — clearing pending flag")
        pendingCommandID = nil
        pendingCommandType = nil
        isCommandInFlight = false
        lastError = "Watch did not acknowledge \(type.rawValue) in time"
    }

    private func sendCompanionMessage(_ message: WorkoutCompanionMessage, guaranteed: Bool) -> Bool {
        guard WCSession.isSupported() else {
            logEvent("WC companion send skipped: unsupported")
            return false
        }

        let session = WCSession.default
        guard session.activationState == .activated else {
            logEvent("WC companion send skipped: session not activated")
            return false
        }

        do {
            let data = try WorkoutSyncCodec.encodeCompanionMessage(message)
            let packet: [String: Any] = [WorkoutSyncDictionaryKey.workoutCompanionMessage: data]

            if session.isReachable {
                session.sendMessage(packet, replyHandler: nil) { [weak self] error in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        self.logEvent("WC companion send failed: \(error.localizedDescription)")

                        guard guaranteed else { return }
                        session.transferUserInfo(packet)
                        self.logEvent("WC companion fallback queued")
                    }
                }
            } else if guaranteed {
                session.transferUserInfo(packet)
            } else {
                try session.updateApplicationContext(packet)
            }

            return true
        } catch {
            lastError = error.localizedDescription
            logEvent("WC companion encoding failed: \(error.localizedDescription)")
            return false
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
            if let snapshotContext = try? JSONDecoder().decode(WorkoutSyncSnapshot.self, from: data) {
                applySnapshotContext(snapshotContext, source: "persisted")
            } else {
                let snapshot = try JSONDecoder().decode(WorkoutSessionStateDTO.self, from: data)
                let sessionID = defaults.string(forKey: Constants.sessionIDStoreKey)
                let snapshotContext = WorkoutSyncSnapshot(
                    state: snapshot,
                    sessionId: sessionID,
                    workoutName: Self.workoutName(for: snapshot.workoutType)
                )
                applySnapshotContext(snapshotContext, source: "persisted-legacy")
            }
            // The persisted snapshot is last-known display state, not proof of a
            // live link. A genuine in-progress workout re-attaches through
            // `workoutSessionMirroringStartHandler`; until then we must not
            // report a mirrored session or it blocks the next launch.
            hasMirroredSession = false
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
        !hasLiveMirroredSession || currentWorkoutPhase.isTerminal || workoutConnectionState == .ended || workoutConnectionState == .failed
    }

    private func clearSessionContextForNextWorkout(resetMetrics: Bool) {
        detachMirroredSession(markDisconnected: false)
        latestWatchSequenceNumber = 0
        pendingCommandID = nil
        mirroredSessionID = nil
        currentWorkoutPhase = .idle
        workoutConnectionState = .idle
        latestSnapshot = nil
        latestSnapshotContext = nil
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

    private func persist(snapshot: WorkoutSyncSnapshot, sessionID: String) {
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: Constants.snapshotStoreKey)
            defaults.set(sessionID, forKey: Constants.sessionIDStoreKey)
        }
    }

    private func clearPersistedSnapshot() {
        defaults.removeObject(forKey: Constants.snapshotStoreKey)
        defaults.removeObject(forKey: Constants.sessionIDStoreKey)
    }

    private func hasAwardedWatchWorkout(_ id: String) -> Bool {
        (defaults.stringArray(forKey: Constants.awardedWatchWorkoutsKey) ?? []).contains(id)
    }

    /// Records that XP was credited for a watch workout. Persisted (so a relaunch
    /// can't double-credit a queued duplicate) and capped to the most recent ids.
    private func markWatchWorkoutAwarded(_ id: String) {
        var awarded = defaults.stringArray(forKey: Constants.awardedWatchWorkoutsKey) ?? []
        guard !awarded.contains(id) else { return }
        awarded.append(id)
        if awarded.count > Constants.awardedWatchWorkoutsLimit {
            awarded.removeFirst(awarded.count - Constants.awardedWatchWorkoutsLimit)
        }
        defaults.set(awarded, forKey: Constants.awardedWatchWorkoutsKey)
    }

    private func applyApplicationContextIfAvailable(_ applicationContext: [String: Any], source: String) {
        guard let snapshotDictionary = applicationContext[WorkoutSyncDictionaryKey.snapshotContext] as? [String: Any],
              let snapshot = WorkoutSyncSnapshot(dictionary: snapshotDictionary) else {
            return
        }

        lastReceived = "applicationContext"
        applySnapshotContext(snapshot, source: source)
        logEvent("snapshot recovered from applicationContext (\(source))")
    }

    private func applySnapshotContext(_ snapshot: WorkoutSyncSnapshot, source: String) {
        if let existingSnapshot = latestSnapshotContext,
           existingSnapshot.lastUpdated > snapshot.lastUpdated {
            logEvent("stale snapshot context ignored from \(source)")
            return
        }

        latestSnapshotContext = snapshot
        latestSnapshot = snapshot.asStateDTO()
        currentWorkoutPhase = snapshot.currentState
        currentHeartRate = snapshot.heartRate
        currentAverageHeartRate = snapshot.averageHeartRate ?? 0
        activeEnergy = snapshot.activeEnergy
        currentDistance = snapshot.distance
        currentDuration = snapshot.elapsedTime
        mirroredSessionID = snapshot.sessionId
        hasMirroredSession = snapshot.hasActiveWorkout
        workoutConnectionState = snapshot.currentState.isTerminal ? .ended : snapshot.connectionState
        lastError = "None"

        if let sessionID = snapshot.sessionId, !snapshot.currentState.isTerminal {
            persist(snapshot: snapshot, sessionID: sessionID)
        } else {
            clearPersistedSnapshot()
        }

        if snapshot.currentState.isTerminal {
            cancelCommandWatchdog()
            isCommandInFlight = false
            pendingCommandID = nil
            mirroredSessionID = nil
            detachMirroredSession(markDisconnected: false)
        }
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
        let snapshotContext = WorkoutSyncSnapshot(
            state: snapshot,
            sessionId: sessionID,
            workoutName: Self.workoutName(for: snapshot.workoutType)
        )
        applySnapshotContext(snapshotContext, source: "payload")

        logEvent("payload received: snapshot seq=\(sequenceNumber)")
    }

    private func applyAcknowledgement(_ acknowledgement: WorkoutSyncAcknowledgement, sequenceNumber: Int) {
        lastAcknowledgement = acknowledgement
        lastAcknowledgement?.appliedState = acknowledgement.appliedState
        lastReceived = "ack=\(acknowledgement.commandId) seq=\(sequenceNumber)"

        if acknowledgement.commandId == pendingCommandID {
            cancelCommandWatchdog()
            pendingCommandID = nil
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

    private func handleCompanionMessage(_ message: WorkoutCompanionMessage) {
        lastReceived = "kind=\(message.kind.rawValue)"

        switch message.kind {
        case .syncPayload:
            guard let payload = message.payload else {
                logEvent("companion payload missing workout payload")
                return
            }
            handleWorkoutPayload(payload)

        case .launchConfiguration, .controlCommand:
            logEvent("unexpected companion message received on phone")
        }
    }

    private func handleIncomingWCData(_ message: [String: Any]) {
        // Standalone Watch workout completion (sent by WatchConnectivityManager
        // when a watch session ends) — drives XP on the phone.
        if let event = message["event"] as? String, event == "workout_completed" {
            let cal = message["calories"] as? Double ?? 0
            let dur = message["duration_minutes"] as? Double ?? 0
            let type = message["workout_type"] as? String ?? ""
            let dist = message["distance_km"] as? Double ?? 0
            let workoutID = (message["workout_id"] as? String).flatMap { $0.isEmpty ? nil : $0 }

            // Exactly-once XP: the watch reports completion over both
            // `sendMessage` and a `transferUserInfo` fallback, so the same
            // workout can arrive twice. Credit each workout id only once.
            if let workoutID, hasAwardedWatchWorkout(workoutID) {
                logEvent("watch workout XP already awarded, ignored: \(workoutID)")
                return
            }
            if let workoutID { markWatchWorkoutAwarded(workoutID) }

            // Award XP: same formula as Watch summary
            let xp = Int(cal * 0.8 + dur * 2)
            if xp > 0 {
                os_log("Watch XP received: %d", xp)
                LevelStore.shared.addXP(xp)
            }
            logEvent("watch workout completed: \(type) cal=\(cal) dur=\(dur) dist=\(dist)")
            return
        }

        if let payloadData = message[WorkoutSyncDictionaryKey.workoutCompanionMessage] as? Data {
            do {
                let companionMessage = try WorkoutSyncCodec.decodeCompanionMessage(payloadData)
                handleCompanionMessage(companionMessage)
            } catch {
                lastError = error.localizedDescription
                logEvent("companion message decode failure: \(error.localizedDescription)")
            }
            return
        }

        if let snapshotDictionary = message[WorkoutSyncDictionaryKey.snapshotContext] as? [String: Any],
           let snapshot = WorkoutSyncSnapshot(dictionary: snapshotDictionary) {
            lastReceived = "snapshotContext"
            applySnapshotContext(snapshot, source: "wc")
            logEvent("snapshot context received over WCSession")
            return
        }

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

    private static func workoutName(for workoutTypeRaw: UInt?) -> String {
        guard let workoutTypeRaw else { return "Workout" }

        let workoutType = HKWorkoutActivityType(rawValue: workoutTypeRaw) ?? .other

        switch workoutType {
        case .running:
            return "Running"
        case .walking:
            return "Walking"
        case .cycling:
            return "Cycling"
        case .hiking:
            return "Hiking"
        case .swimming:
            return "Swimming"
        case .yoga:
            return "Yoga"
        case .functionalStrengthTraining:
            return "Functional Strength"
        case .traditionalStrengthTraining:
            return "Strength Training"
        case .coreTraining:
            return "Core Training"
        case .dance:
            return "Dance"
        case .rowing:
            return "Rowing"
        case .elliptical:
            return "Elliptical"
        case .stairClimbing:
            return "Stair Climbing"
        default:
            return "Workout"
        }
    }

    /// WatchConnectivity and HealthKit deliver delegate callbacks on a
    /// background queue. This type is `@MainActor`, so every callback hops
    /// here before touching `@Published` state — otherwise SwiftUI emits
    /// "Publishing changes from background threads is not allowed".
    nonisolated private static func runOnMain(_ operation: @escaping @MainActor () -> Void) {
        if Thread.isMainThread {
            MainActor.assumeIsolated { operation() }
            return
        }
        DispatchQueue.main.async {
            MainActor.assumeIsolated { operation() }
        }
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith state: WCSessionActivationState,
        error: Error?
    ) {
        Self.runOnMain { [weak self] in
            guard let self else { return }
            self.applyWatchSessionStatus(from: session)
            self.activationState = state

            if let error {
                self.logEvent("WCSession activation error: \(error.localizedDescription)")
            } else {
                self.logEvent("WCSession activated")
            }

            self.applyApplicationContextIfAvailable(
                session.receivedApplicationContext,
                source: "activation"
            )
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Self.runOnMain { [weak self] in
            guard let self else { return }
            self.applyWatchSessionStatus(from: session)
            self.logEvent("WCSession reachability changed: \(session.isReachable)")
        }
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Self.runOnMain { [weak self] in
            guard let self else { return }
            self.applyWatchSessionStatus(from: session)
            self.logEvent("watch state changed")
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Self.runOnMain { [weak self] in
            self?.handleIncomingWCData(message)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        Self.runOnMain { [weak self] in
            self?.handleIncomingWCData(message)
        }
        replyHandler(["status": "received"])
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        Self.runOnMain { [weak self] in
            self?.handleIncomingWCData(userInfo)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Self.runOnMain { [weak self] in
            guard let self else { return }
            if applicationContext[WorkoutSyncDictionaryKey.snapshotContext] != nil {
                self.applyApplicationContextIfAvailable(applicationContext, source: "delegate")
                return
            }
            self.handleIncomingWCData(applicationContext)
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        Self.runOnMain { [weak self] in
            self?.logEvent("WCSession became inactive")
        }
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        Self.runOnMain { [weak self] in
            self?.logEvent("WCSession deactivated, reactivating")
        }
        WCSession.default.activate()
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        Self.runOnMain { [weak self] in
            guard let self else { return }
            self.currentWorkoutPhase = Self.phase(for: toState)
            if self.currentWorkoutPhase.isTerminal {
                self.mirroredSessionID = nil
                self.workoutConnectionState = .ended
                self.detachMirroredSession(markDisconnected: false)
                self.clearPersistedSnapshot()
            }
            self.logEvent("mirrored session state: \(fromState.rawValue) -> \(toState.rawValue)")
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Self.runOnMain { [weak self] in
            guard let self else { return }
            self.lastError = error.localizedDescription
            self.workoutConnectionState = .failed
            self.logEvent("mirrored session failure: \(error.localizedDescription)")
        }
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didReceiveDataFromRemoteWorkoutSession data: [Data]
    ) {
        Self.runOnMain { [weak self] in
            guard let self else { return }
            for item in data {
                do {
                    let payload = try WorkoutSyncCodec.decode(item)
                    self.handleWorkoutPayload(payload)
                } catch {
                    self.lastError = error.localizedDescription
                    self.logEvent("payload decode failure: \(error.localizedDescription)")
                }
            }
        }
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didDisconnectFromRemoteDeviceWithError error: Error?
    ) {
        let reason = error?.localizedDescription ?? "no error"
        Self.runOnMain { [weak self] in
            guard let self else { return }
            self.detachMirroredSession(markDisconnected: !self.currentWorkoutPhase.isTerminal)
            self.workoutConnectionState = self.currentWorkoutPhase.isTerminal ? .ended : .disconnected
            self.logEvent("remote device disconnected: \(reason)")
        }
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
