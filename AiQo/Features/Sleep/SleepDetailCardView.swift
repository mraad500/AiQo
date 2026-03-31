import Charts
import SwiftUI

struct SleepDetailCardView: View {
    private let healthManager: HealthKitManager
    private let historicalChartData: ChartSeriesData
    private let externalTimeframe: TimeScope
    private let onTimeframeChange: ((TimeScope) -> Void)?
    private let loadsFromHealthKit: Bool

    @Environment(\.colorScheme) private var colorScheme

    @State private var sleepStages: [SleepStageData]
    @State private var selectedTimeframe: TimeScope
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var sleepScoreBreakdown: SleepScoreBreakdown?
    @StateObject private var smartWakeViewModel: SmartWakeViewModel

    init(
        healthManager: HealthKitManager = .shared,
        targetWakeTime: Date? = nil,
        historicalChartData: ChartSeriesData = .empty,
        initialTimeframe: TimeScope = .day,
        onTimeframeChange: ((TimeScope) -> Void)? = nil,
        previewStages: [SleepStageData] = []
    ) {
        self.healthManager = healthManager
        self.historicalChartData = historicalChartData
        self.externalTimeframe = initialTimeframe
        self.onTimeframeChange = onTimeframeChange
        self.loadsFromHealthKit = previewStages.isEmpty

        let resolvedBedtime = previewStages.first?.startDate ?? Self.defaultBedtimeReference
        _sleepStages = State(initialValue: previewStages)
        _selectedTimeframe = State(initialValue: initialTimeframe)
        _sleepScoreBreakdown = State(
            initialValue: Self.makeSleepScoreBreakdown(
                from: previewStages,
                historicalBedtimes: []
            )
        )
        _smartWakeViewModel = StateObject(
            wrappedValue: SmartWakeViewModel(
                initialBedtime: resolvedBedtime,
                initialLatestWakeTime: targetWakeTime,
                initialMode: targetWakeTime == nil ? .fromBedtime : .fromWakeTime
            )
        )
    }

    var body: some View {
        ZStack {
            cardBackground

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 24) {
                    timeframeSection
                    summaryAndChartSection
                    legendSection
                    smartWakeSection
                }
                .padding(20)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .task {
            guard loadsFromHealthKit else { return }
            await loadSleepStages()
        }
        .onChange(of: externalTimeframe) { _, newValue in
            if selectedTimeframe != newValue {
                selectedTimeframe = newValue
            }
        }
    }

    private var timeframeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(NSLocalizedString("sleep.timeNavigation", comment: ""))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(AiQoTheme.Colors.textSecondary)

