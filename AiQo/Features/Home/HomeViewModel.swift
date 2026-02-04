import Foundation
internal import Combine
import HealthKit

// MARK: - Extensions for Existing Types (SwiftUI Conformances)

/// Add Identifiable conformance to your existing MetricKind for use in ForEach
extension MetricKind: Identifiable, CaseIterable, Hashable {
    public var id: String {
        switch self {
        case .steps: return "steps"
        case .calories: return "calories"
        case .stand: return "stand"
        case .water: return "water"
        case .sleep: return "sleep"
        case .distance: return "distance"
        }
    }
    
    public static var allCases: [MetricKind] {
        [.steps, .calories, .stand, .water, .sleep, .distance]
    }
}

/// Add Equatable conformance to your existing TodaySummary if not already present
extension TodaySummary: Equatable {
    public static func == (lhs: TodaySummary, rhs: TodaySummary) -> Bool {
        lhs.steps == rhs.steps &&
        lhs.activeKcal == rhs.activeKcal &&
        lhs.standPercent == rhs.standPercent &&
        lhs.waterML == rhs.waterML &&
        lhs.sleepHours == rhs.sleepHours &&
        lhs.distanceMeters == rhs.distanceMeters
    }
}

// MARK: - New Supporting Models (These don't exist in your project yet)

/// Time scope for historical data charts
enum TimeScope: Int, CaseIterable, Identifiable {
    case day = 0
    case week
    case month
    case year
    case allTime
    
    var id: Int { rawValue }
    
    var title: String {
        switch self {
        case .day:     return "Day"
        case .week:    return "Week"
        case .month:   return "Month"
        case .year:    return "Year"
        case .allTime: return "ALL"
        }
    }
}

/// Model for a single metric card display
struct MetricCardData: Identifiable, Equatable {
    let id: MetricKind
    var kind: MetricKind { id }
    var displayValue: String
    var tintColorName: String // "mint" or "sand"
    
    static func empty(kind: MetricKind, tint: String) -> MetricCardData {
        MetricCardData(id: kind, displayValue: "—", tintColorName: tint)
    }
}

/// Model for chart series data
struct ChartSeriesData: Equatable {
    var values: [Double]
    var headerText: String
    
    static let empty = ChartSeriesData(values: [], headerText: "—")
}

/// Demo mode configuration
struct DemoConfiguration {
    let steps: String
    let calories: String
    let stand: String
    let water: String
    let sleep: String
    let distance: String
    
    static let `default` = DemoConfiguration(
        steps: "8,766",
        calories: "841",
        stand: "91",
        water: "2.3 L",
        sleep: "9.0",
        distance: "6.57"
    )
}

/// Navigation destinations from Home screen
enum HomeDestination: Identifiable, Equatable {
    case profile
    case tribe
    case waterDetail
    case metricDetail(MetricKind)
    
    var id: String {
        switch self {
        case .profile: return "profile"
        case .tribe: return "tribe"
        case .waterDetail: return "waterDetail"
        case .metricDetail(let kind): return "metricDetail_\(kind.id)"
        }
    }
}

// MARK: - HomeViewModel

@MainActor
final class HomeViewModel: ObservableObject {
    
    // MARK: - Published State
    
    /// All metric cards data for the grid
    @Published private(set) var metricCards: [MetricCardData] = []
    
    /// Current summary cache for quick access
    @Published private(set) var currentSummary: TodaySummary?
    
    /// Loading state
    @Published private(set) var isLoading: Bool = false
    
    /// Error state
    @Published private(set) var error: Error?
    
    /// Currently expanded metric (for inline detail view)
    @Published var expandedMetric: MetricKind?
    
    /// Chart data for the currently viewed metric detail
    @Published private(set) var chartData: ChartSeriesData = .empty
    
    /// Currently selected time scope for chart
    @Published var selectedScope: TimeScope = .day {
        didSet {
            if let metric = activeDetailMetric {
                Task { await loadChartSeries(for: metric, scope: selectedScope) }
            }
        }
    }
    
    /// Current water intake in liters (for water detail view)
    @Published private(set) var currentWaterLiters: Double = 0.0
    
