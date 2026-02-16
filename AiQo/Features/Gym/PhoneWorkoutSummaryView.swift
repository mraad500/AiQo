import SwiftUI
import HealthKit
import Charts
internal import Combine

// ===============================
// File: PhoneWorkoutSummaryView.swift
// ===============================

struct PhoneWorkoutSummaryView: View {

    // MARK: - Data Inputs
    let duration: TimeInterval
    let calories: Double
    let avgHeartRate: Double
    let heartRateSamples: [HKQuantitySample]
    let recovery1: Int?
    let recovery2: Int?

    // MARK: - State
    @State private var result: XPCalculator.XPResult?
    @State private var appearAnimation: Bool = false
    @StateObject private var heartAnalytics = WorkoutHeartRateAnalyticsStore()
    @State private var showHeartDeepDive = false

    // Action
    var onDismiss: () -> Void

    init(
        duration: TimeInterval,
        calories: Double,
        avgHeartRate: Double,
        heartRateSamples: [HKQuantitySample],
        recovery1: Int? = nil,
        recovery2: Int? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self.duration = duration
        self.calories = calories
        self.avgHeartRate = avgHeartRate
        self.heartRateSamples = heartRateSamples
        self.recovery1 = recovery1
        self.recovery2 = recovery2
        self.onDismiss = onDismiss
    }

