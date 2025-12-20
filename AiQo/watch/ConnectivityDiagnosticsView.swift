import SwiftUI
import WatchConnectivity

struct ConnectivityDiagnosticsView: View {
    
    #if os(iOS)
    @ObservedObject var manager: PhoneConnectivityManager = .shared
    #else
    @ObservedObject var manager: WatchConnectivityManager = .shared
    #endif

    var body: some View {
        List {
            Section("State") {
                Text("activationState: \(activationText)")
                Text("isReachable: \(manager.isReachable.description)")
                #if os(iOS)
                // Use the underlying Bool (manager.isPaired), not the Binding ($manager.isPaired)
                Text("isPaired: \(manager.isPaired.description)")
                Text("isWatchAppInstalled: \(manager.isWatchAppInstalled.description)")
                #endif
            }

            Section("Test") {
                Button("Activate") { manager.activate() }
                // ✅ هذا السطر الآن سيعمل في كلا النظامين لأننا أضفنا sendPing في الملفين
                Button("Ping") { manager.sendPing() }
            }

            Section("Last Received") {
                Text(manager.lastReceived).font(.footnote)
            }

            Section("Last Error") {
                Text(manager.lastError).font(.footnote)
            }
        }
        .navigationTitle("WC Diagnostics")
    }

    private var activationText: String {
        switch manager.activationState {
        case .notActivated: return "notActivated"
        case .inactive: return "inactive"
        case .activated: return "activated"
        @unknown default: return "unknown"
        }
    }
}
