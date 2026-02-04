import Foundation

protocol ConnectivityDebugProviding: ObservableObject {
    var activationStateText: String { get }
    var reachabilityText: String { get }
    var lastReceived: String { get }
    var lastError: String { get }
}