    /// Navigation state
    @Published var activeDestination: HomeDestination?
    
    /// Metric currently shown in detail sheet
    @Published var activeDetailMetric: MetricKind?
    
    // MARK: - Private Properties
    
    /// Demo mode toggle - set to true for video recording with fixed values
    private let demoMode: Bool
    private let demoConfig: DemoConfiguration
    
    /// HealthKit service reference
    private let healthService: HealthKitService
    
    /// Timer for live refresh
    private var refreshTimer: Timer?
    
    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    /// Card tint assignments
    private let cardTints: [MetricKind: String] = [
        .steps: "mint",
        .calories: "mint",
        .stand: "sand",
        .water: "sand",
        .sleep: "mint",
        .distance: "mint"
    ]
    
    /// Grid layout order
    private let gridOrder: [MetricKind] = [.steps, .calories, .stand, .water, .sleep, .distance]
    
    // MARK: - Initialization
    
    init(
        healthService: HealthKitService = .shared,
        demoMode: Bool = false,
        demoConfig: DemoConfiguration = .default
    ) {
        self.healthService = healthService
        self.demoMode = demoMode
        self.demoConfig = demoConfig
        
        setupInitialCards()
    }
    
    // MARK: - Setup
    
    private func setupInitialCards() {
        metricCards = gridOrder.map { kind in
            MetricCardData.empty(kind: kind, tint: cardTints[kind] ?? "mint")
        }
    }
    
    // MARK: - Lifecycle Methods
    
    /// Called when the view appears - initializes health data and starts refresh
    func onAppear() async {
        if demoMode {
            applyDemoSnapshot()
        } else {
            await setupHealthAndAutoRefresh()
        }
    }
    
    /// Called when the view disappears - stops refresh timer
    func onDisappear() {
        stopLiveTimer()
    }
    
    /// Called when app becomes active - refreshes data
    func onAppBecameActive() {
        guard !demoMode else { return }
        Task { await loadTodayFromHealth() }
    }
    
    // MARK: - Health Data Loading
    
