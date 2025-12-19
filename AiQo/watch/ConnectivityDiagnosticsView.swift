import SwiftUI
import WatchConnectivity

#if os(iOS)

struct ConnectivityDiagnosticsView: View {

    @ObservedObject private var m = PhoneConnectivityManager.shared

    var body: some View {
        List {
            Section("State") {
                Text("activationState: \(activationText)")
                Text("isPaired: \(m.isPaired.description)")
                Text("isWatchAppInstalled: \(m.isWatchAppInstalled.description)")
                Text("isReachable: \(m.isReachable.description)")
            }

            Section("Test") {
                Button("Activate") { m.activate() }
                Button("Ping") { m.sendPing() }
            }

            Section("Last Received") {
                Text(m.lastReceived).font(.footnote)
            }

            Section("Last Error") {
                Text(m.lastError).font(.footnote)
            }
        }
        .navigationTitle("WC Diagnostics")
    }

    private var activationText: String {
        switch m.activationState {
        case .notActivated: return "notActivated"
        case .inactive: return "inactive"
        case .activated: return "activated"
        @unknown default: return "unknown"
        }
    }
}

#else

struct ConnectivityDiagnosticsView: View {

    @ObservedObject private var m = WatchConnectivityManager.shared

    var body: some View {
        List {
            Section("State") {
                Text("activationState: \(activationText)")
                Text("isReachable: \(m.isReachable.description)")
            }

            Section("Test") {
                Button("Activate") { m.activate() }
                Button("Ping") { m.sendPing() }
            }

            Section("Last Received") {
                Text(m.lastReceived).font(.footnote)
            }

            Section("Last Error") {
                Text(m.lastError).font(.footnote)
            }
        }
        .navigationTitle("WC Diagnostics")
    }

    private var activationText: String {
        switch m.activationState {
        case .notActivated: return "notActivated"
        case .inactive: return "inactive"
        case .activated: return "activated"
        @unknown default: return "unknown"
        }
    }
}

#endif
