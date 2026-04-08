import Foundation
import HealthKit
import SwiftUI
#if canImport(WatchKit)
import WatchKit
#endif

struct SummaryView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    @Environment(\.dismiss) var dismiss
    @Environment(\.locale) private var locale
    
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
            ProgressView(WatchText.localized(ar: "جارٍ حفظ التمرين", en: "Saving Workout", locale: locale))
                .navigationBarHidden(true)
        } else {
            ScrollView {
                VStack(alignment: .leading) {
                    SummaryMetricView(title: WatchText.localized(ar: "الوقت الكلي", en: "Total Time", locale: locale),
                                      value: durationFormatter.string(from: workoutManager.workout?.duration ?? 0.0) ?? "")
                        .foregroundStyle(.yellow)
                    
                    SummaryMetricView(title: WatchText.localized(ar: "المسافة الكلية", en: "Total Distance", locale: locale),
                                      value: Measurement(value: workoutManager.workout?.totalDistance?.doubleValue(for: .meter()) ?? 0,
                                                         unit: UnitLength.meters)
                                        .formatted(.measurement(width: .abbreviated,
                                                                usage: .road,
                                                                numberFormatStyle: .number.precision(.fractionLength(2)))))
                        .foregroundStyle(.green)
                    
                    SummaryMetricView(title: WatchText.localized(ar: "الطاقة الكلية", en: "Total Energy", locale: locale),
                                      value: Measurement(value: workoutManager.workout?.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0,
                                                         unit: UnitEnergy.kilocalories)
                                        .formatted(.measurement(width: .abbreviated,
                                                                usage: .workout,
                                                                numberFormatStyle: .number.precision(.fractionLength(0)))))
                                                    .foregroundStyle(.pink)
                    
                    SummaryMetricView(title: WatchText.localized(ar: "متوسط النبض", en: "Avg. Heart Rate", locale: locale),
                                      value: workoutManager.averageHeartRate.formatted(.number.precision(.fractionLength(0))) + " bpm")
                        .foregroundStyle(.red)
                    
                    Text(WatchText.localized(ar: "حلقات النشاط", en: "Activity Rings", locale: locale))
                    ActivityRingsView(healthStore: workoutManager.healthStore)
                        .frame(width: 50, height: 50)
                    
                    Text(
                        WatchText.localized(
                            ar: "الإغلاق خلال \(WatchText.number(max(autoDismissRemainingSeconds, 0), locale: locale)) ث",
                            en: "Closing in \(max(autoDismissRemainingSeconds, 0))s...",
                            locale: locale
                        )
                    )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                    
                    Button(WatchText.localized(ar: "تم", en: "Done", locale: locale)) {
                        closeSummary()
                    }
                }
                .scenePadding()
            }
            .navigationTitle(WatchText.localized(ar: "الملخص", en: "Summary", locale: locale))
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
