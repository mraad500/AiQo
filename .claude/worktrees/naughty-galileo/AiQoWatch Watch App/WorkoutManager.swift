// ===============================================
// File: WorkoutManager.swift
// Target: watchOS
// ===============================================

import Foundation
import HealthKit
import Combine
#if canImport(WatchKit)
import WatchKit
#endif
#if canImport(WidgetKit)
import WidgetKit
#endif

@MainActor
final class WorkoutManager: NSObject, ObservableObject {
    static let shared = WorkoutManager()

    private enum Constants {
        static let livePushInterval: TimeInterval = 0.75
        static let snapshotThrottleInterval: TimeInterval = 0.5
        static let widgetSuiteName = "group.aiqo"
        static let sessionIDKey = "aiqo.watch.session-id"
        static let workoutTypeKey = "aiqo.watch.workout-type"
        static let locationTypeKey = "aiqo.watch.location-type"
    }

    let healthStore = HKHealthStore()

    private(set) var session: HKWorkoutSession?
    private(set) var builder: HKLiveWorkoutBuilder?

    private let defaults = UserDefaults.standard

    private var activeSessionID: String?
    private var currentLocationType: HKWorkoutSessionLocationType = .indoor
    private var lastRecordedKm = 0
    private var livePushTimer: Timer?
    private var lastWeeklySyncAt: Date?
    private var lastSnapshotSentAt: Date = .distantPast
    private var nextOutgoingSequenceNumber = 0
    private var highestProcessedCommandSequence = 0
    private var lastProcessedStartRequestAt: TimeInterval = 0
    private var handledCommandIDs = Set<String>()
    private var queuedRemotePayloads: [WorkoutSyncPayload] = []
    private var pendingSnapshotSend = false
    private var remoteSendInFlight = false
    private var hasStartedMirroring = false
    private var isFinishingWorkout = false
    private var isRecoveringWorkout = false
    private var lastEventLabel: String = "idle"
    private var isAuthorizationRequestInFlight = false
    private var isWorkoutAuthorizationGranted = false
    private var pendingStartConfiguration: HKWorkoutConfiguration?

    @Published private(set) var selectedWorkout: HKWorkoutActivityType?
    @Published var showingSummaryView = false {
        didSet {
            if oldValue && showingSummaryView == false {
                resetWorkout()
            }
        }
    }

    @Published private(set) var running = false
    @Published private(set) var workout: HKWorkout?
    @Published private(set) var connectionState: WorkoutConnectionState = .idle
    @Published private(set) var workoutPhase: WorkoutSessionPhase = .idle

    @Published private(set) var averageHeartRate: Double = 0
    @Published private(set) var heartRate: Double = 0
    @Published private(set) var activeEnergy: Double = 0
    @Published private(set) var distance: Double = 0
    @Published private(set) var elapsedSeconds: TimeInterval = 0

    var hasActiveSession: Bool {
        guard session != nil else { return false }
        return !workoutPhase.isTerminal
    }

    var displayElapsedTime: TimeInterval {
        builder?.elapsedTime ?? elapsedSeconds
    }

    var displayWorkoutTitle: String {
        resolvedWorkoutName(for: selectedWorkout)
    }

    override init() {
        super.init()
        _ = WatchConnectivityManager.shared
        requestAuthorization()
        recoverActiveWorkoutIfNeeded()
    }

