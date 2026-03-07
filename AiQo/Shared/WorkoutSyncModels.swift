import Foundation

nonisolated enum WorkoutSyncDictionaryKey {
    static let workoutCompanionMessage = "aiqo.workout.message.data"
    static let snapshotContext = "aiqo.workout.snapshot.context"
    static let companionCommand = "companionCommand"
    static let requestedAt = "requestedAt"
    static let activityTypeRaw = "activityTypeRaw"
    static let locationTypeRaw = "locationTypeRaw"
    static let hasActiveWorkout = "hasActiveWorkout"
    static let isRunning = "isRunning"
    static let workoutName = "workoutName"
    static let activeEnergy = "activeEnergy"
    static let distance = "distance"
    static let heartRate = "heartRate"
    static let elapsedTime = "elapsedTime"
    static let lastUpdated = "lastUpdated"
    static let currentState = "currentState"
    static let connectionState = "connectionState"
    static let averageHeartRate = "averageHeartRate"
    static let workoutType = "workoutType"
    static let sessionId = "sessionId"
}

nonisolated enum WorkoutCompanionCommand: String, Codable, Equatable {
    // Kept as `startWalkingWorkout` for compatibility with the requested payload contract.
    case startWorkout = "startWalkingWorkout"
}

nonisolated enum WorkoutSyncSourceDevice: String, Codable, Equatable {
    case phone
    case watch
}

nonisolated enum WorkoutSyncPayloadKind: String, Codable, Equatable {
    case snapshot
    case command
    case acknowledgement
}

nonisolated enum WorkoutCompanionMessageKind: String, Codable, Equatable {
    case launchConfiguration
    case controlCommand
    case syncPayload
}

nonisolated enum WorkoutSessionPhase: String, Codable, Equatable {
    case idle
    case preparing
    case running
    case paused
    case stopping
    case ended
}

nonisolated enum WorkoutConnectionState: String, Codable, Equatable {
    case idle
    case launching
    case awaitingMirror
    case mirrored
    case disconnected
    case reconnecting
    case ended
    case failed
}

nonisolated enum WorkoutControlCommandType: String, Codable, Equatable {
    case pause
    case resume
    case stop
    case end
    case requestSnapshot
}

nonisolated struct WorkoutCompanionStartRequest: Equatable {
    var companionCommand: WorkoutCompanionCommand
    var requestedAt: Date
    var activityTypeRaw: UInt
    var locationTypeRaw: Int

    var dictionaryRepresentation: [String: Any] {
        [
            WorkoutSyncDictionaryKey.companionCommand: companionCommand.rawValue,
            WorkoutSyncDictionaryKey.requestedAt: requestedAt.timeIntervalSince1970,
            WorkoutSyncDictionaryKey.activityTypeRaw: Int(activityTypeRaw),
            WorkoutSyncDictionaryKey.locationTypeRaw: locationTypeRaw
        ]
    }

    init(
        companionCommand: WorkoutCompanionCommand,
        requestedAt: Date,
        activityTypeRaw: UInt,
        locationTypeRaw: Int
    ) {
        self.companionCommand = companionCommand
        self.requestedAt = requestedAt
        self.activityTypeRaw = activityTypeRaw
        self.locationTypeRaw = locationTypeRaw
    }

    init?(dictionary: [String: Any]) {
        guard let rawCommand = dictionary[WorkoutSyncDictionaryKey.companionCommand] as? String,
              let companionCommand = WorkoutCompanionCommand(rawValue: rawCommand),
              let requestedAtValue = Self.doubleValue(for: WorkoutSyncDictionaryKey.requestedAt, in: dictionary),
              let activityTypeValue = Self.intValue(for: WorkoutSyncDictionaryKey.activityTypeRaw, in: dictionary),
              let locationTypeRaw = Self.intValue(for: WorkoutSyncDictionaryKey.locationTypeRaw, in: dictionary),
              activityTypeValue >= 0 else {
            return nil
        }

        self.companionCommand = companionCommand
        self.requestedAt = Date(timeIntervalSince1970: requestedAtValue)
        self.activityTypeRaw = UInt(activityTypeValue)
        self.locationTypeRaw = locationTypeRaw
    }

    private static func doubleValue(for key: String, in dictionary: [String: Any]) -> Double? {
        if let value = dictionary[key] as? Double {
            return value
        }
        if let value = dictionary[key] as? Int {
            return Double(value)
        }
        if let value = dictionary[key] as? NSNumber {
            return value.doubleValue
        }
        if let value = dictionary[key] as? String {
            return Double(value)
        }
        return nil
    }

    private static func intValue(for key: String, in dictionary: [String: Any]) -> Int? {
        if let value = dictionary[key] as? Int {
            return value
        }
        if let value = dictionary[key] as? NSNumber {
            return value.intValue
        }
        if let value = dictionary[key] as? Double {
            return Int(value)
        }
        if let value = dictionary[key] as? String {
            return Int(value)
        }
        return nil
    }
}

