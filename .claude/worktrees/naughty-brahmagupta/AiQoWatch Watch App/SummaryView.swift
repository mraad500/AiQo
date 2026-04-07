import Foundation
import HealthKit
import SwiftUI
#if canImport(WatchKit)
import WatchKit
#endif

struct SummaryView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    @Environment(\.dismiss) var dismiss
    
    @State private var autoDismissWorkItem: DispatchWorkItem?
    @State private var countdownTimer: Timer?
    @State private var autoDismissRemainingSeconds: Int = 10
    @State private var isClosing = false
    
    @State private var durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()
    
    var body: some View {
        if workoutManager.workout == nil {
            ProgressView("Saving Workout")
                .navigationBarHidden(true)
        } else {
            ScrollView {
                VStack(alignment: .leading) {
                    SummaryMetricView(title: "Total Time",
                                      value: durationFormatter.string(from: workoutManager.workout?.duration ?? 0.0) ?? "")
                        .foregroundStyle(.yellow)
                    
                    SummaryMetricView(title: "Total Distance",
                                      value: Measurement(value: workoutManager.workout?.totalDistance?.doubleValue(for: .meter()) ?? 0,
                                                         unit: UnitLength.meters)
                                        .formatted(.measurement(width: .abbreviated,
                                                                usage: .road,
                                                                numberFormatStyle: .number.precision(.fractionLength(2)))))
                        .foregroundStyle(.green)
                    
                    SummaryMetricView(title: "Total Energy",
                                      value: Measurement(value: workoutManager.workout?.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0,
                                                         unit: UnitEnergy.kilocalories)
                                        .formatted(.measurement(width: .abbreviated,
                                                                usage: .workout,
                                                                numberFormatStyle: .number.precision(.fractionLength(0)))))
                                                    .foregroundStyle(.pink)
                    
                    SummaryMetricView(title: "Avg. Heart Rate",
                                      value: workoutManager.averageHeartRate.formatted(.number.precision(.fractionLength(0))) + " bpm")
                        .foregroundStyle(.red)
                    
                    Text("Activity Rings")
                    ActivityRingsView(healthStore: workoutManager.healthStore)
                        .frame(width: 50, height: 50)
                    
                    Text("Closing in \(max(autoDismissRemainingSeconds, 0))s...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                    
                    Button("Done") {
                        closeSummary()
                    }
                }
                .scenePadding()
            }
            .navigationTitle("Summary")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                startAutoDismissCountdown()
            }
            .onDisappear {
                stopAutoDismissCountdown()
            }
        }
    }

    private func closeSummary() {
        guard !isClosing else { return }
        isClosing = true
        stopAutoDismissCountdown()
        workoutManager.showingSummaryView = false
        dismiss()
    }

    private func startAutoDismissCountdown() {
        stopAutoDismissCountdown()
        isClosing = false
        autoDismissRemainingSeconds = 10

        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if autoDismissRemainingSeconds > 0 {
                autoDismissRemainingSeconds -= 1
            }
        }
        countdownTimer = timer

        let workItem = DispatchWorkItem {
            closeSummary()
        }
        autoDismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: workItem)
    }

    private func stopAutoDismissCountdown() {
        autoDismissWorkItem?.cancel()
        autoDismissWorkItem = nil
        countdownTimer?.invalidate()
        countdownTimer = nil
    }
}

struct SummaryMetricView: View {
    var title: String
    var value: String

    var body: some View {
        Text(title)
            .foregroundStyle(.foreground)
        Text(value)
            .font(.system(.title2, design: .rounded).lowercaseSmallCaps())
        Divider()
    }
}
