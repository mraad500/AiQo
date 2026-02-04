import Foundation

public enum WCCommand: String, Codable {
    case startWorkout
    case endWorkout
    case pauseWorkout
    case resumeWorkout
}
