import SwiftUI
import WatchConnectivity

struct ConnectivityDiagnosticsView: View {
    @ObservedObject var manager = PhoneConnectivityManager.shared

    var body: some View {
        List {
            Section("Mirror State") {
                Text("Connection: \(manager.connectionStateText)")
                Text("Workout: \(manager.currentWorkoutStateText)")
                Text("Session ID: \(manager.currentWorkoutId ?? "None")")
                Text("Mirrored Session: \(manager.hasMirroredSession.description)")
                Text("Command In Flight: \(manager.isCommandInFlight.description)")
            }

            Section("Watch Connectivity") {
                Text("activationState: \(manager.activationStateText)")
                Text("reachability: \(manager.reachabilityText)")
                Text("isPaired: \(manager.isPaired.description)")
                Text("isWatchAppInstalled: \(manager.isWatchAppInstalled.description)")
            }

            Section("Actions") {
                Button("Re-Activate Session") {
                    if WCSession.isSupported() {
                        WCSession.default.activate()
                    }
                }

                Button("Launch Watch Workout") {
                    manager.startWorkoutOnWatch(activityTypeRaw: 37, locationTypeRaw: 2)
                }

                Button("Request Snapshot") {
                    manager.requestLatestSnapshot()
                }

                Button("Pause") {
                    manager.pauseWorkoutOnWatch()
                }

                Button("Resume") {
                    manager.resumeWorkoutOnWatch()
                }

                Button("End") {
                    manager.endWorkoutOnWatch()
                }
            }

            Section("Traffic") {
                Text("Last Sent: \(manager.lastSent)")
                    .font(.footnote)

                Text(manager.lastReceived)
                    .font(.footnote)

                Text("Last Ack: \(manager.lastAcknowledgementText)")
                    .font(.footnote)
            }

            Section("Last Error") {
                Text(manager.lastError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Section("Recent Events") {
                ForEach(Array(manager.eventLog.enumerated()), id: \.offset) { _, entry in
                    Text(entry)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Workout Diagnostics")
    }
}

struct ConnectivityDiagnosticsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ConnectivityDiagnosticsView()
        }
    }
}