    var body: some View {
        ZStack {
            // Background (modern: stars + haze + vignette)
            SpaceBackdrop()
                .ignoresSafeArea()

            if let data = result {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {

                        // Top labels
                        VStack(spacing: 6) {
                            Text("WORKOUT SUMMARY")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .tracking(4)
                                .foregroundStyle(.white.opacity(0.35))

                            Text("WORKOUT COMPLETE")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .tracking(5)
                                .foregroundStyle(.white.opacity(0.80))
                        }
                        .padding(.top, 44)

                        // Big XP
                        VStack(spacing: 6) {
                            Text("\(data.totalXP)")
                                .font(.system(size: 118, weight: .black, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [
                                            .brandMint.opacity(0.95),
                                            .brandMint.opacity(0.75)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .shadow(color: .brandMint.opacity(0.55), radius: 26, x: 0, y: 0)
                                .shadow(color: .black.opacity(0.65), radius: 24, x: 0, y: 18)
                                .scaleEffect(appearAnimation ? 1.0 : 0.92)
                                .opacity(appearAnimation ? 1.0 : 0.0)

                            Text("XP EARNED")
                                .font(.system(size: 20, weight: .heavy, design: .rounded))
                                .tracking(2)
                                .foregroundStyle(.white.opacity(0.55))
                        }
                        .padding(.top, 6)

                        // Metric cards row
                        HStack(spacing: 14) {
                            ModernMetricCard(
                                title: "TIME",
                                value: formatTime(duration),
                                sub: "min",
                                icon: "stopwatch.fill",
                                delay: 0.10
                            )

                            ModernMetricCard(
                                title: "KCAL",
                                value: "\(Int(calories))",
                                sub: "cal",
                                icon: "flame.fill",
                                delay: 0.18
                            )

                            ModernMetricCard(
                                title: "AVG HR",
                                value: "\(Int(avgHeartRate))",
                                sub: "bpm",
                                icon: "heart.fill",
                                delay: 0.26
                            )
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 8)

                        if recovery1 != nil || recovery2 != nil {
                            HStack(spacing: 14) {
                                RecoveryMetricCard(
                                    title: "RECOVERY 1",
                                    value: recoveryCardValue(recovery1),
                                    sub: "Peak - 1 min",
                                    icon: "heart.circle.fill",
                                    delay: 0.30
                                )

                                RecoveryMetricCard(
                                    title: "RECOVERY 2",
                                    value: recoveryCardValue(recovery2),
                                    sub: "Peak - 2 min",
                                    icon: "heart.circle",
                                    delay: 0.34
                                )
                            }
                            .padding(.horizontal, 18)
                        }

                        HeartRateZoneSummaryCard(
                            analytics: heartAnalytics,
                            delay: 0.34
                        ) {
                            showHeartDeepDive = true
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 2)
                        .opacity(appearAnimation ? 1 : 0)
                        .offset(y: appearAnimation ? 0 : 14)

                        // Logic container
                        LogicContainer {
                            HStack(spacing: 14) {
                                ModernLogicCard(
                                    title: "Truth Number",
                                    header: "CAL + TIME",
                                    subHeader: nil,
                                    equation: "\(data.activeCalories) + \(data.durationMinutes)",
                                    result: "\(data.truthNumber)",
                                    tint: .brandSand,
                                    delay: 0.42
                                )

                                ModernLogicCard(
                                    title: "Lucky Number",
                                    header: "Total Heartbeats",
                                    subHeader: "\(data.totalHeartbeats) HR",
                                    equation: data.heartbeatDigits.map(String.init).joined(separator: "+"),
                                    result: "\(data.luckyNumber)",
                                    tint: .brandMint,
                                    delay: 0.50
                                )
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 8)
                        .opacity(appearAnimation ? 1 : 0)
                        .offset(y: appearAnimation ? 0 : 18)

                        // Done button (✅ تم التعديل هنا)
                        Button(action: {
                            saveXPAndDismiss(xp: data.totalXP)
                        }) {
                            Text("Done")
                                .font(.system(size: 22, weight: .black, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .frame(height: 62)
                                .background(.white)
                                .foregroundStyle(.black)
                                .clipShape(Capsule())
                                .shadow(color: .black.opacity(0.55), radius: 22, x: 0, y: 14)
                        }
                        .padding(.horizontal, 26)
                        .padding(.top, 8)
                        .padding(.bottom, 34)
                    }
                }
            } else {
                ProgressView()
                    .tint(.brandMint)
            }
        }
        .sheet(isPresented: $showHeartDeepDive) {
            HeartRateZoneDeepDiveView(analytics: heartAnalytics)
        }
        .onAppear {
            heartAnalytics.startStreaming(
                duration: duration,
                fallbackAverageHeartRate: avgHeartRate,
                seedSamples: heartRateSamples
            )
            calculateStats()
        }
        .onDisappear {
            heartAnalytics.stopStreaming()
        }
        .onChange(of: heartAnalytics.samples.count) { _, _ in
            calculateStats()
        }
    }

    // MARK: - Logic Execution
    private func calculateStats() {
        let samplesForXP = resolvedHeartRateSamples
        DispatchQueue.global(qos: .userInitiated).async {
            // ✅ افترضنا وجود كلاس XPCalculator في مشروعك كما هو
            let computedResult = XPCalculator.calculateSessionStats(
                samples: samplesForXP,
                duration: duration,
                averageHeartRate: avgHeartRate,
                activeCalories: calories
            )
            DispatchQueue.main.async {
                self.result = computedResult
                withAnimation(.spring(response: 0.75, dampingFraction: 0.82)) {
                    appearAnimation = true
                }
            }
        }
    }

    // ✅ دالة جديدة: حفظ النقاط وحساب المستوى الجديد
    private func saveXPAndDismiss(xp: Int) {
        // 1. جلب البيانات الحالية
        let defaults = UserDefaults.standard
        let currentLevel = max(defaults.integer(forKey: "aiqo.currentLevel"), 1)
        let currentProgress = defaults.double(forKey: "aiqo.currentLevelProgress") // 0.0 to 1.0
        let currentTotalScore = defaults.integer(forKey: "aiqo.legacyTotalPoints")

        // 2. تحديث مجموع النقاط (Line Score)
        let newTotalScore = currentTotalScore + xp
        defaults.set(newTotalScore, forKey: "aiqo.legacyTotalPoints")

        // 3. منطق حساب المستوى (Level Up Logic)
        // لنفترض معادلة بسيطة: كل مستوى يحتاج (المستوى الحالي * 500) نقطة لملء البار
        // يمكنك تعديل الرقم 500 ليصبح أصعب أو أسهل
        var level = currentLevel
        var xpRequiredForNextLevel = Double(level * 500)
        
        // حساب الـ XP الحالي المتراكم داخل هذا المستوى فقط
        var currentXPInLevel = currentProgress * xpRequiredForNextLevel
        
        // إضافة الـ XP الجديد
        currentXPInLevel += Double(xp)
        
        // حلقة تكرار: هل تجاوزنا الحد المطلوب للمستوى التالي؟
        while currentXPInLevel >= xpRequiredForNextLevel {
            currentXPInLevel -= xpRequiredForNextLevel // نخصم تكلفة الصعود
            level += 1                                 // نرفع المستوى
            xpRequiredForNextLevel = Double(level * 500) // التكلفة للمستوى الذي يليه
        }
        
        // حساب النسبة المئوية الجديدة (0.0 - 1.0)
        let newProgress = currentXPInLevel / xpRequiredForNextLevel
        
        // 4. حفظ البيانات الجديدة
        defaults.set(level, forKey: "aiqo.currentLevel")
        defaults.set(newProgress, forKey: "aiqo.currentLevelProgress")
        
        // 5. إرسال إشعار ليعلم LevelCardView بالتحديث
        NotificationCenter.default.post(name: NSNotification.Name("XPUpdated"), object: nil)
        
        // 6. إغلاق الشاشة
        onDismiss()
    }

    private func formatTime(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%02d:%02d", m, s)
    }

    private func recoveryCardValue(_ value: Int?) -> String {
        guard let value else { return "--" }
        return "\(value)"
    }

    private var resolvedHeartRateSamples: [HKQuantitySample] {
        if !heartAnalytics.samples.isEmpty {
            return heartAnalytics.samples
        }
        return heartRateSamples
    }
}

// ====================================
// MARK: - Background (Space, modern)
// ====================================

private struct SpaceBackdrop: View {
    var body: some View {
        ZStack {
            // Deep base
            LinearGradient(
                colors: [
                    Color.black,
                    Color.black.opacity(0.95),
                    Color.black.opacity(0.92)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Soft nebula/haze
            GeometryReader { geo in
                Circle()
                    .fill(Color.brandMint.opacity(0.10))
                    .frame(width: geo.size.width * 0.90, height: geo.size.width * 0.90)
                    .blur(radius: 120)
                    .position(x: geo.size.width * 0.62, y: geo.size.height * 0.34)

                Circle()
                    .fill(Color.brandSand.opacity(0.08))
                    .frame(width: geo.size.width * 0.75, height: geo.size.width * 0.75)
                    .blur(radius: 140)
                    .position(x: geo.size.width * 0.28, y: geo.size.height * 0.66)
            }

            // Starfield (Canvas)
            Starfield()
                .opacity(0.75)
                .blendMode(.screen)

            // Vignette (key for readability)
            RadialGradient(
                colors: [
                    Color.black.opacity(0.12),
                    Color.black.opacity(0.70),
                    Color.black.opacity(0.92)
                ],
                center: .center,
                startRadius: 80,
                endRadius: 520
            )
            .blendMode(.multiply)
        }
    }
}

private struct Starfield: View {
    var body: some View {
        Canvas { context, size in
            // Deterministic stars without random() calls per frame
            let stars: [Star] = Star.seeded(count: 140, in: size)

            for s in stars {
                var path = Path()
                path.addEllipse(in: CGRect(x: s.x, y: s.y, width: s.r, height: s.r))
                context.fill(path, with: .color(Color.white.opacity(s.a)))
            }
        }
        .ignoresSafeArea()
    }

    private struct Star {
        let x: CGFloat
        let y: CGFloat
        let r: CGFloat
        let a: CGFloat

        static func seeded(count: Int, in size: CGSize) -> [Star] {
            var out: [Star] = []
            out.reserveCapacity(count)

            // Simple deterministic generator
            var seed: UInt64 = 0xA1C020251227
            func next() -> UInt64 {
                seed = seed &* 6364136223846793005 &+ 1
                return seed
            }

            for _ in 0..<count {
                let nx = Double(next() % 10_000) / 10_000.0
                let ny = Double(next() % 10_000) / 10_000.0
                let nr = Double(next() % 1_000) / 1_000.0
                let na = Double(next() % 1_000) / 1_000.0

                let x = CGFloat(nx) * size.width
                let y = CGFloat(ny) * size.height
                let r = CGFloat(1.0 + nr * 2.2) // 1...3.2
                let a = CGFloat(0.10 + na * 0.35) // 0.10...0.45

                out.append(Star(x: x, y: y, r: r, a: a))
            }
            return out
        }
    }
}

// ====================================
// MARK: - Metric Card (modern)
// ====================================

private struct ModernMetricCard: View {
    let title: String
    let value: String
    let sub: String
    let icon: String
    let delay: Double

    @State private var show = false

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white.opacity(0.90))
                .padding(.top, 14)

            VStack(spacing: 2) {
                Text(value)
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)

                Text(sub)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
            }

            Spacer(minLength: 0)

            Text(title)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.45))

            // Bottom indicator
            Capsule()
                .fill(.white.opacity(0.18))
                .frame(width: 34, height: 3)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 126)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.55), radius: 18, x: 0, y: 12)
        .opacity(show ? 1 : 0)
        .scaleEffect(show ? 1 : 0.94)
        .onAppear {
            withAnimation(.spring(response: 0.70, dampingFraction: 0.85).delay(delay)) {
                show = true
            }
        }
    }
}