nonisolated struct WorkoutSyncSnapshot: Codable, Equatable {
    var hasActiveWorkout: Bool
    var isRunning: Bool
    var workoutName: String
    var activeEnergy: Double
    var distance: Double
    var heartRate: Double
    var elapsedTime: TimeInterval
    var lastUpdated: Date
    var currentState: WorkoutSessionPhase
    var connectionState: WorkoutConnectionState
    var averageHeartRate: Double?
    var workoutType: UInt?
    var sessionId: String?

    init(
        hasActiveWorkout: Bool,
        isRunning: Bool,
        workoutName: String,
        activeEnergy: Double,
        distance: Double,
        heartRate: Double,
        elapsedTime: TimeInterval,
        lastUpdated: Date,
        currentState: WorkoutSessionPhase,
        connectionState: WorkoutConnectionState,
        averageHeartRate: Double? = nil,
        workoutType: UInt? = nil,
        sessionId: String? = nil
    ) {
        self.hasActiveWorkout = hasActiveWorkout
        self.isRunning = isRunning
        self.workoutName = workoutName
        self.activeEnergy = activeEnergy
        self.distance = distance
        self.heartRate = heartRate
        self.elapsedTime = elapsedTime
        self.lastUpdated = lastUpdated
        self.currentState = currentState
        self.connectionState = connectionState
        self.averageHeartRate = averageHeartRate
        self.workoutType = workoutType
        self.sessionId = sessionId
    }

    init(
        state: WorkoutSessionStateDTO,
        sessionId: String?,
        workoutName: String,
        lastUpdated: Date = Date()
    ) {
        self.hasActiveWorkout = !state.currentState.isTerminal
        self.isRunning = state.isRunning
        self.workoutName = workoutName
        self.activeEnergy = state.activeEnergy ?? 0
        self.distance = state.distance ?? 0
        self.heartRate = state.heartRate ?? 0
        self.elapsedTime = state.elapsedTime
        self.lastUpdated = lastUpdated
        self.currentState = state.currentState
        self.connectionState = state.connectionState
        self.averageHeartRate = state.averageHeartRate
        self.workoutType = state.workoutType
        self.sessionId = sessionId
    }

    init?(dictionary: [String: Any]) {
        guard let hasActiveWorkout = Self.boolValue(for: WorkoutSyncDictionaryKey.hasActiveWorkout, in: dictionary),
              let isRunning = Self.boolValue(for: WorkoutSyncDictionaryKey.isRunning, in: dictionary),
              let workoutName = dictionary[WorkoutSyncDictionaryKey.workoutName] as? String,
              let activeEnergy = Self.doubleValue(for: WorkoutSyncDictionaryKey.activeEnergy, in: dictionary),
              let distance = Self.doubleValue(for: WorkoutSyncDictionaryKey.distance, in: dictionary),
              let heartRate = Self.doubleValue(for: WorkoutSyncDictionaryKey.heartRate, in: dictionary),
              let elapsedTime = Self.doubleValue(for: WorkoutSyncDictionaryKey.elapsedTime, in: dictionary),
              let lastUpdatedValue = Self.doubleValue(for: WorkoutSyncDictionaryKey.lastUpdated, in: dictionary),
              let rawState = dictionary[WorkoutSyncDictionaryKey.currentState] as? String,
              let currentState = WorkoutSessionPhase(rawValue: rawState),
              let rawConnectionState = dictionary[WorkoutSyncDictionaryKey.connectionState] as? String,
              let connectionState = WorkoutConnectionState(rawValue: rawConnectionState) else {
            return nil
        }

        self.hasActiveWorkout = hasActiveWorkout
        self.isRunning = isRunning
        self.workoutName = workoutName
        self.activeEnergy = activeEnergy
        self.distance = distance
        self.heartRate = heartRate
        self.elapsedTime = elapsedTime
        self.lastUpdated = Date(timeIntervalSince1970: lastUpdatedValue)
        self.currentState = currentState
        self.connectionState = connectionState
        self.averageHeartRate = Self.doubleValue(for: WorkoutSyncDictionaryKey.averageHeartRate, in: dictionary)

        if let workoutTypeValue = Self.intValue(for: WorkoutSyncDictionaryKey.workoutType, in: dictionary), workoutTypeValue >= 0 {
            self.workoutType = UInt(workoutTypeValue)
        } else {
            self.workoutType = nil
        }

        if let sessionId = dictionary[WorkoutSyncDictionaryKey.sessionId] as? String, !sessionId.isEmpty {
            self.sessionId = sessionId
        } else {
            self.sessionId = nil
        }
    }

    var dictionaryRepresentation: [String: Any] {
        var dictionary: [String: Any] = [
            WorkoutSyncDictionaryKey.hasActiveWorkout: hasActiveWorkout,
            WorkoutSyncDictionaryKey.isRunning: isRunning,
            WorkoutSyncDictionaryKey.workoutName: workoutName,
            WorkoutSyncDictionaryKey.activeEnergy: activeEnergy,
            WorkoutSyncDictionaryKey.distance: distance,
            WorkoutSyncDictionaryKey.heartRate: heartRate,
            WorkoutSyncDictionaryKey.elapsedTime: elapsedTime,
            WorkoutSyncDictionaryKey.lastUpdated: lastUpdated.timeIntervalSince1970,
            WorkoutSyncDictionaryKey.currentState: currentState.rawValue,
            WorkoutSyncDictionaryKey.connectionState: connectionState.rawValue
        ]

        if let averageHeartRate {
            dictionary[WorkoutSyncDictionaryKey.averageHeartRate] = averageHeartRate
        }
        if let workoutType {
            dictionary[WorkoutSyncDictionaryKey.workoutType] = Int(workoutType)
        }
        if let sessionId, !sessionId.isEmpty {
            dictionary[WorkoutSyncDictionaryKey.sessionId] = sessionId
        }

        return dictionary
    }

    func asStateDTO() -> WorkoutSessionStateDTO {
        WorkoutSessionStateDTO(
            workoutType: workoutType,
            currentState: currentState,
            isRunning: isRunning,
            startedAt: nil,
            elapsedTime: elapsedTime,
            heartRate: heartRate,
            averageHeartRate: averageHeartRate,
            activeEnergy: activeEnergy,
            distance: distance,
            lastEvent: nil,
            connectionState: connectionState
        )
    }

    private static func boolValue(for key: String, in dictionary: [String: Any]) -> Bool? {
        if let value = dictionary[key] as? Bool {
            return value
        }
        if let value = dictionary[key] as? NSNumber {
            return value.boolValue
        }
        if let value = dictionary[key] as? String {
            return NSString(string: value).boolValue
        }
        return nil
    }

    private static func doubleValue(for key: String, in dictionary: [String: Any]) -> Double? {
        if let value = dictionary[key] as? Double {
            return value
        }
        if let value = dictionary[key] as? Int {
            return Double(value)
        }
        if let value = dictionary[key] as? NSNumber {
            return value.doubleValue
        }
        if let value = dictionary[key] as? String {
            return Double(value)
        }
        return nil
    }

    private static func intValue(for key: String, in dictionary: [String: Any]) -> Int? {
        if let value = dictionary[key] as? Int {
            return value
        }
        if let value = dictionary[key] as? NSNumber {
            return value.intValue
        }
        if let value = dictionary[key] as? Double {
            return Int(value)
        }
        if let value = dictionary[key] as? String {
            return Int(value)
        }
        return nil
    }
}

