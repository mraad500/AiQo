// =====================================================
// File: Shared/WorkoutWC.swift
// Target Membership: iOS + watchOS  ✅
// =====================================================

import Foundation

enum WorkoutWC {
    static let version = 1

    enum Command: String {
        case start
        case pause
        case resume
        case end
    }

    enum MessageType: String {
        case workoutCommand = "workout_command"
        case workoutState = "workout_state"
        case liveMetrics = "live_metrics"
        case workoutSummary = "workout_summary"
        case commandAck = "command_ack"
    }

    enum Key {
        static let v = "v"
        static let type = "type"
        static let timestamp = "timestamp"

        static let workoutID = "workoutID"
        static let command = "command"

        static let activityTypeRaw = "activityTypeRaw"
        static let locationTypeRaw = "locationTypeRaw"

        // legacy compatibility
        static let payload = "payload"
    }
}