private struct RecoveryMetricCard: View {
    let title: String
    let value: String
    let sub: String
    let icon: String
    let delay: Double

    @State private var show = false

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white.opacity(0.90))
                .padding(.top, 14)

            Text(value)
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Text("BPM")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.66))

            Spacer(minLength: 0)

            Text(title)
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .tracking(1.3)
                .foregroundStyle(.white.opacity(0.62))

            Text(sub)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.50))
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 136)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.55), radius: 18, x: 0, y: 12)
        .opacity(show ? 1 : 0)
        .scaleEffect(show ? 1 : 0.94)
        .onAppear {
            withAnimation(.spring(response: 0.70, dampingFraction: 0.85).delay(delay)) {
                show = true
            }
        }
    }
}

// ====================================
// MARK: - Logic Container (modern)
// ====================================

private struct LogicContainer<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.65), radius: 26, x: 0, y: 18)
    }
}

// ====================================
// MARK: - Logic Cards (Truth / Lucky)
// ====================================

private struct ModernLogicCard: View {
    let title: String
    let header: String
    let subHeader: String?
    let equation: String
    let result: String
    let tint: Color
    let delay: Double

    @State private var show = false

    var body: some View {
        VStack(spacing: 10) {

            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .padding(.top, 6)

            VStack(spacing: 8) {
                Text(header.uppercased())
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.72))
                    .padding(.top, 16)

                if let subHeader {
                    Text(subHeader)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.50))
                        .padding(.top, -4)
                }

                Spacer(minLength: 0)

                Text(equation)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.95))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.60)
                    .padding(.horizontal, 10)

                Spacer(minLength: 0)

                Text("= \(result)")
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 8)
                    .padding(.bottom, 18)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 170)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(tint.opacity(0.92))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(.white.opacity(0.16), lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity)
        .opacity(show ? 1 : 0)
        .offset(y: show ? 0 : 12)
        .onAppear {
            withAnimation(.spring(response: 0.75, dampingFraction: 0.88).delay(delay)) {
                show = true
            }
        }
    }
}

