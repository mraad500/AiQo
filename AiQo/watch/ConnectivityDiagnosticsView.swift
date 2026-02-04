import SwiftUI
import WatchConnectivity

struct ConnectivityDiagnosticsView: View {
    
    @ObservedObject var manager = PhoneConnectivityManager.shared

    var body: some View {
        List {
            Section("State") {
                Text("activationState: \(activationText)")
                Text("isReachable: \(manager.isReachable.description)")
                Text("isPaired: \(manager.isPaired.description)")
                Text("isWatchAppInstalled: \(manager.isWatchAppInstalled.description)")
            }
            
            Section("Test") {
                Button("Re-Activate Session") {
                    if WCSession.isSupported() {
                        WCSession.default.activate()
                    }
                }
                
                Button("Send Start Command") {
                    // ✅ التصحيح: نمرر بيانات افتراضية (جري) للتجربة
                    manager.startWorkoutOnWatch(activityTypeRaw: 37, locationTypeRaw: 2)
                }
            }
            
            Section("Last Received") {
                Text(manager.lastReceived)
                    .font(.footnote)
            }
            
            Section("Last Error") {
                Text(manager.lastError)
                    .font(.footnote)
                    .foregroundColor(.red)
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

struct ConnectivityDiagnosticsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ConnectivityDiagnosticsView()
        }
    }
}
