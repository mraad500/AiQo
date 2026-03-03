import Foundation

protocol ConnectivityDebugProviding: ObservableObject {
    var activationStateText: String { get }
    var reachabilityText: String { get }
    var lastReceived: String { get }
    var lastSent: String { get }
    var lastError: String { get }
    var lastAcknowledgementText: String { get }
    var connectionStateText: String { get }
    var currentWorkoutStateText: String { get }
    var currentWorkoutId: String? { get }
    var eventLog: [String] { get }
}