// ====================================
// MARK: - Heart Analytics Models
// ====================================

private enum HeartRateZoneBucket: String, CaseIterable, Identifiable {
    case below
    case zone2
    case peak

    var id: String { rawValue }

    var title: String {
        switch self {
        case .below: return "Below"
        case .zone2: return "Zone 2"
        case .peak: return "Peak/Above"
        }
    }

    var color: Color {
        switch self {
        case .below: return .blue
        case .zone2: return .green
        case .peak: return .orange
        }
    }
}

private struct HeartRateZoneSlice: Identifiable {
    let zone: HeartRateZoneBucket
    let seconds: Double
    let percentage: Double

    var id: String { zone.id }
    var minutes: Double { seconds / 60.0 }
}

private struct HeartRateLinePoint: Identifiable {
    let time: Date
    let elapsedMinutes: Double
    let bpm: Double

    var id: TimeInterval { time.timeIntervalSince1970 }
}

private struct HeartRateRecoveryPoint: Identifiable {
    let elapsedSeconds: Double
    let bpm: Double

    var id: Double { elapsedSeconds }
}

private struct HeartRatePeakMoment: Identifiable {
    let time: Date
    let bpm: Double

    var id: TimeInterval { time.timeIntervalSince1970 }

    var timestampText: String {
        Self.formatter.string(from: time)
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}

// ====================================
// MARK: - Heart Analytics Store
// ====================================

@MainActor
private final class WorkoutHeartRateAnalyticsStore: ObservableObject {
    @Published private(set) var samples: [HKQuantitySample] = []
    @Published private(set) var linePoints: [HeartRateLinePoint] = []
    @Published private(set) var zoneSlices: [HeartRateZoneSlice] = HeartRateZoneBucket.allCases.map {
        HeartRateZoneSlice(zone: $0, seconds: 0, percentage: 0)
    }
    @Published private(set) var recoveryPoints: [HeartRateRecoveryPoint] = []
    @Published private(set) var peakMoments: [HeartRatePeakMoment] = []
    @Published private(set) var zoneLowerBound: Double = 0
    @Published private(set) var zoneUpperBound: Double = 0
    @Published private(set) var isLoading = false

