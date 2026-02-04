import Foundation

public enum WorkoutState: String, Codable {
    case idle
    case running
    case paused
    case stopped
}

// هيكل يحمل الحالة وتوقيتها
public struct WorkoutStatePayload: Codable {
    public let state: WorkoutState
    public let workoutID: String?
    public let date: Date
    
    public init(state: WorkoutState, workoutID: String?, date: Date = Date()) {
        self.state = state
        self.workoutID = workoutID
        self.date = date
    }
}
