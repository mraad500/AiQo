import Foundation

protocol ConnectivityDebugProviding: ObservableObject {
    var activationStateText: String { get }
    var reachabilityText: String { get }
    var lastReceived: String { get }
    var lastSent: String { get }
    var lastError: String { get }
    var pendingQueueCount: Int { get }
    var currentWorkoutStateText: String { get }
    var currentWorkoutId: String? { get }
}