    private let healthStore = HKHealthStore()
    private var anchoredQuery: HKAnchoredObjectQuery?
    private var queryAnchor: HKQueryAnchor?
    private var sampleMap: [UUID: HKQuantitySample] = [:]

    private var workoutStartDate: Date?
    private var workoutEndDate: Date?
    private var maxAcceptedDate: Date?
    private var fallbackAverageHeartRate: Double = 0
    private var expectedDuration: TimeInterval = 0

    func startStreaming(
        duration: TimeInterval,
        fallbackAverageHeartRate: Double,
        seedSamples: [HKQuantitySample]
    ) {
        stopStreaming()

        self.fallbackAverageHeartRate = fallbackAverageHeartRate
        expectedDuration = max(duration, 60)

        let now = Date()
        workoutStartDate = now.addingTimeInterval(-expectedDuration - 90)
        workoutEndDate = now
        maxAcceptedDate = now.addingTimeInterval(20 * 60)

        mergeSamples(seedSamples)
        recomputeDerivedMetrics()

        Task {
            await prepareHealthKitStreaming()
        }
    }

    func stopStreaming() {
        if let anchoredQuery {
            healthStore.stop(anchoredQuery)
        }
        anchoredQuery = nil
        queryAnchor = nil
    }

    var totalTrackedMinutes: Double {
        zoneSlices.reduce(0) { $0 + $1.minutes }
    }

    func minutes(for zone: HeartRateZoneBucket) -> Double {
        zoneSlices.first(where: { $0.zone == zone })?.minutes ?? 0
    }

    var heartRateYDomain: ClosedRange<Double> {
        guard !linePoints.isEmpty else { return 70...180 }
        let values = linePoints.map(\.bpm)
        let minValue = max(45, (values.min() ?? 70) - 10)
        let maxValue = min(225, (values.max() ?? 180) + 10)
        if maxValue - minValue < 20 {
            let center = (minValue + maxValue) / 2
            return (center - 12)...(center + 12)
        }
        return minValue...maxValue
    }

    private func prepareHealthKitStreaming() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        guard await requestAuthorization() else { return }

        isLoading = true
        if let matchedWorkout = await fetchMatchingWorkout() {
            workoutStartDate = matchedWorkout.startDate
            workoutEndDate = matchedWorkout.endDate
            maxAcceptedDate = matchedWorkout.endDate.addingTimeInterval(25 * 60)
        }

