import SwiftUI
import UIKit
import Combine

// MARK: - HomeView

/// Main home screen displaying health metrics in a grid layout.
/// Replaces the UIKit `HomeViewController`.
struct HomeView: View {
    
    // MARK: - ViewModel
    
    #if DEBUG
    @StateObject private var viewModel: HomeViewModel = {
        if let scenario = ScreenshotMode.scenario {
            return HomeViewModel(demoMode: true, demoConfig: scenario.demoConfig)
        }
        return HomeViewModel()
    }()
    @StateObject private var dailyAuraViewModel: DailyAuraViewModel = {
        if let scenario = ScreenshotMode.scenario {
            return DailyAuraViewModel(
                provider: MockActivityProvider(snapshot: scenario.activitySnapshot)
            )
        }
        return DailyAuraViewModel()
    }()
    #else
    @StateObject private var viewModel = HomeViewModel()
    @StateObject private var dailyAuraViewModel = DailyAuraViewModel()
    #endif
    @StateObject private var vibeControlViewModel = VibeControlViewModel()
    
    // MARK: - Environment
    
    @Environment(\.scenePhase) private var scenePhase
    
    // MARK: - Local State for Water Sheet Binding
    
    /// Local state that syncs with ViewModel for two-way binding in WaterDetailSheetView
    @State private var waterSheetLiters: Double = 0.0
    
    // MARK: - Sheet Presentation States

    @State private var isProfileSheetPresented: Bool = false
    @State private var showVibeSheet: Bool = false
    @State private var appeared: Bool = false
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Background
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(spacing: 6) {
                    dailyAuraSection

                    // Metrics Grid
                    metricsGrid

                    // Kitchen Section
                    kitchenSection

                }
                .padding(.top, 6)
                .padding(.bottom, 4)