    /// Initial setup: request authorization and start auto-refresh
    private func setupHealthAndAutoRefresh() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            _ = try await healthService.requestAuthorization()
        } catch {
            self.error = error
        }
        
        await loadTodayFromHealth()
        startLiveTimer()
    }
    
    /// Load today's health summary from HealthKit
    func loadTodayFromHealth() async {
        guard !demoMode else { return }
        
        do {
            let summary = try await healthService.fetchTodaySummary()
            applySummary(summary)
        } catch {
            self.error = error
            applySummary(nil)
        }
    }
    
    /// Force refresh all data
    func refresh() async {
        guard !demoMode else {
            applyDemoSnapshot()
            return
        }
        await loadTodayFromHealth()
    }
    
    // MARK: - Timer Management
    
    private func startLiveTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self, !self.demoMode else { return }
            Task { await self.loadTodayFromHealth() }
        }
    }
    
    private func stopLiveTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    // MARK: - Apply Data to Cards
    
    private func applySummary(_ summary: TodaySummary?) {
        guard !demoMode else { return }
        
        guard let summary else {
            clearAllMetrics()
            currentSummary = nil
            return
        }
        
        currentSummary = summary
        currentWaterLiters = summary.waterML / 1000.0
        
        updateMetricCard(.steps, displayValue: format(summary.steps))
        updateMetricCard(.calories, displayValue: format(summary.activeKcal))
        updateMetricCard(.stand, displayValue: format(summary.standPercent))
        updateMetricCard(.water, displayValue: String(format: "%.1f L", summary.waterML / 1000.0))
        updateMetricCard(.sleep, displayValue: String(format: "%.1f", summary.sleepHours))
        updateMetricCard(.distance, displayValue: String(format: "%.2f", summary.distanceMeters / 1000.0))
    }
    
    private func clearAllMetrics() {
        updateMetricCard(.steps, displayValue: format(0))
        updateMetricCard(.calories, displayValue: format(0))
        updateMetricCard(.stand, displayValue: format(0))
        updateMetricCard(.water, displayValue: String(format: "%.1f", 0.0))
        updateMetricCard(.sleep, displayValue: String(format: "%.1f", 0.0))
        updateMetricCard(.distance, displayValue: String(format: "%.2f", 0.0))
    }
    
    private func updateMetricCard(_ kind: MetricKind, displayValue: String) {
        if let index = metricCards.firstIndex(where: { $0.kind == kind }) {
            metricCards[index] = MetricCardData(
                id: kind,
                displayValue: displayValue,
                tintColorName: cardTints[kind] ?? "mint"
            )
        }
    }
    
    // MARK: - Demo Mode
    
    private func applyDemoSnapshot() {
        stopLiveTimer()
        currentSummary = nil
        
        updateMetricCard(.steps, displayValue: demoConfig.steps)
        updateMetricCard(.calories, displayValue: demoConfig.calories)
        updateMetricCard(.stand, displayValue: demoConfig.stand)
        updateMetricCard(.water, displayValue: demoConfig.water)
        updateMetricCard(.sleep, displayValue: demoConfig.sleep)
        updateMetricCard(.distance, displayValue: demoConfig.distance)
    }
    
    // MARK: - Formatting Helpers
    
    private func format(_ value: Double, digits: Int = 0) -> String {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = digits
        formatter.minimumFractionDigits = digits
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
    
    /// Format header value for metric detail view
    func formattedHeader(for kind: MetricKind) -> String {
        guard let summary = currentSummary else { return "—" }
        
        switch kind {
        case .steps:    return format(summary.steps)
        case .calories: return format(summary.activeKcal)
        case .stand:    return format(summary.standPercent) + "%"
        case .water:    return String(format: "%.1f L", summary.waterML / 1000.0)
        case .sleep:    return String(format: "%.1f h", summary.sleepHours)
        case .distance: return String(format: "%.2f km", summary.distanceMeters / 1000.0)
        }
    }
    
    // MARK: - Navigation Actions
    
    func openProfile() {
        activeDestination = .profile
    }
    
    func openTribe() {
        activeDestination = .tribe
    }
    
    func openWaterDetail() {
        currentWaterLiters = (currentSummary?.waterML ?? 0) / 1000.0
        activeDestination = .waterDetail
    }
    
    func openMetricDetail(for kind: MetricKind) {
        activeDetailMetric = kind
        selectedScope = .day
        
        // Load initial chart data
        Task {
            await loadChartSeries(for: kind, scope: .day)
        }
    }
    
    func closeMetricDetail() {
        activeDetailMetric = nil
        chartData = .empty
    }
    
    /// Handle metric card tap - water opens special view, others open detail sheet
    func handleMetricTap(_ kind: MetricKind) {
        if kind == .water {
            openWaterDetail()
        } else {
            openMetricDetail(for: kind)
        }
    }
    
    func dismissDestination() {
        activeDestination = nil
    }
    
    // MARK: - Water Tracking
    
    /// Add water intake
    func addWater(liters: Double) async {
        guard !demoMode else { return }
        
        do {
            try await healthService.saveWater(liters: liters)
            await loadTodayFromHealth()
        } catch {
            self.error = error
        }
    }
    
    // MARK: - Chart Series Loading
    
    /// Load chart series data for a metric and time scope
    func loadChartSeries(for kind: MetricKind, scope: TimeScope) async {
        // Handle all-time scope separately
        if scope == .allTime {
            await loadAllTimeSeries(for: kind)
            return
        }
        
        // Handle regular time scopes
        switch kind {
        case .steps:
            await loadQuantitySeries(.stepCount, unit: .count(), scope: scope) { values, total in
                ChartSeriesData(values: values, headerText: self.format(total))
            }
            
        case .calories:
            await loadQuantitySeries(.activeEnergyBurned, unit: .kilocalorie(), scope: scope) { values, total in
                ChartSeriesData(values: values, headerText: self.format(total))
            }
            
        case .distance:
            await loadQuantitySeries(.distanceWalkingRunning, unit: .meter(), scope: scope) { values, total in
                let kmValues = values.map { $0 / 1000.0 }
                return ChartSeriesData(values: kmValues, headerText: String(format: "%.2f km", total / 1000.0))
            }
            
        case .sleep:
            await loadSleepSeries(scope: scope)
            
        case .stand:
            await loadStandSeries(scope: scope)
            
        case .water:
            await loadQuantitySeries(.dietaryWater, unit: .literUnit(with: .milli), scope: scope) { values, total in
                let literValues = values.map { $0 / 1000.0 }
                return ChartSeriesData(values: literValues, headerText: String(format: "%.1f L", total / 1000.0))
            }
        }
    }
    
    // MARK: - Series Loading Helpers
    
    private func loadAllTimeSeries(for kind: MetricKind) async {
        do {
            let summary = try await healthService.fetchAllTimeSummary()
            
            switch kind {
            case .steps:
                chartData = ChartSeriesData(values: [summary.steps], headerText: format(summary.steps))
            case .calories:
                chartData = ChartSeriesData(values: [summary.activeKcal], headerText: format(summary.activeKcal))
            case .distance:
                let km = summary.distanceMeters / 1000.0
                chartData = ChartSeriesData(values: [km], headerText: String(format: "%.2f km", km))
            case .sleep:
                chartData = ChartSeriesData(values: [summary.sleepHours], headerText: String(format: "%.1f h", summary.sleepHours))
            case .stand:
                chartData = ChartSeriesData(values: [summary.standHours], headerText: String(format: "%.0f h", summary.standHours))
            case .water:
                let liters = summary.waterML / 1000.0
                chartData = ChartSeriesData(values: [liters], headerText: String(format: "%.1f L", liters))
            }
        } catch {
            chartData = .empty
        }
    }
    
    private func loadQuantitySeries(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        scope: TimeScope,
        transform: @escaping ([Double], Double) -> ChartSeriesData
    ) async {
        let store = HKHealthStore()
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else {
            chartData = .empty
            return
        }
        
        let (start, end, interval, anchor) = dateRangeAndInterval(for: scope)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: [.cumulativeSum],
                anchorDate: anchor,
                intervalComponents: interval
            )
            
            query.initialResultsHandler = { [weak self] _, results, _ in
                var values: [Double] = []
                var total: Double = 0
                
                results?.enumerateStatistics(from: start, to: end) { stat, _ in
                    let v = stat.sumQuantity()?.doubleValue(for: unit) ?? 0
                    values.append(v)
                    total += v
                }
                
                Task { @MainActor in
                    self?.chartData = transform(values, total)
                    continuation.resume()
                }
            }
            
            store.execute(query)
        }
    }
    
    private func loadSleepSeries(scope: TimeScope) async {
        let store = HKHealthStore()
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            chartData = .empty
            return
        }
        
        let (start, end, interval, _) = dateRangeAndInterval(for: scope)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let calendar = Calendar.current
        
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { [weak self] _, raw, _ in
                guard let self else {
                    continuation.resume()
                    return
                }
                
                let samples = raw as? [HKCategorySample] ?? []
                var buckets: [Date: Double] = [:]
                
                for sample in samples {
                    let duration = sample.endDate.timeIntervalSince(sample.startDate)
                    let key = self.bucketKey(for: sample.startDate, scope: scope, calendar: calendar)
                    buckets[key, default: 0] += duration
                }
                
                var values: [Double] = []
                var cursor = start
                
                while cursor < end {
                    let key = self.bucketKey(for: cursor, scope: scope, calendar: calendar)
                    values.append(buckets[key] ?? 0)
                    cursor = calendar.date(byAdding: interval, to: cursor) ?? end
                }
                
                let totalSeconds = values.reduce(0, +)
                let hoursValues = values.map { $0 / 3600.0 }
                
                Task { @MainActor in
                    self.chartData = ChartSeriesData(
                        values: hoursValues,
                        headerText: String(format: "%.1f h", totalSeconds / 3600.0)
                    )
                    continuation.resume()
                }
            }
            
            store.execute(query)
        }
    }
    
    private func loadStandSeries(scope: TimeScope) async {
        let store = HKHealthStore()
        guard let type = HKObjectType.categoryType(forIdentifier: .appleStandHour) else {
            chartData = .empty
            return
        }
        
        let (start, end, interval, _) = dateRangeAndInterval(for: scope)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let calendar = Calendar.current
        
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { [weak self] _, raw, _ in
                guard let self else {
                    continuation.resume()
                    return
                }
                
                let samples = raw as? [HKCategorySample] ?? []
                var buckets: [Date: Double] = [:]
                
                for sample in samples where sample.value == 1 {
                    let key = self.bucketKey(for: sample.startDate, scope: scope, calendar: calendar)
                    buckets[key, default: 0] += 1
                }
                
                var values: [Double] = []
                var cursor = start
                
                while cursor < end {
                    let key = self.bucketKey(for: cursor, scope: scope, calendar: calendar)
                    values.append(buckets[key] ?? 0)
                    cursor = calendar.date(byAdding: interval, to: cursor) ?? end
                }
                
                let totalHours = values.reduce(0, +)
                let percent = min(100.0, (totalHours / 12.0) * 100.0)
                
                Task { @MainActor in
                    self.chartData = ChartSeriesData(
                        values: values,
                        headerText: String(format: "%.0f%%", percent)
                    )
                    continuation.resume()
                }
            }
            
            store.execute(query)
        }
    }
    
    // MARK: - Date Range Helpers
    
    private func dateRangeAndInterval(for scope: TimeScope) -> (start: Date, end: Date, interval: DateComponents, anchor: Date) {
        let calendar = Calendar.current
        let now = Date()
        let end = now
        
        let interval: DateComponents
        let start: Date
        var anchor: Date
        
        switch scope {
        case .day:
            interval = DateComponents(hour: 1)
            start = calendar.startOfDay(for: now)
            anchor = start
            
        case .week:
            interval = DateComponents(day: 1)
            start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now))!
            anchor = start
            
        case .month:
            interval = DateComponents(day: 1)
            start = calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: now))!
            anchor = start
            
        case .year:
            interval = DateComponents(month: 1)
            let components = calendar.dateComponents([.year, .month], from: now)
            start = calendar.date(from: DateComponents(
                year: components.year! - 1,
                month: components.month,
                day: 1
            ))!
            anchor = calendar.date(from: calendar.dateComponents([.year, .month], from: start))!
            
        case .allTime:
            interval = DateComponents(day: 1)
            start = calendar.startOfDay(for: now)
            anchor = start
        }
        
        return (start, end, interval, anchor)
    }
    
    private func bucketKey(for date: Date, scope: TimeScope, calendar: Calendar) -> Date {
        switch scope {
        case .day:
            let components = calendar.dateComponents([.year, .month, .day, .hour], from: date)
            return calendar.date(from: components)!
            
        case .week, .month:
            return calendar.startOfDay(for: date)
            
        default:
            let components = calendar.dateComponents([.year, .month], from: date)
            return calendar.date(from: components)!
        }
    }
    
    // MARK: - Inline Expand/Collapse (for grid cards)
    
    func toggleInlineExpand(for kind: MetricKind) {
        if expandedMetric == kind {
            expandedMetric = nil
        } else {
            expandedMetric = kind
            selectedScope = .day
            Task { await loadChartSeries(for: kind, scope: .day) }
        }
    }
    
    func collapseExpandedCard() {
        expandedMetric = nil
    }
    
    // MARK: - Grid Helpers
    
    /// Returns the metric cards arranged in rows of 2
    var gridRows: [[MetricCardData]] {
        stride(from: 0, to: metricCards.count, by: 2).map { index in
            Array(metricCards[index..<min(index + 2, metricCards.count)])
        }
    }
    
    /// Get the tint color name for a metric kind
    func tintColor(for kind: MetricKind) -> String {
        cardTints[kind] ?? "mint"
    }
}

// MARK: - Preview Helper

#if DEBUG
extension HomeViewModel {
    static var preview: HomeViewModel {
        let vm = HomeViewModel(demoMode: true)
        return vm
    }
}
#endif