    func requestAuthorization() {
        if isAuthorizationRequestInFlight {
            return
        }

        let typesToShare: Set<HKSampleType> = [HKQuantityType.workoutType()]
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate),
              let calorieType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
              let walkingDistanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning),
              let cyclingDistanceType = HKQuantityType.quantityType(forIdentifier: .distanceCycling)
        else { return }

        let typesToRead: Set<HKObjectType> = [
            heartRateType,
            calorieType,
            walkingDistanceType,
            cyclingDistanceType
        ]

        isAuthorizationRequestInFlight = true
        logEvent("authorization requested")

        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { [weak self] success, error in
            Self.runOnMain { [weak self] in
                guard let self else { return }
                self.isAuthorizationRequestInFlight = false

                if let error {
                    self.isWorkoutAuthorizationGranted = false
                    self.pendingStartConfiguration = nil
                    self.logEvent("authorization failed: \(error.localizedDescription)")
                    return
                }

                self.isWorkoutAuthorizationGranted = success
                self.logEvent("authorization granted: \(success)")
                if success {
                    self.refreshWeeklyWidgetData(force: true)
                    self.recoverActiveWorkoutIfNeeded()

                    if let pendingStartConfiguration = self.pendingStartConfiguration, self.session == nil {
                        self.pendingStartConfiguration = nil
                        self.logEvent("starting queued workout after authorization")
                        self.startWorkout(with: pendingStartConfiguration)
                    }
                } else if self.pendingStartConfiguration != nil {
                    self.pendingStartConfiguration = nil
                    self.logEvent("authorization denied; queued workout discarded")
                }
            }
        }
    }

    func recoverActiveWorkoutIfNeeded() {
        guard !isRecoveringWorkout else { return }
        guard session == nil else {
            reattachDelegatesIfNeeded()
            return
        }

        guard #available(watchOS 10.0, *) else { return }
        isRecoveringWorkout = true

        Self.runOnMainAsync { [weak self] in
            guard let self else { return }

            do {
                let recoveredSession = try await self.healthStore.recoverActiveWorkoutSession()
                self.isRecoveringWorkout = false

                guard let recoveredSession else {
                    self.logEvent("recovery found no active workout")
                    return
                }

                self.logEvent("recovery attached to active workout")
                self.attachRecoveredSession(recoveredSession)
            } catch {
                self.isRecoveringWorkout = false
                self.logEvent("recovery failed: \(error.localizedDescription)")
            }
        }
    }

    func startWorkout(workoutType: HKWorkoutActivityType, locationType: HKWorkoutSessionLocationType) {
        guard session == nil else {
            logEvent("duplicate start ignored")
            sendImmediateSnapshot(reason: "duplicate_start")
            return
        }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = workoutType
        configuration.locationType = locationType
        startWorkout(with: configuration)
    }

    func startWorkout(with configuration: HKWorkoutConfiguration) {
        guard session == nil else {
            logEvent("duplicate start ignored")
            sendImmediateSnapshot(reason: "duplicate_start")
            return
        }

        guard isWorkoutAuthorizationGranted else {
            pendingStartConfiguration = configuration
            logEvent("queueing workout start until authorization completes")
            requestAuthorization()
            return
        }

        startPrimaryWorkout(with: configuration)
    }

    private func startPrimaryWorkout(with configuration: HKWorkoutConfiguration) {
        do {
            let newSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let newBuilder = newSession.associatedWorkoutBuilder()

            configurePrimarySession(
                newSession,
                builder: newBuilder,
                configuration: configuration,
                recovered: false
            )

            workout = nil
            if showingSummaryView {
                showingSummaryView = false
            }
            resetLiveMetrics()

            logEvent("session created")

            Self.runOnMainAsync { [weak self] in
                guard let self else { return }
                await self.beginCurrentWorkoutStartup()
            }
        } catch {
            logEvent("session creation failed: \(error.localizedDescription)")
        }
    }

    private func beginCurrentWorkoutStartup() async {
        guard let workoutSession = session, let workoutBuilder = builder else {
            logEvent("startup aborted: session unavailable")
            return
        }

        await startMirroringBeforeWorkoutIfNeeded(using: workoutSession)

        let startDate = Date()
        workoutSession.prepare()
        workoutSession.startActivity(with: startDate)

        do {
            try await workoutBuilder.beginCollection(at: startDate)
            logEvent("workout started")
            lastEventLabel = "workout_started"
            startLivePushTimer()
            sendImmediateSnapshot(reason: "workout_started")
        } catch {
            logEvent("workout collection failed: \(error.localizedDescription)")
        }
    }

    func startDefaultWorkout() {
        startWorkout(workoutType: .running, locationType: .indoor)
    }

    func handleCompanionMessage(_ message: WorkoutCompanionMessage) {
        guard !isStaleCompanionMessage(message) else {
            logEvent("stale companion message ignored: \(message.kind.rawValue)")
            return
        }

        switch message.kind {
        case .launchConfiguration:
            logEvent("legacy launch configuration ignored")
        case .controlCommand:
            handleCompanionControlMessage(message)
        case .syncPayload:
            guard let payload = message.payload else {
                logEvent("companion sync payload missing body")
                return
            }
            handleRemoteCommandPayload(payload)
        }
    }

    func handleCompanionStartRequest(_ request: WorkoutCompanionStartRequest) {
        processCompanionStartRequest(request)
    }

    nonisolated func togglePause() {
        Self.runOnMain { [weak self] in
            self?.togglePauseOnMain()
        }
    }

    nonisolated func pause() {
        Self.runOnMain { [weak self] in
            self?.performPause()
        }
    }

    private func performPause() {
        guard let session, workoutPhase == .running else { return }
        session.pause()
        logEvent("pause requested")
    }

    nonisolated func resume() {
        Self.runOnMain { [weak self] in
            self?.performResume()
        }
    }

    private func performResume() {
        guard let session, workoutPhase == .paused else { return }
        session.resume()
        logEvent("resume requested")
    }

    nonisolated func stopWorkout() {
        Self.runOnMain { [weak self] in
            self?.finishWorkout(trigger: "stop_requested")
        }
    }

    nonisolated func endWorkout() {
        Self.runOnMain { [weak self] in
            self?.finishWorkout(trigger: "end_requested")
        }
    }

    private func finishWorkout(trigger: String) {
        guard !isFinishingWorkout else { return }
        guard let session, let builder else { return }

        isFinishingWorkout = true
        running = false
        workoutPhase = .stopping
        lastEventLabel = trigger
        stopLivePushTimer()
        sendImmediateSnapshot(reason: trigger)
        logEvent(trigger)

        let finalDuration = Int(displayElapsedTime.rounded())
        let finalDistance = distance
        let finalCalories = Int(activeEnergy.rounded())

        session.end()

        builder.endCollection(withEnd: Date()) { [weak self] success, error in
            Self.runOnMainAsync { [weak self] in
                guard let self else { return }

                if let error {
                    self.isFinishingWorkout = false
                    self.logEvent("endCollection failed: \(error.localizedDescription)")
                    return
                }

                guard success else {
                    self.isFinishingWorkout = false
                    self.logEvent("endCollection returned false")
                    return
                }

                do {
                    let workout = try await builder.finishWorkout()
                    self.isFinishingWorkout = false
                    self.workout = workout
                    self.running = false
                    self.workoutPhase = .ended
                    self.connectionState = .ended
                    self.lastEventLabel = "workout_ended"
                    self.showingSummaryView = true

                    WorkoutNotificationCenter.scheduleSummary(
                        elapsedSeconds: finalDuration,
                        distanceMeters: finalDistance,
                        calories: finalCalories
                    )

                    self.updateSharedWidgetSnapshot(
                        heartRate: self.heartRate,
                        activeEnergy: Double(finalCalories),
                        distanceMeters: finalDistance,
                        duration: TimeInterval(finalDuration)
                    )
                    self.refreshWeeklyWidgetData(force: true)
                    self.sendImmediateSnapshot(reason: "workout_ended")
                    self.logEvent("workout ended")
                } catch {
                    self.isFinishingWorkout = false
                    self.logEvent("finishWorkout failed: \(error.localizedDescription)")
                }
            }
        }
    }

    func resetWorkout() {
        stopLivePushTimer()
        session?.delegate = nil
        builder?.delegate = nil
        session = nil
        builder = nil
        workout = nil
        selectedWorkout = nil
        activeSessionID = nil
        lastRecordedKm = 0
        running = false
        workoutPhase = .idle
        connectionState = .idle
        nextOutgoingSequenceNumber = 0
        highestProcessedCommandSequence = 0
        lastProcessedStartRequestAt = 0
        handledCommandIDs.removeAll()
        queuedRemotePayloads.removeAll()
        pendingSnapshotSend = false
        remoteSendInFlight = false
        hasStartedMirroring = false
        isFinishingWorkout = false
        lastEventLabel = "idle"
        clearPersistedActiveSession()
        resetLiveMetrics()
        logEvent("workout state reset")
    }

    private func resetLiveMetrics() {
        averageHeartRate = 0
        heartRate = 0
        activeEnergy = 0
        distance = 0
        elapsedSeconds = 0
    }

    private func attachRecoveredSession(_ recoveredSession: HKWorkoutSession) {
        let configuration = HKWorkoutConfiguration()
        let storedWorkoutType = UInt(defaults.integer(forKey: Constants.workoutTypeKey))
        let storedLocationType = defaults.integer(forKey: Constants.locationTypeKey)
        configuration.activityType = HKWorkoutActivityType(rawValue: storedWorkoutType) ?? .other
        configuration.locationType = HKWorkoutSessionLocationType(rawValue: storedLocationType) ?? .indoor
        let recoveredBuilder = recoveredSession.associatedWorkoutBuilder()

        configurePrimarySession(
            recoveredSession,
            builder: recoveredBuilder,
            configuration: configuration,
            recovered: true
        )

        running = recoveredSession.state == .running
        workoutPhase = phase(for: recoveredSession.state)
        lastEventLabel = "recovered"

        if running || workoutPhase == .paused {
            startLivePushTimer()
        }

        if running {
            startMirroringIfNeeded()
        }

        sendImmediateSnapshot(reason: "recovery")
    }

    private func configurePrimarySession(
        _ newSession: HKWorkoutSession,
        builder newBuilder: HKLiveWorkoutBuilder,
        configuration: HKWorkoutConfiguration,
        recovered: Bool
    ) {
        session = newSession
        builder = newBuilder
        newSession.delegate = self
        newBuilder.delegate = self

        newBuilder.dataSource = HKLiveWorkoutDataSource(
            healthStore: healthStore,
            workoutConfiguration: configuration
        )

        selectedWorkout = configuration.activityType
        currentLocationType = configuration.locationType

        if recovered {
            activeSessionID = defaults.string(forKey: Constants.sessionIDKey) ?? UUID().uuidString
        } else {
            activeSessionID = UUID().uuidString
        }

        persistActiveSession(
            sessionID: activeSessionID,
            workoutType: configuration.activityType,
            locationType: configuration.locationType
        )

        if recovered {
            hasStartedMirroring = false
            connectionState = .reconnecting
        } else {
            connectionState = .awaitingMirror
            workoutPhase = .preparing
        }
    }

    private func reattachDelegatesIfNeeded() {
        session?.delegate = self
        builder?.delegate = self
    }

    private func startMirroringIfNeeded() {
        guard let session else { return }
        Task { [weak self] in
            guard let self else { return }
            await self.startMirroringIfNeeded(using: session, reconnecting: true)
        }
    }

    private func startMirroringBeforeWorkoutIfNeeded(using session: HKWorkoutSession) async {
        await startMirroringIfNeeded(using: session, reconnecting: false)
    }

    private func startMirroringIfNeeded(
        using session: HKWorkoutSession,
        reconnecting: Bool
    ) async {
#if os(watchOS)
        guard #available(watchOS 10.0, *) else { return }
        guard !hasStartedMirroring else { return }

        let previousState = connectionState
        hasStartedMirroring = true
        logEvent("starting mirroring")

        do {
            try await session.startMirroringToCompanionDevice()
            connectionState = .mirrored
            logEvent("mirroring started")

            if reconnecting || previousState == .disconnected || previousState == .reconnecting {
                lastEventLabel = "reconnect"
            } else {
                lastEventLabel = "mirroring_started"
            }

            sendImmediateSnapshot(reason: lastEventLabel)
        } catch {
            hasStartedMirroring = false
            connectionState = reconnecting ? .disconnected : .reconnecting

            if reconnecting {
                logEvent("mirroring failed: \(error.localizedDescription)")
            } else {
                logEvent("mirroring prestart failed: \(error.localizedDescription)")
            }
        }
#else
        _ = session
        _ = reconnecting
#endif
    }

    private func startLivePushTimer() {
        stopLivePushTimer()

        let timer = Timer(timeInterval: Constants.livePushInterval, repeats: true) { [weak self] _ in
            Self.runOnMain { [weak self] in
                guard let self else { return }
                guard self.hasActiveSession else { return }
                self.sendSnapshotIfNeeded(reason: "timer")
            }
        }
        timer.tolerance = 0.2
        RunLoop.main.add(timer, forMode: .common)
        livePushTimer = timer
    }

    private func stopLivePushTimer() {
        livePushTimer?.invalidate()
        livePushTimer = nil
    }

    private func sendSnapshotIfNeeded(reason: String) {
        guard let payload = makeSnapshotPayload(reason: reason) else { return }

        let elapsed = Date().timeIntervalSince(lastSnapshotSentAt)
        if elapsed < Constants.snapshotThrottleInterval {
            pendingSnapshotSend = true
            return
        }

        lastSnapshotSentAt = Date()
        publishSnapshotContext(reason: reason)
        sendRemotePayload(payload)
    }

    private func sendImmediateSnapshot(reason: String) {
        guard let payload = makeSnapshotPayload(reason: reason) else { return }
        lastSnapshotSentAt = Date()
        pendingSnapshotSend = false
        publishSnapshotContext(reason: reason)
        sendRemotePayload(payload)
    }

    private func makeSnapshotPayload(reason: String) -> WorkoutSyncPayload? {
        guard let activeSessionID else { return nil }

        nextOutgoingSequenceNumber += 1

        let state = makeCurrentWorkoutState(reason: reason)

        return WorkoutSyncPayload(
            version: WorkoutSyncPayload.currentVersion,
            sessionId: activeSessionID,
            sequenceNumber: nextOutgoingSequenceNumber,
            timestamp: Date(),
            sourceDevice: .watch,
            kind: .snapshot,
            state: state,
            command: nil,
            acknowledgement: nil
        )
    }

    private func makeCurrentWorkoutState(reason: String) -> WorkoutSessionStateDTO {
        WorkoutSessionStateDTO(
            workoutType: selectedWorkout?.rawValue,
            currentState: workoutPhase,
            isRunning: running,
            startedAt: builder?.startDate,
            elapsedTime: displayElapsedTime,
            heartRate: heartRate,
            averageHeartRate: averageHeartRate,
            activeEnergy: activeEnergy,
            distance: distance,
            lastEvent: reason,
            connectionState: connectionState
        )
    }

    private func publishSnapshotContext(reason: String) {
        guard let activeSessionID else { return }

        let snapshot = WorkoutSyncSnapshot(
            state: makeCurrentWorkoutState(reason: reason),
            sessionId: activeSessionID,
            workoutName: resolvedWorkoutName(for: selectedWorkout)
        )
        WatchConnectivityManager.shared.updateWorkoutSnapshotContext(snapshot)
    }

    private func sendAcknowledgement(
        commandID: String,
        appliedState: WorkoutSessionPhase?,
        failureReason: String? = nil
    ) {
        guard let activeSessionID else { return }

        nextOutgoingSequenceNumber += 1

        let acknowledgement = WorkoutSyncAcknowledgement(
            commandId: commandID,
            sessionId: activeSessionID,
            appliedState: appliedState,
            failureReason: failureReason
        )

        let payload = WorkoutSyncPayload(
            version: WorkoutSyncPayload.currentVersion,
            sessionId: activeSessionID,
            sequenceNumber: nextOutgoingSequenceNumber,
            timestamp: Date(),
            sourceDevice: .watch,
            kind: .acknowledgement,
            state: nil,
            command: nil,
            acknowledgement: acknowledgement
        )

        logEvent("command acknowledged")
        sendRemotePayload(payload)
    }

    private func sendRemotePayload(_ payload: WorkoutSyncPayload) {
        guard #available(watchOS 10.0, *), let session else {
            sendPayloadViaWCSession(payload)
            return
        }

        if remoteSendInFlight {
            if payload.kind == .snapshot {
                pendingSnapshotSend = true
            } else {
                queuedRemotePayloads.append(payload)
            }
            return
        }

        do {
            let data = try WorkoutSyncCodec.encode(payload)
            remoteSendInFlight = true

            Task { [weak self] in
                let sendError: Error?
                do {
                    try await Self.sendToRemoteSession(data, via: session)
                    sendError = nil
                } catch {
                    sendError = error
                }

                Self.runOnMain { [weak self] in
                    self?.finishRemotePayloadSend(payload: payload, error: sendError)
                }
            }
        } catch {
            logEvent("payload encoding failed: \(error.localizedDescription)")
        }
    }

    private func finishRemotePayloadSend(payload: WorkoutSyncPayload, error: Error?) {
        remoteSendInFlight = false

        if let error {
            if !workoutPhase.isTerminal {
                connectionState = .disconnected
            }
            logEvent("payload send failed: \(error.localizedDescription)")
            sendPayloadViaWCSession(payload)
        } else if connectionState == .disconnected || connectionState == .reconnecting {
            connectionState = .mirrored
            lastEventLabel = "reconnect"
            pendingSnapshotSend = true
            logEvent("reconnect")
        } else {
            if payload.kind == .snapshot {
                logEvent("payload sent")
            }
        }

        if !queuedRemotePayloads.isEmpty {
            let nextPayload = queuedRemotePayloads.removeFirst()
            sendRemotePayload(nextPayload)
            return
        }

        if pendingSnapshotSend, !workoutPhase.isTerminal {
            pendingSnapshotSend = false
            sendImmediateSnapshot(reason: "flush")
        }
    }

    private static func sendToRemoteSession(_ data: Data, via session: HKWorkoutSession) async throws {
        if #available(watchOS 10.0, *) {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await session.sendToRemoteWorkoutSession(data: data)
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: 2_000_000_000)
                    throw NSError(
                        domain: "AiQo.WorkoutMirroring",
                        code: -3,
                        userInfo: [NSLocalizedDescriptionKey: "Remote workout payload timed out"]
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

    private func handleRemoteCommandPayload(_ payload: WorkoutSyncPayload) {
        guard payload.version == WorkoutSyncPayload.currentVersion else {
            logEvent("unsupported payload version")
            return
        }

        guard payload.kind == .command, let command = payload.command else {
            return
        }

        if payload.sequenceNumber <= highestProcessedCommandSequence {
            sendAcknowledgement(
                commandID: command.commandId,
                appliedState: workoutPhase,
                failureReason: "Stale command ignored"
            )
            return
        }

        highestProcessedCommandSequence = payload.sequenceNumber
        applyControlCommand(
            commandID: command.commandId,
            commandType: command.commandType,
            requestedSessionID: command.sessionId
        )
    }

    private func persistActiveSession(
        sessionID: String?,
        workoutType: HKWorkoutActivityType,
        locationType: HKWorkoutSessionLocationType
    ) {
        defaults.set(sessionID, forKey: Constants.sessionIDKey)
        defaults.set(Int(workoutType.rawValue), forKey: Constants.workoutTypeKey)
        defaults.set(locationType.rawValue, forKey: Constants.locationTypeKey)
    }

    private func clearPersistedActiveSession() {
        defaults.removeObject(forKey: Constants.sessionIDKey)
        defaults.removeObject(forKey: Constants.workoutTypeKey)
        defaults.removeObject(forKey: Constants.locationTypeKey)
    }

    private func checkForMilestone(totalMeters: Double) {
        let currentKm = Int(totalMeters / 1000)
        guard currentKm > 0, currentKm > lastRecordedKm else { return }

        lastRecordedKm = currentKm
        WKInterfaceDevice.current().play(.success)
        WorkoutNotificationCenter.scheduleMilestone(
            km: currentKm,
            heartRate: Int(heartRate.rounded()),
            calories: Int(activeEnergy.rounded()),
            elapsedSeconds: Int(displayElapsedTime.rounded()),
            distanceMeters: totalMeters
        )
        logEvent("milestone reached: \(currentKm) km")
    }

    private func updateSharedWidgetSnapshot(
        heartRate: Double,
        activeEnergy: Double,
        distanceMeters: Double,
        duration: TimeInterval
    ) {
        guard let shared = UserDefaults(suiteName: Constants.widgetSuiteName) else { return }

        let calories = max(0, Int(activeEnergy.rounded()))
        let bpm = max(0, Int(heartRate.rounded()))
        let km = max(0, distanceMeters) / 1000.0
        let standPercent = min(100, max(0, Int((duration / (13 * 3600.0)) * 100)))

        shared.set(calories, forKey: "aiqo_active_cal")
        shared.set(bpm, forKey: "aiqo_bpm")
        shared.set(standPercent, forKey: "aiqo_stand_percent")
        shared.set(km, forKey: "aiqo_km_current")
        shared.set(km, forKey: "aiqo_km")
        reloadWatchWidgets()
    }

    private func refreshWeeklyWidgetData(force: Bool = false) {
        if !force, let lastWeeklySyncAt, Date().timeIntervalSince(lastWeeklySyncAt) < 120 {
            return
        }
        lastWeeklySyncAt = Date()

        queryWeeklyDistanceKm { [weak self] dailyKm in
            guard let self else { return }
            guard let shared = UserDefaults(suiteName: Constants.widgetSuiteName) else { return }

            let normalized = Array(dailyKm.prefix(7))
            let padded = normalized.count < 7 ? normalized + Array(repeating: 0, count: 7 - normalized.count) : normalized
            shared.set(padded, forKey: "aiqo_week_daily_km")
            shared.set(padded.reduce(0, +), forKey: "aiqo_week_km_total")
            self.reloadWatchWidgets()
        }
    }

    private func queryWeeklyDistanceKm(completion: @escaping ([Double]) -> Void) {
        let calendar = Calendar.current
        let endDate = Date()
        let todayStart = calendar.startOfDay(for: endDate)
        guard let weekStart = calendar.date(byAdding: .day, value: -6, to: todayStart),
              let walkingType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning),
              let cyclingType = HKQuantityType.quantityType(forIdentifier: .distanceCycling) else {
            completion([])
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: weekStart, end: endDate, options: .strictStartDate)
        let interval = DateComponents(day: 1)
        let anchor = todayStart

        func executeDailyQuery(for type: HKQuantityType, done: @escaping ([Double]) -> Void) {
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: anchor,
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, results, _ in
                var values = Array(repeating: 0.0, count: 7)
                guard let results else {
                    done(values)
                    return
                }

                results.enumerateStatistics(from: weekStart, to: endDate) { stats, _ in
                    let day = calendar.startOfDay(for: stats.startDate)
                    let index = calendar.dateComponents([.day], from: weekStart, to: day).day ?? -1
                    guard index >= 0, index < values.count else { return }
                    let km = stats.sumQuantity()?.doubleValue(for: HKUnit.meterUnit(with: .kilo)) ?? 0
                    values[index] = max(0, km)
                }

                done(values)
            }

            healthStore.execute(query)
        }

        executeDailyQuery(for: walkingType) { walking in
            executeDailyQuery(for: cyclingType) { cycling in
                completion(zip(walking, cycling).map(+))
            }
        }
    }

    private func reloadWatchWidgets() {
#if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: "AiQoWatchWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "AiQoWeeklyWidget")
#endif
    }

    private func logEvent(_ message: String) {
        print("⌚️ [WorkoutManager] \(message)")
    }
}