                Spacer(minLength: 0)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            topChrome
        }
        .task {
            await viewModel.onAppear()
        }
        .onDisappear {
            viewModel.onDisappear()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                viewModel.onAppBecameActive()
            }
        }
        .onChange(of: viewModel.currentSummary) { _, summary in
            guard let summary else { return }
            dailyAuraViewModel.ingest(todaySteps: Int(summary.steps), todayCalories: summary.activeKcal)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openKitchenFromHome)) { _ in
            viewModel.openKitchen()
        }
        
        // MARK: - Metric Detail Sheet (with transparent paper effect)
        .sheet(item: $viewModel.activeDetailMetric) { kind in
            MetricDetailSheet(
                kind: kind,
                headerValue: viewModel.formattedHeader(for: kind),
                chartData: viewModel.chartData,
                selectedScope: $viewModel.selectedScope,
                onScopeChange: nil,
                onDismiss: {
                    viewModel.closeMetricDetail()
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(.ultraThinMaterial) // Transparent paper effect
            .presentationCornerRadius(28)
        }

        .sheet(isPresented: $showVibeSheet) {
            VibeControlSheet(viewModel: vibeControlViewModel)
                .presentationDetents([.fraction(0.6), .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.clear)
        }
        
        // MARK: - Other Destination Sheets
        .sheet(item: $viewModel.activeDestination) { destination in
            destinationView(for: destination)
                .aiQoSheetStyle()
        }
        .aiqoProfileSheet(isPresented: $isProfileSheetPresented)
    }
    
    // MARK: - Header View
    
    private var topChrome: some View {
        AiQoScreenTopChrome(
            horizontalInset: 10,
            profileVerticalOffset: -16,
            onProfileTap: { isProfileSheetPresented = true }
        ) {
            HStack {
                VibeDashboardTriggerButton {
                    showVibeSheet = true
                }
                .offset(y: -16)

                Spacer(minLength: 0)
            }
        }
    }
    
    // MARK: - Metrics Grid

    private var dailyAuraSection: some View {
        DailyAuraView(viewModel: dailyAuraViewModel)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.top, -19)
            .padding(.bottom, 16)
    }
    
    private var metricsGrid: some View {
        let allRows = Array(viewModel.gridRows.enumerated())
        return VStack(spacing: 28) {
            ForEach(allRows, id: \.offset) { rowIndex, row in
                HStack(spacing: 14) {
                    ForEach(Array(row.enumerated()), id: \.element.id) { colIndex, cardData in
                        let flatIndex = allRows.prefix(rowIndex).reduce(0) { $0 + $1.element.count } + colIndex
                        if viewModel.expandedMetric == cardData.kind {
                            // Show expanded card
                            ExpandedStatCard(
                                kind: cardData.kind,
                                headerValue: viewModel.chartData.headerText,
                                chartValues: viewModel.chartData.values,
                                tintColorName: cardData.tintColorName,
                                selectedScope: $viewModel.selectedScope,
                                onClose: {
                                    if UIAccessibility.isReduceMotionEnabled {
                                        viewModel.collapseExpandedCard()
                                    } else {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            viewModel.collapseExpandedCard()
                                        }
                                    }
                                }
                            )
                            .transition(.scale.combined(with: .opacity))
                        } else {
                            // Show normal card
                            HomeStatCard(data: cardData) {
                                HapticEngine.light()
                                viewModel.handleMetricTap(cardData.kind)
                            }
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 12)
                            .animation(
                                AiQoAccessibility.prefersReducedMotion
                                    ? .none
                                    : .spring(response: 0.4, dampingFraction: 0.8)
                                        .delay(Double(flatIndex) * 0.06),
                                value: appeared
                            )
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .animation(AiQoAccessibility.prefersReducedMotion ? .none : .spring(response: 0.3, dampingFraction: 0.8), value: viewModel.expandedMetric)
        .onAppear { appeared = true }
    }
    
    // MARK: - Kitchen Section
    
    private var kitchenSection: some View {
        VStack(spacing: 0) {
            KitchenShortcutButton {
                viewModel.openKitchen()
            }
            .offset(y: 9)

            Text(NSLocalizedString("tab.kitchen", comment: "Kitchen title under icon"))
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .padding(.top, -4)
        }
    }

    // MARK: - Destination Views
    
    @ViewBuilder
    private func destinationView(for destination: HomeDestination) -> some View {
        switch destination {
        case .profile:
            // Handled by separate sheet binding now
            EmptyView()

        case .kitchen:
            HomeKitchenSheetView()
            
        case .waterDetail:
            // Water Sheet with medium/large detents (Goal #5)
            WaterDetailSheetView(
                currentWaterLiters: $waterSheetLiters,
                onAddWater: { addedLiters in
                    Task {
                        await viewModel.addWater(liters: addedLiters)
                    }
                }
            )
            .onAppear {
                // Sync local state with ViewModel when sheet appears
                waterSheetLiters = viewModel.currentWaterLiters
            }
            .presentationDetents([.medium, .large]) // Changed from [.large] to [.medium, .large]
            .presentationDragIndicator(.visible)
            .presentationBackground(.ultraThinMaterial) // Transparent paper effect
            
        case .metricDetail:
            // Handled by separate sheet binding
            EmptyView()
        }
    }
}

// MARK: - Profile Button View (Unified)

private struct HomeKitchenRootView: View {
    @State private var viewModel = KitchenViewModel(repository: LocalMealsRepository())
    @StateObject private var kitchenStore = KitchenPersistenceStore()

    var body: some View {
        KitchenScreen(
            viewModel: viewModel,
            kitchenStore: kitchenStore
        )
    }
}

private struct HomeKitchenSheetView: View {
    @State private var selectedDetent: PresentationDetent = .fraction(0.75)

    var body: some View {
        NavigationStack {
            HomeKitchenRootView()
        }
        .presentationDetents([.fraction(0.75), .large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .presentationBackground(.ultraThinMaterial)
        .onAppear {
            selectedDetent = .fraction(0.75)
        }
    }
}

// MARK: - Kitchen Button

/// Animated kitchen button that prefers the custom kitchen asset provided in the catalog.
struct KitchenShortcutButton: View {
    var onTap: (() -> Void)?
    
    @State private var isPressed: Bool = false
    @State private var floatOffset: CGFloat = 0
    @State private var feedbackTrigger = 0

    private let preferredKitchenIconName = "Kitchenـicon"
    private let fallbackKitchenIconName = "Kitchen icon"

    private var kitchenIconName: String {
        UIImage(named: preferredKitchenIconName) != nil ? preferredKitchenIconName : fallbackKitchenIconName
    }
    
    var body: some View {
        Button(action: {
            feedbackTrigger += 1
            withAnimation(.snappy(duration: 0.30, extraBounce: 0.08)) {
                isPressed = true
            }

            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(150))
                withAnimation(.snappy(duration: 0.30, extraBounce: 0.08)) {
                    isPressed = false
                }
            }

            onTap?()
        }) {
            Image(kitchenIconName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .offset(y: floatOffset)
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.9 : 1.0)
        .sensoryFeedback(.selection, trigger: feedbackTrigger)
        .accessibilityLabel("افتح المطبخ")
        .onAppear {
            // Subtle floating animation (disabled when Reduce Motion is on)
            guard !AiQoAccessibility.prefersReducedMotion else { return }
            withAnimation(
                Animation
                    .easeInOut(duration: 2.0)
                    .repeatForever(autoreverses: true)
            ) {
                floatOffset = -4
            }
        }
    }
}

// MARK: - Metric Detail Sheet

/// Bottom sheet for displaying metric details with chart
struct MetricDetailSheet: View {
    let kind: MetricKind
    let headerValue: String
    let chartData: ChartSeriesData
    @Binding var selectedScope: TimeScope
    var onScopeChange: ((TimeScope) -> Void)?
    var onDismiss: (() -> Void)?

    private var resolvedHeaderValue: String {
        if !chartData.headerText.isEmpty, chartData.headerText != "—" {
            return chartData.headerText
        }

        if selectedScope == .day {
            return headerValue
        }

        return "—"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if kind == .sleep {
                    SleepDetailCardView(
                        historicalChartData: chartData,
                        initialTimeframe: selectedScope,
                        onTimeframeChange: { scope in
                            selectedScope = scope
                            onScopeChange?(scope)
                        }
                    )
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(kind.title)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary.opacity(0.7))

                        Text(resolvedHeaderValue)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .contentTransition(.numericText())

                        Picker(NSLocalizedString("time.scope", value: "Time Scope", comment: ""), selection: $selectedScope) {
                            ForEach(TimeScope.allCases) { scope in
                                Text(scope.title).tag(scope)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: selectedScope) { _, newScope in
                            onScopeChange?(newScope)
                        }

                        SimpleBarChart(
                            values: chartData.values,
                            barColor: Color.metricTint(for: kind.tintColorName).opacity(0.7)
                        )
                        .frame(height: 140)
                    }
                    .padding(20)
                    .background {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.ultraThinMaterial)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
                
                Spacer()
            }
            .background(Color.clear) // Allow transparent background to show through
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { onDismiss?() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.secondary)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("أغلق تفاصيل المؤشر")
                }
            }
        }
    }
}

