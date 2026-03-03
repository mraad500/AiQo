import Foundation

nonisolated enum WorkoutSyncSourceDevice: String, Codable, Equatable {
    case phone
    case watch
}

nonisolated enum WorkoutSyncPayloadKind: String, Codable, Equatable {
    case snapshot
    case command
    case acknowledgement
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

nonisolated extension WorkoutSessionPhase {
    var isTerminal: Bool {
        self == .ended
    }
}