        let initialSamples = await queryHeartRateSamples(
            start: workoutStartDate ?? Date().addingTimeInterval(-expectedDuration),
            end: maxAcceptedDate ?? Date()
        )
        mergeSamples(initialSamples)
        recomputeDerivedMetrics()
        startAnchoredQuery()
        isLoading = false
    }

    private func requestAuthorization() async -> Bool {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return false }
        let readTypes: Set<HKObjectType> = [heartRateType, HKObjectType.workoutType()]

        do {
            try await healthStore.requestAuthorization(toShare: Set<HKSampleType>(), read: readTypes)
            return true
        } catch {
            return false
        }
    }

    private func fetchMatchingWorkout() async -> HKWorkout? {
        let now = Date()
        let lookback = now.addingTimeInterval(-6 * 3600)
        let expectedDuration = expectedDuration
        let predicate = HKQuery.predicateForSamples(
            withStart: lookback,
            end: now.addingTimeInterval(10 * 60),
            options: .strictStartDate
        )
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: 10,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                let workouts = (samples as? [HKWorkout]) ?? []
                let maxDiff = max(240, expectedDuration * 0.45)
                let matched = workouts.first {
                    abs($0.duration - expectedDuration) <= maxDiff &&
                    abs(now.timeIntervalSince($0.endDate)) <= 1800
                }
                continuation.resume(returning: matched)
            }
            healthStore.execute(query)
        }
    }

    private func queryHeartRateSamples(start: Date, end: Date) async -> [HKQuantitySample] {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return [] }
        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: .strictStartDate
        )
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKQuantitySample]) ?? [])
            }
            healthStore.execute(query)
        }
    }

    private func startAnchoredQuery() {
        guard anchoredQuery == nil,
              let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate),
              let workoutStartDate else {
            return
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: workoutStartDate,
            end: nil,
            options: .strictStartDate
        )

        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: predicate,
            anchor: queryAnchor,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, newAnchor, _ in
            guard let self else { return }
            Task { @MainActor in
                self.queryAnchor = newAnchor
                self.mergeSamples((samples as? [HKQuantitySample]) ?? [])
                self.recomputeDerivedMetrics()
            }
        }

        query.updateHandler = { [weak self] _, samples, _, newAnchor, _ in
            guard let self else { return }
            Task { @MainActor in
                self.queryAnchor = newAnchor
                self.mergeSamples((samples as? [HKQuantitySample]) ?? [])
                self.recomputeDerivedMetrics()
            }
        }

        anchoredQuery = query
        healthStore.execute(query)
    }

    private func mergeSamples(_ incoming: [HKQuantitySample]) {
        guard !incoming.isEmpty else { return }

        let lowerBound = workoutStartDate?.addingTimeInterval(-30)
        for sample in incoming {
            if let lowerBound, sample.startDate < lowerBound {
                continue
            }
            if let maxAcceptedDate, sample.startDate > maxAcceptedDate {
                continue
            }
            sampleMap[sample.uuid] = sample
        }

        samples = sampleMap.values.sorted { $0.startDate < $1.startDate }
    }

    private func recomputeDerivedMetrics() {
        let bounds = resolveZoneBounds()
        zoneLowerBound = bounds.lower
        zoneUpperBound = bounds.upper

        guard !samples.isEmpty else {
            generateFallbackLinePoints()
            zoneSlices = HeartRateZoneBucket.allCases.map {
                HeartRateZoneSlice(zone: $0, seconds: 0, percentage: 0)
            }
            recoveryPoints = []
            peakMoments = []
            return
        }

        let start = workoutStartDate ?? samples.first?.startDate ?? Date()
        let end = workoutEndDate ?? Date()
        let sorted = samples.sorted { $0.startDate < $1.startDate }
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())

        var belowSeconds = 0.0
        var zone2Seconds = 0.0
        var peakSeconds = 0.0

        for index in sorted.indices {
            let sample = sorted[index]
            let bpm = sample.quantity.doubleValue(for: bpmUnit)
            let nextDate = index < sorted.count - 1 ? sorted[index + 1].startDate : end
            let durationSeconds = max(1, min(nextDate.timeIntervalSince(sample.startDate), 20))

            if bpm < bounds.lower {
                belowSeconds += durationSeconds
            } else if bpm <= bounds.upper {
                zone2Seconds += durationSeconds
            } else {
                peakSeconds += durationSeconds
            }
        }

        let trackedSeconds = max(1, belowSeconds + zone2Seconds + peakSeconds)
        zoneSlices = [
            HeartRateZoneSlice(zone: .below, seconds: belowSeconds, percentage: (belowSeconds / trackedSeconds) * 100),
            HeartRateZoneSlice(zone: .zone2, seconds: zone2Seconds, percentage: (zone2Seconds / trackedSeconds) * 100),
            HeartRateZoneSlice(zone: .peak, seconds: peakSeconds, percentage: (peakSeconds / trackedSeconds) * 100)
        ]

        linePoints = sorted.map { sample in
            let elapsed = max(0, sample.startDate.timeIntervalSince(start) / 60)
            let bpm = sample.quantity.doubleValue(for: bpmUnit)
            return HeartRateLinePoint(time: sample.startDate, elapsedMinutes: elapsed, bpm: bpm)
        }

        peakMoments = linePoints
            .sorted(by: { $0.bpm > $1.bpm })
            .prefix(3)
            .map { HeartRatePeakMoment(time: $0.time, bpm: $0.bpm) }
            .sorted(by: { $0.time < $1.time })

        if let peakPoint = linePoints.max(by: { $0.bpm < $1.bpm }) {
            let recoveryWindowEnd = peakPoint.time.addingTimeInterval(180)
            let segment = linePoints.filter {
                $0.time >= peakPoint.time && $0.time <= recoveryWindowEnd
            }
            recoveryPoints = segment.map {
                HeartRateRecoveryPoint(
                    elapsedSeconds: $0.time.timeIntervalSince(peakPoint.time),
                    bpm: $0.bpm
                )
            }
        } else {
            recoveryPoints = []
        }
    }

    private func generateFallbackLinePoints() {
        guard fallbackAverageHeartRate > 0,
              let workoutStartDate else {
            linePoints = []
            return
        }

        let end = workoutEndDate ?? Date()
        linePoints = [
            HeartRateLinePoint(time: workoutStartDate, elapsedMinutes: 0, bpm: fallbackAverageHeartRate),
            HeartRateLinePoint(
                time: end,
                elapsedMinutes: max(0, end.timeIntervalSince(workoutStartDate) / 60),
                bpm: fallbackAverageHeartRate
            )
        ]
    }

    private func resolveZoneBounds() -> (lower: Double, upper: Double) {
        var age = UserProfileStore.shared.current.age
        if !(13...100).contains(age), let birthDate = UserProfileStore.shared.current.birthDate {
            age = Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 30
        }
        if !(13...100).contains(age) {
            age = 30
        }

        let maxHeartRate = max(100, 220 - age)
        return (Double(maxHeartRate) * 0.60, Double(maxHeartRate) * 0.70)
    }
}