            Picker(NSLocalizedString("sleep.timeNavigation", comment: ""), selection: timeframeBinding) {
                ForEach(TimeScope.allCases) { scope in
                    Text(scope.nativeSleepTitle)
                        .tag(scope)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var summaryAndChartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(NSLocalizedString("sleep.architecture", comment: ""))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(AiQoTheme.Colors.textPrimary)

            VStack(alignment: .leading, spacing: 6) {
                Text(summaryValueText)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(AiQoTheme.Colors.textPrimary)
                    .contentTransition(.numericText())

                Text(summarySubtitle)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(AiQoTheme.Colors.textSecondary)
            }

            Group {
                if selectedTimeframe == .day {
                    dailySleepContent
                } else {
                    historicalSleepContent
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(panelBackground)
    }

    @ViewBuilder
    private var dailySleepContent: some View {
        if isLoading {
            loadingState
        } else if let errorMessage {
            emptyState(
                systemImage: "waveform.badge.exclamationmark",
                title: NSLocalizedString("sleep.stages.unavailable", comment: ""),
                message: errorMessage
            )
        } else if sleepStages.isEmpty {
            emptyState(
                systemImage: "bed.double.circle",
                title: NSLocalizedString("sleep.stages.noData", comment: ""),
                message: NSLocalizedString("sleep.stages.noDataMessage", comment: "")
            )
        } else {
            sleepStageChart
        }
    }

    @ViewBuilder
    private var historicalSleepContent: some View {
        if historicalPoints.isEmpty {
            emptyState(
                systemImage: "chart.xyaxis.line",
                title: NSLocalizedString("sleep.trend.noData", comment: ""),
                message: NSLocalizedString("sleep.trend.noDataMessage", comment: "")
            )
        } else {
            historicalSleepChart
        }
    }

    private var sleepStageChart: some View {
        Chart(sleepStages) { segment in
            BarMark(
                xStart: .value("Start", segment.startDate),
                xEnd: .value("End", segment.endDate),
                y: .value("Session", NSLocalizedString("sleep.lastNight", comment: ""))
            )
            .foregroundStyle(segment.stage.gradient)
            .cornerRadius(8)
        }
        .chartLegend(.hidden)
        .chartYScale(domain: [NSLocalizedString("sleep.lastNight", comment: "")])
        .chartYAxis(.hidden)
        .chartXScale(domain: chartDomain)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) {
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.8, dash: [3, 4]))
                    .foregroundStyle(.white.opacity(colorScheme == .dark ? 0.16 : 0.22))
                AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .abbreviated)))
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(AiQoTheme.Colors.textSecondary)
            }
        }
        .chartPlotStyle { plotArea in
            plotArea
                .background(Color.white.opacity(colorScheme == .dark ? 0.04 : 0.28))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .frame(height: 128)
    }

    private var historicalSleepChart: some View {
        Chart(historicalPoints) { point in
            AreaMark(
                x: .value("Index", point.index),
                y: .value("Hours", point.value)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        Color(hex: "A5EFD1").opacity(0.70),
                        Color(hex: "D9E7FF").opacity(0.18)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            LineMark(
                x: .value("Index", point.index),
                y: .value("Hours", point.value)
            )
            .interpolationMethod(.catmullRom)
            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        Color(hex: "8DE0CD"),
                        Color(hex: "AFC9FF")
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )

            if shouldShowHistoricalPointMarks {
                PointMark(
                    x: .value("Index", point.index),
                    y: .value("Hours", point.value)
                )
                .foregroundStyle(Color(hex: "C6FFF0"))
            }
        }
        .chartLegend(.hidden)
        .chartXAxis {
            AxisMarks(values: historicalAxisIndices) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.6, dash: [3, 4]))
                    .foregroundStyle(.white.opacity(colorScheme == .dark ? 0.12 : 0.18))
                AxisValueLabel {
                    if let index = value.as(Int.self) {
                        Text(historicalAxisLabel(for: index))
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(AiQoTheme.Colors.textSecondary)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.8, dash: [3, 4]))
                    .foregroundStyle(.white.opacity(colorScheme == .dark ? 0.12 : 0.18))
                AxisValueLabel {
                    if let hours = value.as(Double.self) {
                        Text("\(hours, format: .number.precision(.fractionLength(0)))h")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(AiQoTheme.Colors.textSecondary)
                    }
                }
            }
        }
        .chartPlotStyle { plotArea in
            plotArea
                .background(Color.white.opacity(colorScheme == .dark ? 0.04 : 0.28))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .frame(height: 196)
    }

    private var legendSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(NSLocalizedString("sleep.stages", comment: ""))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(AiQoTheme.Colors.textPrimary)

            SleepScoreRingView(
                score: sleepScoreValue,
                hasData: stageSessionDuration > 0
            )
            .frame(maxWidth: .infinity)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ], spacing: 10) {
                ForEach(orderedStages, id: \.self) { stage in
                    SleepStageLegendPill(
                        stage: stage,
                        durationText: legendDurationText(for: stage)
                    )
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(panelBackground)
    }

    private var smartWakeSection: some View {
        SmartWakeCalculatorView(viewModel: smartWakeViewModel)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(panelBackground)
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(AiQoTheme.Colors.accent)
                .scaleEffect(1.1)

            Text(NSLocalizedString("sleep.syncing", comment: ""))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(AiQoTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 160)
    }

    private func emptyState(
        systemImage: String,
        title: String,
        message: String
    ) -> some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(AiQoTheme.Colors.accent)

            Text(title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(AiQoTheme.Colors.textPrimary)

            Text(message)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(AiQoTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 170)
        .padding(.horizontal, 12)
    }

    private var timeframeBinding: Binding<TimeScope> {
        Binding(
            get: { selectedTimeframe },
            set: { newValue in
                guard newValue != selectedTimeframe else { return }
                selectedTimeframe = newValue
                onTimeframeChange?(newValue)
            }
        )
    }

    private var summaryValueText: String {
        if selectedTimeframe == .day {
            return totalSleepDurationText
        }

        return historicalChartData.headerText.isEmpty ? "—" : historicalChartData.headerText
    }

    private var summarySubtitle: String {
        if selectedTimeframe == .day {
            guard let start = sleepStages.first?.startDate,
                  let end = sleepStages.last?.endDate else {
                return NSLocalizedString("sleep.nextSync", comment: "")
            }

            return "Last night • \(formattedTime(start)) - \(formattedTime(end))"
        }

        return selectedTimeframe.historicalSubtitle
    }

    private var chartDomain: ClosedRange<Date> {
        let start = sleepStages.first?.startDate ?? Self.defaultBedtimeReference
        let end = sleepStages.last?.endDate ?? start.addingTimeInterval(9 * 3600)
        return start...max(end, start.addingTimeInterval(3600))
    }

    private var orderedStages: [SleepStageData.Stage] {
        SleepStageData.Stage.allCases.sorted { $0.sortIndex < $1.sortIndex }
    }

    private var stageDurations: [SleepStageData.Stage: TimeInterval] {
        Dictionary(grouping: sleepStages, by: \.stage).mapValues {
            $0.reduce(0) { $0 + $1.duration }
        }
    }

    private var stageSessionDuration: TimeInterval {
        sleepStages.reduce(0) { $0 + $1.duration }
    }

    private var totalSleepDuration: TimeInterval {
        sleepStages
            .filter { $0.stage != .awake }
            .reduce(0) { $0 + $1.duration }
    }

    private var resolvedSleepScoreBreakdown: SleepScoreBreakdown? {
        sleepScoreBreakdown ?? Self.makeSleepScoreBreakdown(
            from: sleepStages,
            historicalBedtimes: []
        )
    }

    private var sleepScoreValue: Int? {
        resolvedSleepScoreBreakdown?.totalScore
    }

    private var totalSleepDurationText: String {
        formattedDuration(totalSleepDuration, unitsStyle: .short)
    }

    private var historicalPoints: [HistoricalSleepPoint] {
        historicalChartData.values.enumerated().map { index, value in
            HistoricalSleepPoint(index: index, value: value)
        }
    }

    private var historicalAxisIndices: [Int] {
        let count = historicalPoints.count
        guard count > 0 else { return [] }
        guard count > 4 else { return Array(0..<count) }

        let step = max(1, (count - 1) / 3)
        var indices = Array(stride(from: 0, to: count, by: step))
        if indices.last != count - 1 {
            indices.append(count - 1)
        }

        return Array(Set(indices)).sorted()
    }

    private var shouldShowHistoricalPointMarks: Bool {
        selectedTimeframe == .week || selectedTimeframe == .month
    }

    private func historicalAxisLabel(for index: Int) -> String {
        let calendar = Calendar.current

        switch selectedTimeframe {
        case .week:
            let weekdays = calendar.veryShortStandaloneWeekdaySymbols
            return weekdays[index % weekdays.count]
        case .month:
            return "\(index + 1)"
        case .year, .allTime:
            let months = calendar.shortMonthSymbols
            return months[index % months.count]
        case .day:
            return ""
        }
    }

    private func legendDurationText(for stage: SleepStageData.Stage) -> String {
        let duration = stageDurations[stage] ?? 0
        return duration > 0 ? formattedDuration(duration, unitsStyle: .abbreviated) : "—"
    }

    private func loadSleepStages() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            let authorized = try await healthManager.requestSleepAuthorizationIfNeeded()
            guard authorized else {
                throw SleepStageFetchError.authorizationDenied
            }

            let referenceDate = Date()
            let stages = try await healthManager.fetchSleepStagesForLastNight(now: referenceDate)
            let historicalBedtimes = (try? await healthManager.fetchHistoricalSleepBedtimes(before: referenceDate)) ?? []
            let scoreBreakdown = Self.makeSleepScoreBreakdown(
                from: stages,
                historicalBedtimes: historicalBedtimes
            )

            await MainActor.run {
                sleepStages = stages
                sleepScoreBreakdown = scoreBreakdown
                isLoading = false

                if let detectedBedtime = stages.first?.startDate {
                    smartWakeViewModel.updateInferredBedtime(detectedBedtime)
                }
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
                sleepScoreBreakdown = Self.makeSleepScoreBreakdown(
                    from: sleepStages,
                    historicalBedtimes: []
                )
            }
        }
    }

    private func formattedTime(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    private static let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.maximumUnitCount = 2
        formatter.zeroFormattingBehavior = .dropLeading
        return formatter
    }()

    private func formattedDuration(
        _ duration: TimeInterval,
        unitsStyle: DateComponentsFormatter.UnitsStyle
    ) -> String {
        let formatter = Self.durationFormatter
        formatter.allowedUnits = duration >= 3600 ? [.hour, .minute] : [.minute]
        formatter.unitsStyle = unitsStyle
        return formatter.string(from: duration) ?? "0m"
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .fill(.ultraThinMaterial)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "D7EEFF").opacity(colorScheme == .dark ? 0.10 : 0.24),
                                Color(hex: "F5EEFF").opacity(colorScheme == .dark ? 0.08 : 0.18),
                                Color(hex: "FFF1DF").opacity(colorScheme == .dark ? 0.06 : 0.16)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(colorScheme == .dark ? 0.30 : 0.72),
                                .white.opacity(colorScheme == .dark ? 0.10 : 0.16),
                                Color(hex: "BFD4FF").opacity(colorScheme == .dark ? 0.18 : 0.32)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.28 : 0.10), radius: 24, x: 0, y: 18)
    }

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color.white.opacity(colorScheme == .dark ? 0.05 : 0.34))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(.white.opacity(colorScheme == .dark ? 0.10 : 0.32), lineWidth: 1)
            )
    }

    private static func makeSleepScoreBreakdown(
        from stages: [SleepStageData],
        historicalBedtimes: [Date],
        calendar: Calendar = .current
    ) -> SleepScoreBreakdown? {
        let totalSleepDuration = stages
            .filter { $0.stage != .awake }
            .reduce(0) { $0 + $1.duration }
        guard totalSleepDuration > 0 else { return nil }

        let bedtime = stages.first?.startDate ?? defaultBedtimeReference

        return SleepScoreBreakdown(
            durationScore: durationSleepScore(for: totalSleepDuration),
            bedtimeScore: bedtimeSleepScore(
                for: bedtime,
                historicalBedtimes: historicalBedtimes,
                calendar: calendar
            ),
            interruptionScore: interruptionSleepScore(from: stages)
        )
    }

    private static func durationSleepScore(for totalSleepDuration: TimeInterval) -> Int {
        let durationTarget = 7.75 * 3_600.0
        let normalizedScore = min(max(totalSleepDuration / durationTarget, 0), 1)
        return max(0, min(Int((normalizedScore * 50).rounded()), 50))
    }

    private static func bedtimeSleepScore(
        for bedtime: Date,
        historicalBedtimes: [Date],
        calendar: Calendar
    ) -> Int {
        let bedtimeMinutes = clockMinutes(for: bedtime, calendar: calendar)

        guard let averageBedtimeMinutes = anchoredAverageClockMinutes(
            around: bedtimeMinutes,
            from: historicalBedtimes,
            calendar: calendar
        ) else {
            return 30
        }

        let deviation = circularMinuteDistance(
            between: bedtimeMinutes,
            and: averageBedtimeMinutes
        )

        let score: Double
        switch deviation {
        case ...90:
            score = 30
        case ...150:
            score = 30 - ((deviation - 90) / 60) * 10
        case ...240:
            score = 20 - ((deviation - 150) / 90) * 20
        default:
            score = 0
        }

        return max(0, min(Int(score.rounded()), 30))
    }

    private static func interruptionSleepScore(from stages: [SleepStageData]) -> Int {
        let interruptions = groupedAwakeInterruptions(from: stages)
        let wakeupCount = interruptions.count
        let awakeMinutes = interruptions.reduce(0) { $0 + $1.duration } / 60

        if awakeMinutes <= 5 {
            return 20
        }

        let wakeupPenalty = max(Double(wakeupCount - 3), 0) * 1.75
        let durationPenalty = max(awakeMinutes - 5, 0) * 0.55
        let totalPenalty = min(wakeupPenalty + durationPenalty, 20)

        return max(0, min(Int((20 - totalPenalty).rounded()), 20))
    }

    private static func anchoredAverageClockMinutes(
        around anchorMinutes: Double,
        from dates: [Date],
        calendar: Calendar
    ) -> Double? {
        guard !dates.isEmpty else { return nil }

        let anchoredMinutes = dates.map {
            unwrappedClockMinutes(clockMinutes(for: $0, calendar: calendar), around: anchorMinutes)
        }
        let comparableMinutes = anchoredMinutes.filter { abs($0 - anchorMinutes) <= 240 }
        let resolvedMinutes = comparableMinutes.isEmpty ? anchoredMinutes : comparableMinutes
        guard !resolvedMinutes.isEmpty else { return nil }

        let averageMinutes = resolvedMinutes.reduce(0, +) / Double(resolvedMinutes.count)
        return normalizedClockMinutes(averageMinutes)
    }

    private static func groupedAwakeInterruptions(from stages: [SleepStageData]) -> [DateInterval] {
        let awakeStages = stages
            .filter { $0.stage == .awake && $0.duration > 0 }
            .sorted { $0.startDate < $1.startDate }
        guard !awakeStages.isEmpty else { return [] }

        var interruptions: [DateInterval] = []

        for awakeStage in awakeStages {
            let interval = DateInterval(start: awakeStage.startDate, end: awakeStage.endDate)

            if let last = interruptions.last,
               interval.start.timeIntervalSince(last.end) <= 8 * 60 {
                interruptions[interruptions.count - 1] = DateInterval(
                    start: last.start,
                    end: max(last.end, interval.end)
                )
            } else {
                interruptions.append(interval)
            }
        }

        return interruptions
    }

    private static func unwrappedClockMinutes(_ minutes: Double, around anchor: Double) -> Double {
        var resolvedMinutes = minutes

        while resolvedMinutes - anchor > 720 {
            resolvedMinutes -= 1_440
        }

        while anchor - resolvedMinutes > 720 {
            resolvedMinutes += 1_440
        }

        return resolvedMinutes
    }

    private static func normalizedClockMinutes(_ minutes: Double) -> Double {
        let normalized = minutes.truncatingRemainder(dividingBy: 1_440)
        return normalized >= 0 ? normalized : normalized + 1_440
    }

    private static func clockMinutes(for date: Date, calendar: Calendar) -> Double {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        return Double((hour * 60) + minute)
    }

    private static func circularMinuteDistance(between lhs: Double, and rhs: Double) -> Double {
        let directDistance = abs(lhs - rhs)
        return min(directDistance, 1_440.0 - directDistance)
    }

    private static var defaultBedtimeReference: Date {
        let calendar = Calendar.current
        let now = Date()
        return calendar.date(bySettingHour: 23, minute: 0, second: 0, of: now) ?? now
    }
}