nonisolated struct WorkoutSessionStateDTO: Codable, Equatable {
    var workoutType: UInt?
    var currentState: WorkoutSessionPhase
    var isRunning: Bool
    var startedAt: Date?
    var elapsedTime: TimeInterval
    var heartRate: Double?
    var averageHeartRate: Double?
    var activeEnergy: Double?
    var distance: Double?
    var lastEvent: String?
    var connectionState: WorkoutConnectionState
}

nonisolated struct WorkoutControlCommand: Codable, Equatable, Identifiable {
    var commandId: String
    var commandType: WorkoutControlCommandType
    var sessionId: String
    var issuedAt: Date

    var id: String { commandId }
}

nonisolated struct WorkoutSyncAcknowledgement: Codable, Equatable {
    var commandId: String
    var sessionId: String
    var appliedState: WorkoutSessionPhase?
    var failureReason: String?
}

nonisolated struct WorkoutSyncPayload: Codable, Equatable {
    var version: Int
    var sessionId: String
    var sequenceNumber: Int
    var timestamp: Date
    var sourceDevice: WorkoutSyncSourceDevice
    var kind: WorkoutSyncPayloadKind
    var state: WorkoutSessionStateDTO?
    var command: WorkoutControlCommand?
    var acknowledgement: WorkoutSyncAcknowledgement?

    static let currentVersion = 1
}