extension WorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        Self.runOnMain { [weak self] in
            self?.handleWorkoutSessionStateChange(toState: toState, fromState: fromState)
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Self.runOnMain { [weak self] in
            self?.handleWorkoutSessionFailure(error)
        }
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didReceiveDataFromRemoteWorkoutSession data: [Data]
    ) {
        for item in data {
            do {
                let payload = try WorkoutSyncCodec.decode(item)
                Self.runOnMain { [weak self] in
                    self?.handleRemoteCommandPayload(payload)
                }
            } catch {
                Self.runOnMain { [weak self] in
                    self?.logEvent("payload decode failed: \(error.localizedDescription)")
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
            self?.handleRemoteDisconnect(reason: reason)
        }
    }
}

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        Self.runOnMain { [weak self] in
            self?.handleCollectedMetrics(from: workoutBuilder, collectedTypes: collectedTypes)
        }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        Self.runOnMain { [weak self] in
            self?.handleWorkoutBuilderEvent()
        }
    }
}

private extension WorkoutManager {
    nonisolated static func runOnMain(_ operation: @escaping @MainActor () -> Void) {
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                operation()
            }
            return
        }

        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                operation()
            }
        }
    }

    nonisolated static func runOnMainAsync(_ operation: @escaping @MainActor () async -> Void) {
        if Thread.isMainThread {
            Task { @MainActor in
                await operation()
            }
            return
        }

        DispatchQueue.main.async {
            Task { @MainActor in
                await operation()
            }
        }
    }

    func handleWorkoutSessionStateChange(
        toState: HKWorkoutSessionState,
        fromState: HKWorkoutSessionState
    ) {
        workoutPhase = phase(for: toState)
        running = toState == .running
        elapsedSeconds = builder?.elapsedTime ?? elapsedSeconds

        switch toState {
        case .running:
            startLivePushTimer()
            startMirroringIfNeeded()
            lastEventLabel = fromState == .paused ? "resume" : "running"
            connectionState = connectionState == .disconnected ? .reconnecting : connectionState
            sendImmediateSnapshot(reason: fromState == .paused ? "resume" : "running")

        case .paused:
            stopLivePushTimer()
            lastEventLabel = "pause"
            sendImmediateSnapshot(reason: "pause")

        case .stopped:
            stopLivePushTimer()
            lastEventLabel = "stopped"
            sendImmediateSnapshot(reason: "stopped")

        case .ended:
            stopLivePushTimer()
            running = false
            workoutPhase = .ended
            lastEventLabel = "ended"
            sendImmediateSnapshot(reason: "ended")

        case .prepared:
            workoutPhase = .preparing
            sendImmediateSnapshot(reason: "prepared")

        case .notStarted:
            workoutPhase = .idle

        @unknown default:
            break
        }

        logEvent("session state changed: \(fromState.rawValue) -> \(toState.rawValue)")
    }

    func togglePauseOnMain() {
        if running {
            performPause()
        } else {
            performResume()
        }
    }

    func handleWorkoutSessionFailure(_ error: Error) {
        connectionState = .failed
        logEvent("session failed: \(error.localizedDescription)")
    }

    func handleRemoteDisconnect(reason: String) {
        connectionState = workoutPhase.isTerminal ? .ended : .disconnected
        lastEventLabel = "disconnect"
        sendImmediateSnapshot(reason: "disconnect")
        logEvent("remote device disconnected: \(reason)")
    }

    func handleCollectedMetrics(
        from workoutBuilder: HKLiveWorkoutBuilder,
        collectedTypes: Set<HKSampleType>
    ) {
        var latestHeartRate = heartRate
        var latestAverageHeartRate = averageHeartRate
        var latestActiveEnergy = activeEnergy
        var latestDistance = distance

        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }
            let statistics = workoutBuilder.statistics(for: quantityType)

            switch quantityType {
            case HKQuantityType.quantityType(forIdentifier: .heartRate):
                let unit = HKUnit.count().unitDivided(by: .minute())
                latestHeartRate = statistics?.mostRecentQuantity()?.doubleValue(for: unit) ?? latestHeartRate
                latestAverageHeartRate = statistics?.averageQuantity()?.doubleValue(for: unit) ?? latestAverageHeartRate

            case HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned):
                let unit = HKUnit.kilocalorie()
                latestActiveEnergy = statistics?.sumQuantity()?.doubleValue(for: unit) ?? latestActiveEnergy

            case HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning),
                 HKQuantityType.quantityType(forIdentifier: .distanceCycling):
                let unit = HKUnit.meter()
                latestDistance = statistics?.sumQuantity()?.doubleValue(for: unit) ?? latestDistance

            default:
                break
            }
        }

        heartRate = latestHeartRate
        averageHeartRate = latestAverageHeartRate
        activeEnergy = latestActiveEnergy
        distance = latestDistance
        elapsedSeconds = workoutBuilder.elapsedTime

        checkForMilestone(totalMeters: latestDistance)
        updateSharedWidgetSnapshot(
            heartRate: latestHeartRate,
            activeEnergy: latestActiveEnergy,
            distanceMeters: latestDistance,
            duration: workoutBuilder.elapsedTime
        )
        refreshWeeklyWidgetData()
        sendSnapshotIfNeeded(reason: "metrics")
    }

    func handleWorkoutBuilderEvent() {
        lastEventLabel = "event"
        sendImmediateSnapshot(reason: "event")
        logEvent("workout event collected")
    }

    func resolvedWorkoutName(for activityType: HKWorkoutActivityType?) -> String {
        guard let activityType else { return "Workout" }

        switch activityType {
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

    func processCompanionStartRequest(_ request: WorkoutCompanionStartRequest) {
        let requestedAt = request.requestedAt.timeIntervalSince1970
        guard requestedAt > lastProcessedStartRequestAt else {
            logEvent("duplicate start request ignored")
            sendImmediateSnapshot(reason: "duplicate_start_request")
            return
        }

        lastProcessedStartRequestAt = requestedAt

        let activityType = HKWorkoutActivityType(rawValue: request.activityTypeRaw) ?? .walking
        let locationType = HKWorkoutSessionLocationType(rawValue: request.locationTypeRaw) ?? .unknown

        if hasActiveSession {
            logEvent("start request ignored because workout is already active")
            sendImmediateSnapshot(reason: "start_request_ignored_active")
            return
        }

        logEvent("start request received via WCSession")
        startWorkout(workoutType: activityType, locationType: locationType)
    }

    func handleCompanionControlMessage(_ message: WorkoutCompanionMessage) {
        guard let commandType = message.commandType else {
            logEvent("control command missing command type")
            return
        }

        applyControlCommand(
            commandID: message.id,
            commandType: commandType,
            requestedSessionID: message.sessionId
        )
    }

    func applyControlCommand(
        commandID: String,
        commandType: WorkoutControlCommandType,
        requestedSessionID: String?
    ) {
        guard let activeSessionID else {
            logEvent("command \(commandType.rawValue) ignored: no active session")
            return
        }

        if let requestedSessionID,
           !requestedSessionID.isEmpty,
           requestedSessionID != activeSessionID {
            sendAcknowledgement(
                commandID: commandID,
                appliedState: workoutPhase,
                failureReason: "Session mismatch"
            )
            return
        }

        if handledCommandIDs.contains(commandID) {
            if commandType == .requestSnapshot {
                sendImmediateSnapshot(reason: "snapshot_requested_duplicate")
            } else {
                sendAcknowledgement(commandID: commandID, appliedState: workoutPhase)
            }
            return
        }

        handledCommandIDs.insert(commandID)
        logEvent("command received: \(commandType.rawValue)")

        switch commandType {
        case .pause:
            if workoutPhase == .paused {
                sendAcknowledgement(commandID: commandID, appliedState: .paused)
                return
            }

            guard workoutPhase == .running else {
                sendAcknowledgement(
                    commandID: commandID,
                    appliedState: workoutPhase,
                    failureReason: "Session is not running"
                )
                return
            }

            performPause()
            sendAcknowledgement(commandID: commandID, appliedState: .paused)

        case .resume:
            if workoutPhase == .running {
                sendAcknowledgement(commandID: commandID, appliedState: .running)
                return
            }

            guard workoutPhase == .paused else {
                sendAcknowledgement(
                    commandID: commandID,
                    appliedState: workoutPhase,
                    failureReason: "Session is not paused"
                )
                return
            }

            performResume()
            sendAcknowledgement(commandID: commandID, appliedState: .running)

        case .stop, .end:
            if workoutPhase.isTerminal || workoutPhase == .stopping {
                sendAcknowledgement(commandID: commandID, appliedState: workoutPhase)
                return
            }

            finishWorkout(trigger: commandType.rawValue)
            sendAcknowledgement(commandID: commandID, appliedState: .stopping)

        case .requestSnapshot:
            sendImmediateSnapshot(reason: "snapshot_requested")
        }
    }

    func sendPayloadViaWCSession(_ payload: WorkoutSyncPayload) {
        let guaranteed = payload.kind != .snapshot
        WatchConnectivityManager.shared.sendWorkoutCompanionMessage(
            .syncPayload(payload),
            guaranteed: guaranteed
        )
        logEvent("payload bridged over WCSession")
    }

    func isStaleCompanionMessage(_ message: WorkoutCompanionMessage) -> Bool {
        Date().timeIntervalSince(message.timestamp) > 30
    }

    func phase(for state: HKWorkoutSessionState) -> WorkoutSessionPhase {
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