private struct HistoricalSleepPoint: Identifiable {
    let index: Int
    let value: Double

    var id: Int { index }
}

private struct SleepScoreBreakdown: Equatable {
    let durationScore: Int
    let bedtimeScore: Int
    let interruptionScore: Int

    var totalScore: Int {
        max(0, min(durationScore + bedtimeScore + interruptionScore, 100))
    }
}

private struct SleepStageLegendPill: View {
    let stage: SleepStageData.Stage
    let durationText: String

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(stage.gradient)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(stage.rawValue)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(AiQoTheme.Colors.textPrimary)

                Text(durationText)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(AiQoTheme.Colors.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.10))
        )
    }
}

private extension SleepStageData.Stage {
    var gradient: LinearGradient {
        let colors: [Color]

        switch self {
        case .deep:
            colors = [Color(hex: "4D63F8"), Color(hex: "7C89FF")]
        case .core:
            colors = [Color(hex: "96E9C8"), Color(hex: "CFF7E3")]
        case .rem:
            colors = [Color(hex: "CAB8FF"), Color(hex: "E6DBFF")]
        case .awake:
            colors = [Color(hex: "FFBE8F"), Color(hex: "FFD9B8")]
        }

        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

private extension TimeScope {
    var nativeSleepTitle: String {
        switch self {
        case .day:
            return "يوم"
        case .week:
            return "أسبوع"
        case .month:
            return "شهر"
        case .year:
            return "سنة"
        case .allTime:
            return "الكل"
        }
    }

    var historicalSubtitle: String {
        switch self {
        case .day:
            return NSLocalizedString("sleep.subtitle.day", comment: "")
        case .week:
            return NSLocalizedString("sleep.subtitle.week", comment: "")
        case .month:
            return NSLocalizedString("sleep.subtitle.month", comment: "")
        case .year:
            return NSLocalizedString("sleep.subtitle.year", comment: "")
        case .allTime:
            return NSLocalizedString("sleep.subtitle.all", comment: "")
        }
    }
}

#Preview("Sleep Detail Card") {
    SleepDetailCardView(
        historicalChartData: ChartSeriesData(
            values: [6.4, 7.1, 7.8, 6.9, 8.2, 7.4, 7.0],
            headerText: "7.3 h"
        ),
        initialTimeframe: .day,
        previewStages: [
            SleepStageData(stage: .core, startDate: Date().addingTimeInterval(-8.6 * 3600), endDate: Date().addingTimeInterval(-7.8 * 3600)),
            SleepStageData(stage: .deep, startDate: Date().addingTimeInterval(-7.8 * 3600), endDate: Date().addingTimeInterval(-7.0 * 3600)),
            SleepStageData(stage: .core, startDate: Date().addingTimeInterval(-7.0 * 3600), endDate: Date().addingTimeInterval(-5.8 * 3600)),
            SleepStageData(stage: .rem, startDate: Date().addingTimeInterval(-5.8 * 3600), endDate: Date().addingTimeInterval(-5.2 * 3600)),
            SleepStageData(stage: .core, startDate: Date().addingTimeInterval(-5.2 * 3600), endDate: Date().addingTimeInterval(-3.8 * 3600)),
            SleepStageData(stage: .deep, startDate: Date().addingTimeInterval(-3.8 * 3600), endDate: Date().addingTimeInterval(-3.1 * 3600)),
            SleepStageData(stage: .rem, startDate: Date().addingTimeInterval(-3.1 * 3600), endDate: Date().addingTimeInterval(-2.2 * 3600)),
            SleepStageData(stage: .awake, startDate: Date().addingTimeInterval(-2.2 * 3600), endDate: Date().addingTimeInterval(-2.0 * 3600)),
            SleepStageData(stage: .core, startDate: Date().addingTimeInterval(-2.0 * 3600), endDate: Date().addingTimeInterval(-0.6 * 3600))
        ]
    )
    .padding()
    .background(
        LinearGradient(
            colors: [
                Color(hex: "EEF3FA"),
                Color(hex: "DCE6F3"),
                Color(hex: "C8D7E7")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
}