// ====================================
// MARK: - Heart Zone Summary Card
// ====================================

private struct HeartRateZoneSummaryCard: View {
    @ObservedObject var analytics: WorkoutHeartRateAnalyticsStore
    let delay: Double
    let onTap: () -> Void

    @State private var show = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("HEART RATE ZONES")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .tracking(1.2)
                            .foregroundStyle(.white.opacity(0.62))

                        Text("Interactive Performance Lens")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.65))
                }

                HStack(spacing: 14) {
                    VStack(spacing: 10) {
                        if analytics.totalTrackedMinutes > 0 {
                            Chart(analytics.zoneSlices) { slice in
                                SectorMark(
                                    angle: .value("Seconds", max(slice.seconds, 0.01)),
                                    innerRadius: .ratio(0.63),
                                    angularInset: 2
                                )
                                .foregroundStyle(slice.zone.color)
                            }
                            .chartLegend(.hidden)
                            .frame(width: 128, height: 128)
                        } else {
                            Circle()
                                .strokeBorder(.white.opacity(0.18), lineWidth: 10)
                                .frame(width: 124, height: 124)
                                .overlay {
                                    Text("Syncing")
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.65))
                                }
                        }

                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(analytics.zoneSlices) { slice in
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(slice.zone.color)
                                        .frame(width: 7, height: 7)
                                    Text(slice.zone.title)
                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.78))
                                    Spacer(minLength: 2)
                                    Text("\(Int(slice.percentage.rounded()))%")
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                        .frame(width: 130)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Heart Rate Timeline")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.8))

                        Chart(analytics.linePoints) { point in
                            LineMark(
                                x: .value("Minute", point.elapsedMinutes),
                                y: .value("BPM", point.bpm)
                            )
                            .interpolationMethod(.catmullRom)
                            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .green, .orange, .red],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        }
                        .chartYScale(domain: analytics.heartRateYDomain)
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 3)) {
                                AxisValueLabel()
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.58))
                            }
                        }
                        .chartYAxis(.hidden)
                        .frame(height: 142)

                        Text("Tap for zone minutes, recovery curve, and peak timestamps")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.58))
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.55), radius: 22, x: 0, y: 16)
        }
        .buttonStyle(.plain)
        .opacity(show ? 1 : 0)
        .offset(y: show ? 0 : 12)
        .onAppear {
            withAnimation(.spring(response: 0.75, dampingFraction: 0.86).delay(delay)) {
                show = true
            }
        }
    }
}