// MARK: - Profile Sheet View

private struct ProfileSheetView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ProfileScreen()
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 22))
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityLabel("أغلق الملف الشخصي")
                    }
                }
        }
    }
}

// MARK: - Loading & Error Views

struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
        }
    }
}

struct ErrorBanner: View {
    let message: String
    var onDismiss: (() -> Void)?
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white)
            Spacer()
            Button(action: { onDismiss?() }) {
                Image(systemName: "xmark")
                    .foregroundStyle(.white)
            }
            .accessibilityLabel("إخفاء رسالة الخطأ")
        }
        .padding()
        .background(Color.red.opacity(0.9))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

// MARK: - MetricKind Extension for tint color

extension MetricKind {
    /// Returns the tint color name for this metric kind
    var tintColorName: String {
        switch self {
        case .steps, .calories, .sleep, .distance:
            return "mint"
        case .stand, .water:
            return "sand"
        }
    }
}

// MARK: - Previews

#Preview("Home View") {
    HomeView()
}

#Preview("Metric Detail Sheet") {
    MetricDetailSheet(
        kind: .steps,
        headerValue: "8,766",
        chartData: ChartSeriesData(
            values: [1200, 2400, 1800, 3200, 2800, 4100, 2900, 3500],
            headerText: "8,766"
        ),
        selectedScope: .constant(.day),
        onScopeChange: { _ in },
        onDismiss: { }
    )
    .presentationBackground(.ultraThinMaterial)
}

#Preview("Profile Button") {
    AiQoProfileButton { }
        .padding()
        .background(Color(.systemBackground))
}

#Preview("Kitchen Button") {
    KitchenShortcutButton { }
        .padding()
}
