import SwiftUI
import UIKit
import Combine

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
    @State private var showTribeScreen: Bool = false
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
        .fullScreenCover(isPresented: $showTribeScreen) {
            NavigationStack {
                TribeView()
            }
        }
    }
    
    // MARK: - Header View
    
    private var topChrome: some View {
        AiQoScreenTopChrome(
            horizontalInset: 24,
            onProfileTap: { isProfileSheetPresented = true }
        ) {
            HStack {
                VibeDashboardTriggerButton {
                    showVibeSheet = true
                }

                Spacer(minLength: 0)

                StreakBadgeView()
            }
        }
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
        let allRows = Array(viewModel.gridRows.enumerated())
        return VStack(spacing: 8) {
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
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        viewModel.collapseExpandedCard()
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
                            .aiQoPressEffect()
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 12)
                            .animation(
                                .spring(response: 0.4, dampingFraction: 0.8)
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
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.expandedMetric)
        .onAppear { appeared = true }
    }
    
    // MARK: - Kitchen Section
    
    private var kitchenSection: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 8)

            KitchenShortcutButton {
                viewModel.openKitchen()
            }
            .offset(y: 2)
            
            Text(NSLocalizedString("tab.kitchen", comment: "Kitchen title under icon"))
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .padding(.top, -4)
        }
        .frame(height: 112)
    }

    // MARK: - Emirate Card

    private var emirateCard: some View {
        let level = LevelStore.shared.level
        let points = LevelStore.shared.totalXP

        return Button {
            showTribeScreen = true
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(NSLocalizedString("home.emirate.title", value: "إمارة 🏆", comment: ""))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: "162026"))

                    Text(String(format: NSLocalizedString("home.emirate.subtitle", value: "المستوى %@ · %@ نقطة", comment: ""), level.arabicFormatted, points.arabicFormatted))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(hex: "56636D"))
                }

                Spacer()

                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(hex: "75808A"))
            }
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(hex: "FFFDF8"))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "6FD7B4").opacity(0.2), Color(hex: "EDB45D").opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    }
                    .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6)
            }
        }
        .buttonStyle(.plain)
        .aiQoPressEffect()
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
                    }
                }
        }
    }
}

// MARK: - Tribe Ranking Sheet View

private struct TribeRankingSheetView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TribeView()
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