// ====================================
// MARK: - Heart Deep Dive Sheet
// ====================================

private struct HeartRateZoneDeepDiveView: View {
    @ObservedObject var analytics: WorkoutHeartRateAnalyticsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color.black,
                        Color(red: 0.07, green: 0.10, blue: 0.16),
                        Color(red: 0.04, green: 0.05, blue: 0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Detailed cardio intelligence from live HealthKit samples, designed to tune your pacing precision.")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.72))

                        zoneBreakdownSection
                        recoverySection
                        peaksSection
                    }
                    .padding(18)
                    .padding(.bottom, 26)
                }
            }
            .navigationTitle("Heart Zone Analytics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var zoneBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Exact Zone Minutes")
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)

            ForEach(analytics.zoneSlices) { slice in
                HStack {
                    Circle()
                        .fill(slice.zone.color)
                        .frame(width: 10, height: 10)
                    Text(slice.zone.title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.86))
                    Spacer()
                    Text("\(slice.minutes, specifier: "%.1f") min")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    private var recoverySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Heart Rate Recovery Curve")
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)

            if analytics.recoveryPoints.count >= 2 {
                Chart(analytics.recoveryPoints) { point in
                    LineMark(
                        x: .value("Seconds", point.elapsedSeconds),
                        y: .value("BPM", point.bpm)
                    )
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .yellow, .mint],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                }
                .chartXScale(domain: 0...180)
                .chartYScale(domain: analytics.heartRateYDomain)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine()
                            .foregroundStyle(.white.opacity(0.10))
                        AxisValueLabel {
                            if let seconds = value.as(Double.self) {
                                Text("\(Int(seconds))s")
                            }
                        }
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.62))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) {
                        AxisGridLine()
                            .foregroundStyle(.white.opacity(0.08))
                        AxisValueLabel()
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.60))
                    }
                }
                .frame(height: 210)
            } else {
                Text("Recovery curve will appear as soon as enough synced samples arrive.")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    private var peaksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Timestamped Peaks")
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)

            if analytics.peakMoments.isEmpty {
                Text("No peaks detected yet.")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.62))
            } else {
                ForEach(Array(analytics.peakMoments.enumerated()), id: \.element.id) { index, peak in
                    HStack {
                        Text("#\(index + 1)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.75))
                            .frame(width: 30, alignment: .leading)

                        Text("\(Int(peak.bpm.rounded())) bpm")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundStyle(.white)

                        Spacer()

                        Text(peak.timestampText)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.72))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.07))
                    )
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}
