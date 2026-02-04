import SwiftUI

// MARK: - HomeView

/// Main home screen displaying health metrics in a grid layout.
/// Replaces the UIKit `HomeViewController`.
struct HomeView: View {
    
    // MARK: - ViewModel
    
    @StateObject private var viewModel = HomeViewModel()
    
    // MARK: - Environment
    
    @Environment(\.scenePhase) private var scenePhase
    
    // MARK: - Local State for Water Sheet Binding
    
    /// Local state that syncs with ViewModel for two-way binding in WaterDetailSheetView
    @State private var waterSheetLiters: Double = 0.0
    
    // MARK: - Body
    
    var body: some View {
        ZStack(alignment: .top) {
            // Background
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Scrollable Content
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Metrics Grid
                        metricsGrid
                        
                        // Tribe Section
                        tribeSection
                        
                        // Bottom padding for tab bar
                        Spacer()
                            .frame(height: 100)
                    }
                    .padding(.top, 4)
                }
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
        // Sheet presentations
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
        }
        .sheet(item: $viewModel.activeDestination) { destination in
            destinationView(for: destination)
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack {
            Text(NSLocalizedString("screen.home.title", comment: "Home header title"))
                .font(.system(size: 32, weight: .heavy, design: .rounded))
            
            Spacer()
            
            Button(action: viewModel.openProfile) {
                ProfileButtonView()
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, -10)
        .frame(height: 60)
    }
    
    // MARK: - Metrics Grid
    
    private var metricsGrid: some View {
        VStack(spacing: 14) {
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
        .padding(.horizontal, 16)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.expandedMetric)
    }
    
    // MARK: - Tribe Section
    
    private var tribeSection: some View {
        VStack(spacing: 4) {
            Spacer()
                .frame(height: 27)
            
            TribeButton {
                viewModel.openTribe()
            }
            
            Text(NSLocalizedString("screen.home.tribe", comment: "Tribe title under icon"))
                .font(.system(size: 24, weight: .heavy, design: .rounded))
        }
        .frame(height: 145)
    }
    
    // MARK: - Destination Views
    
    @ViewBuilder
    private func destinationView(for destination: HomeDestination) -> some View {
        switch destination {
        case .profile:
            ProfileSheetView {
                viewModel.dismissDestination()
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            
        case .tribe:
            TribeRankingSheetView {
                viewModel.dismissDestination()
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            
        case .waterDetail:
            // Use the external WaterDetailSheetView with correct parameters
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
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            
        case .metricDetail:
            // Handled by separate sheet binding
            EmptyView()
        }
    }
}

// MARK: - Profile Button View

/// Circular profile button for the header
struct ProfileButtonView: View {
    var body: some View {
        Circle()
            .fill(Color(.secondarySystemBackground))
            .frame(width: 40, height: 40)
            .overlay {
                Image(systemName: "person.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.primary)
            }
    }
}

// MARK: - Tribe Button

/// Bouncy tribe button with floating animation
struct TribeButton: View {
    let action: () -> Void
    
    @State private var isPressed = false
    @State private var floatOffset: CGFloat = 0
    
    var body: some View {
        Button(action: action) {
            Image("Tribeicon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 120, height: 120)
        }
        .buttonStyle(BouncyButtonStyle(isPressed: $isPressed))
        .offset(y: floatOffset)
        .onAppear {
            startFloatingAnimation()
        }
    }
    
    private func startFloatingAnimation() {
        withAnimation(
            .easeInOut(duration: 2.0)
            .repeatForever(autoreverses: true)
        ) {
            floatOffset = 4
        }
    }
}

/// Custom button style with bouncy press feedback
struct BouncyButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(
                .spring(response: 0.4, dampingFraction: 0.5, blendDuration: 0),
                value: configuration.isPressed
            )
            .onChange(of: configuration.isPressed) { _, newValue in
                isPressed = newValue
                if newValue {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
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
        NavigationView {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(kind.title)
                        .font(.system(size: 18, weight: .heavy))
                    
                    Text(chartData.headerText.isEmpty ? headerValue : chartData.headerText)
                        .font(.system(size: 28, weight: .heavy))
                        .contentTransition(.numericText())
                    
                    Picker("Time Scope", selection: $selectedScope) {
                        ForEach(TimeScope.allCases) { scope in
                            Text(scope.title).tag(scope)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedScope) { _, newScope in
                        onScopeChange?(newScope)
                    }
                    
                    SimpleBarChart(values: chartData.values)
                        .frame(height: 120)
                }
                .padding(16)
                .background {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                
                Spacer()
            }
            .background(Color(.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { onDismiss?() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Profile Sheet View (Placeholder)

struct ProfileSheetView: View {
    var onDismiss: (() -> Void)?
    
    var body: some View {
        NavigationView {
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

// MARK: - Tribe Ranking Sheet View (Placeholder)

struct TribeRankingSheetView: View {
    var onDismiss: (() -> Void)?
    
    var body: some View {
        NavigationView {
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
            ProgressView().scaleEffect(1.5).tint(.white)
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
}

#Preview("Tribe Button") {
    TribeButton { }
        .padding()
}