nonisolated struct WorkoutCompanionMessage: Codable, Equatable, Identifiable {
    var id: String
    var kind: WorkoutCompanionMessageKind
    var timestamp: Date
    var sessionId: String?
    var commandType: WorkoutControlCommandType?
    var activityTypeRaw: UInt?
    var locationTypeRaw: Int?
    var payload: WorkoutSyncPayload?

    static func controlCommand(
        id: String = UUID().uuidString,
        commandType: WorkoutControlCommandType,
        sessionId: String? = nil
    ) -> WorkoutCompanionMessage {
        WorkoutCompanionMessage(
            id: id,
            kind: .controlCommand,
            timestamp: Date(),
            sessionId: sessionId,
            commandType: commandType,
            activityTypeRaw: nil,
            locationTypeRaw: nil,
            payload: nil
        )
    }

    static func syncPayload(_ payload: WorkoutSyncPayload) -> WorkoutCompanionMessage {
        let identifier: String
        if let commandID = payload.command?.commandId {
            identifier = commandID
        } else if let acknowledgementID = payload.acknowledgement?.commandId {
            identifier = "ack:\(acknowledgementID):\(payload.sequenceNumber)"
        } else {
            identifier = "\(payload.sessionId):\(payload.kind.rawValue):\(payload.sequenceNumber)"
        }

        return WorkoutCompanionMessage(
            id: identifier,
            kind: .syncPayload,
            timestamp: payload.timestamp,
            sessionId: payload.sessionId,
            commandType: nil,
            activityTypeRaw: nil,
            locationTypeRaw: nil,
            payload: payload
        )
    }
}

nonisolated extension WorkoutSessionPhase {
    var isTerminal: Bool {
        self == .ended
    }
}
