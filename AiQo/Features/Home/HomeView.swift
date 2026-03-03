import SwiftUI
import UIKit
internal import Combine

// MARK: - HomeView

/// Main home screen displaying health metrics in a grid layout.
/// Replaces the UIKit `HomeViewController`.
struct HomeView: View {
    
    // MARK: - ViewModel
    
    @StateObject private var viewModel = HomeViewModel()
    @StateObject private var dailyAuraViewModel = DailyAuraViewModel()
    @StateObject private var vibeControlViewModel = VibeControlViewModel()
    
    // MARK: - Environment
    
    @Environment(\.scenePhase) private var scenePhase
    
    // MARK: - Local State for Water Sheet Binding
    
    /// Local state that syncs with ViewModel for two-way binding in WaterDetailSheetView
    @State private var waterSheetLiters: Double = 0.0
    
    // MARK: - Sheet Presentation States
    
    @State private var isProfileSheetPresented: Bool = false
    @State private var showVibeSheet: Bool = false
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Background
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerView

                VStack(spacing: 6) {
                    dailyAuraSection

                    // Metrics Grid
                    metricsGrid

                    // Kitchen Section
                    kitchenSection
                }
                .padding(.top, 6)
                .padding(.bottom, 4)
                .task {
                    await HealthKitService.shared.refreshWidgetFromToday()
                }

                Spacer(minLength: 0)
            }
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
                onScopeChange: { scope in
                    Task {
                        await viewModel.loadChartSeries(for: kind, scope: scope)
                    }
                },
                onDismiss: {
                    viewModel.closeMetricDetail()
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(.ultraThinMaterial) // Transparent paper effect
        }
        
        // MARK: - Profile Sheet
        .sheet(isPresented: $isProfileSheetPresented) {
            NavigationStack {
                ProfileScreen()
            }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .ignoresSafeArea(edges: .bottom)
        }

        .sheet(isPresented: $showVibeSheet) {
            VibeControlSheet(viewModel: vibeControlViewModel)
                .presentationDetents([.fraction(0.6), .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
        }
        
        // MARK: - Other Destination Sheets
        .sheet(item: $viewModel.activeDestination) { destination in
            destinationView(for: destination)
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack {
            VibeDashboardTriggerButton {
                showVibeSheet = true
            }

            Spacer()

            FloatingProfileButton {
                isProfileSheetPresented = true
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 4)
        .frame(height: 68)
    }
    
    // MARK: - Metrics Grid

    private var dailyAuraSection: some View {
        DailyAuraView(viewModel: dailyAuraViewModel)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.top, -4)
            .padding(.bottom, 16)
    }
    
    private var metricsGrid: some View {
        VStack(spacing: 8) {
            ForEach(Array(viewModel.gridRows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 14) {
                    ForEach(row) { cardData in
                        if viewModel.expandedMetric == cardData.kind {
                            // Show expanded card
                            ExpandedStatCard(
                                kind: cardData.kind,
                                headerValue: viewModel.chartData.headerText,
                                chartValues: viewModel.chartData.values,
                                tintColorName: cardData.tintColorName,
                                selectedScope: $viewModel.selectedScope,
                                onClose: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        viewModel.collapseExpandedCard()
                                    }
                                }
                            )
                            .transition(.scale.combined(with: .opacity))
                        } else {
                            // Show normal card
                            HomeStatCard(data: cardData) {
                                viewModel.handleMetricTap(cardData.kind)
                            }
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.expandedMetric)
    }
    
    // MARK: - Kitchen Section
    
    private var kitchenSection: some View {
        VStack(spacing: 4) {
            Spacer()
                .frame(height: 4)

            KitchenShortcutButton {
                viewModel.openKitchen()
            }
            
            Text(NSLocalizedString("tab.kitchen", comment: "Kitchen title under icon"))
                .font(.system(size: 24, weight: .heavy, design: .rounded))
        }
        .frame(height: 112)
    }

    // MARK: - Destination Views
    
    @ViewBuilder
    private func destinationView(for destination: HomeDestination) -> some View {
        switch destination {
        case .profile:
            // Handled by separate sheet binding now
            EmptyView()
            
        case .tribe:
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
                .frame(width: 90, height: 90)
                .offset(y: floatOffset)
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.9 : 1.0)
        .sensoryFeedback(.selection, trigger: feedbackTrigger)
        .onAppear {
            // Subtle floating animation
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
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(kind.title)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.primary.opacity(0.7))
                    
                    Text(chartData.headerText.isEmpty ? headerValue : chartData.headerText)
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
                }
            }
        }
    }
}

// MARK: - Profile Sheet View (Placeholder - kept for backwards compatibility)

struct ProfileSheetView: View {
    var onDismiss: (() -> Void)?
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Profile")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                Text("Profile content goes here")
                    .foregroundColor(.secondary)
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { onDismiss?() }
                }
            }
        }
    }
}

// MARK: - Tribe Ranking Sheet View (Placeholder - kept for backwards compatibility)

struct TribeRankingSheetView: View {
    var onDismiss: (() -> Void)?
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Tribe Ranking")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                Text("Tribe ranking content goes here")
                    .foregroundColor(.secondary)
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { onDismiss?() }
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
                .foregroundColor(.yellow)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.white)
            Spacer()
            Button(action: { onDismiss?() }) {
                Image(systemName: "xmark")
                    .foregroundColor(.white)
            }
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
    FloatingProfileButton { }
        .padding()
        .background(Color(.systemBackground))
}

#Preview("Kitchen Button") {
    KitchenShortcutButton { }
        .padding()
}
