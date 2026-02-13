import SwiftUI

// MARK: - HomeStatCard

/// A card displaying a single health metric with title, value, unit, and icon.
/// Supports tap interaction with 3D tilt & scale animation and haptic feedback.
/// Uses the existing `MetricKind` enum from your project.
struct HomeStatCard: View {
    
    // MARK: - Properties
    
    /// The type of metric this card displays (uses your existing MetricKind)
    let kind: MetricKind
    
    /// The current display value (e.g., "8,766", "2.3 L")
    let displayValue: String
    
    /// Background tint color name ("mint" or "sand")
    let tintColorName: String
    
    /// Action triggered when card is tapped
    var onTap: (() -> Void)?
    
    // MARK: - Animation State
    
    /// Tracks whether the card is currently pressed (for 3D tilt & scale)
    @State private var isPressed: Bool = false
    
    /// Rotation angle for 3D tilt effect (tilts back from top)
    @State private var tapRotation: Double = 0.0
    
    /// Floating animation offset (cloud-like movement)
    @State private var floatOffsetY: CGFloat = 0.0
    
    /// Animation trigger for value changes
    @State private var valueChangeID: UUID = UUID()
    
    // MARK: - Computed Properties
    
    /// Resolve tint color from name
    private var tintColor: Color {
        switch tintColorName.lowercased() {
        case "mint":
            return Color(red: 0.77, green: 0.94, blue: 0.86)
        case "sand":
            return Color(red: 0.97, green: 0.84, blue: 0.64)
        default:
            return Color(red: 0.77, green: 0.94, blue: 0.86)
        }
    }
    
    /// Subtle shadow color based on tint
    private var shadowColor: Color {
        switch tintColorName.lowercased() {
        case "mint":
            return Color(red: 0.55, green: 0.80, blue: 0.70).opacity(0.35)
        case "sand":
            return Color(red: 0.85, green: 0.70, blue: 0.45).opacity(0.35)
        default:
            return Color(red: 0.55, green: 0.80, blue: 0.70).opacity(0.35)
        }
    }
    
    /// Check if displayValue already contains the unit (to avoid duplication like "0.5 L L")
    private var shouldShowUnit: Bool {
        guard !kind.unit.isEmpty else { return false }
        // Check if displayValue already ends with or contains the unit
        let unitLower = kind.unit.lowercased()
        let valueLower = displayValue.lowercased()
        return !valueLower.contains(unitLower)
    }
    
    // MARK: - Body
    
    var body: some View {
        // Use Button with PlainButtonStyle to completely remove white highlight/bubble on tap
        Button(action: {
            triggerWaveAnimation()
            onTap?()
        }) {
            cardContent
        }
        .buttonStyle(.plain) // Force plain style - no highlight
        .contentShape(Rectangle()) // Ensure entire card is tappable
        // 1. Floating animation offset (cloud-like movement)
        .offset(y: floatOffsetY)
        
        // 2. 3D Tilt & Scale effect
        .scaleEffect(isPressed ? 0.92 : 1.0)
        .rotation3DEffect(.degrees(tapRotation), axis: (x: 1, y: 0, z: 0))
        
        .onAppear {
            startFloatingAnimation()
        }
        .onChange(of: displayValue) { oldValue, newValue in
            if oldValue != newValue {
                withAnimation(.easeInOut(duration: 0.18)) {
                    valueChangeID = UUID()
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(kind.title), \(displayValue) \(kind.unit)")
        .accessibilityAddTraits(.isButton)
    }
    
    // MARK: - Card Content (Polished Layout)
    
    private var cardContent: some View {
        ZStack {
            // Background with subtle gradient
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [tintColor, tintColor.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: shadowColor, radius: 12, x: 0, y: 6)
            
            // Content Layout
            VStack(alignment: .leading, spacing: 0) {
                // Top Row: Title + Icon
                HStack(alignment: .top) {
                    Text(kind.title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.black.opacity(0.55))
                        .lineLimit(1)
                    
                    Spacer(minLength: 8)
                    
                    // Icon badge
                    Image(systemName: kind.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.black.opacity(0.4))
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.5))
                        )
                }
                .padding(.bottom, 12)
                
                Spacer(minLength: 0)
                
                // Bottom: Value + Unit (aligned baseline) - INCREASED SPACING from 3 to 6
                // Only show unit if displayValue doesn't already contain it
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(displayValue)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(.black.opacity(0.85))
                        .contentTransition(.numericText())
                        .id(valueChangeID)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    
                    // Only show unit if displayValue doesn't already contain it (fixes "L L" issue)
                    if shouldShowUnit {
                        Text(kind.unit)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.black.opacity(0.5))
                            .padding(.leading, 2) // Additional padding for better spacing
                            .padding(.bottom, 2)
                    }
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 18)
            .padding(.horizontal, 16)
        }
        .frame(height: 100)
    }
    
    // MARK: - Animations
    
    /// Starts the subtle floating animation (cloud-like movement)
    private func startFloatingAnimation() {
        let randomDelay = Double.random(in: 0...2.0)
        
        withAnimation(
            Animation
                .easeInOut(duration: 5.0)
                .repeatForever(autoreverses: true)
                .delay(randomDelay)
        ) {
            floatOffsetY = -6.0
        }
    }
    
    /// Triggers the 3D tilt & scale animation with haptic feedback on tap
    private func triggerWaveAnimation() {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0)) {
            isPressed = true
            tapRotation = 8.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.4, blendDuration: 0)) {
                isPressed = false
                tapRotation = 0.0
            }
        }
    }
}

// MARK: - Convenience Initializer using MetricCardData

extension HomeStatCard {
    /// Initialize using MetricCardData from ViewModel
    init(data: MetricCardData, onTap: (() -> Void)? = nil) {
        self.kind = data.kind
        self.displayValue = data.displayValue
        self.tintColorName = data.tintColorName
        self.onTap = onTap
    }
}

// MARK: - Stat Card Grid Row

/// A horizontal row of two stat cards for the home grid
struct StatCardRow: View {
    let cards: [MetricCardData]
    var onCardTap: ((MetricKind) -> Void)?
    
    var body: some View {
        HStack(spacing: 14) {
            ForEach(cards) { cardData in
                HomeStatCard(data: cardData) {
                    onCardTap?(cardData.kind)
                }
            }
        }
    }
}

// MARK: - Expanded Detail Card (for inline expansion)

/// An expanded version of the stat card showing chart and time scope selector
struct ExpandedStatCard: View {
    let kind: MetricKind
    let headerValue: String
    let chartValues: [Double]
    let tintColorName: String
    
    @Binding var selectedScope: TimeScope
    var onClose: (() -> Void)?
    
    private var tintColor: Color {
        switch tintColorName.lowercased() {
        case "mint":
            return Color(red: 0.77, green: 0.94, blue: 0.86)
        case "sand":
            return Color(red: 0.97, green: 0.84, blue: 0.64)
        default:
            return Color(red: 0.77, green: 0.94, blue: 0.86)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header row
            HStack(alignment: .center) {
                Text(kind.title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.primary.opacity(0.8))
                
                Spacer()
                
                Button(action: { onClose?() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(.secondary)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
            }
            
            // Value
            Text(headerValue)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            // Scope picker
            Picker(NSLocalizedString("time.scope", value: "Time Scope", comment: ""), selection: $selectedScope) {
                ForEach(TimeScope.allCases) { scope in
                    Text(scope.title).tag(scope)
                }
            }
            .pickerStyle(.segmented)
            
            // Chart
            SimpleBarChart(values: chartValues, barColor: tintColor.opacity(0.8))
                .frame(height: 120)
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .frame(minHeight: 240)
    }
}

// MARK: - Simple Bar Chart

/// A basic bar chart for displaying metric series data
struct SimpleBarChart: View {
    let values: [Double]
    var barColor: Color = Color.primary.opacity(0.15)
    var spacing: CGFloat = 6
    
    private var maxValue: Double {
        values.max() ?? 1
    }
    
    var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width
            let barCount = CGFloat(max(values.count, 1))
            let totalSpacing = spacing * (barCount + 1)
            let barWidth = max(2, (availableWidth - totalSpacing) / barCount)
            
            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                    let ratio = maxValue > 0 ? value / maxValue : 0
                    let barHeight = max(4, CGFloat(ratio) * geometry.size.height)
                    
                    RoundedRectangle(cornerRadius: min(barWidth / 2, 8))
                        .fill(barColor)
                        .frame(width: barWidth, height: barHeight)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(.horizontal, spacing)
        }
    }
}

// MARK: - Color Definitions

extension Color {
    static let mintTint = Color(red: 0.77, green: 0.94, blue: 0.86)
    static let sandTint = Color(red: 0.97, green: 0.84, blue: 0.64)
    
    static func metricTint(for name: String) -> Color {
        switch name.lowercased() {
        case "mint": return .mintTint
        case "sand": return .sandTint
        default: return .mintTint
        }
    }
}

// MARK: - Previews

#Preview("Steps Card") {
    HomeStatCard(
        kind: .steps,
        displayValue: "8,766",
        tintColorName: "mint"
    ) {
        print("Steps tapped")
    }
    .frame(width: 170)
    .padding()
}

#Preview("Water Card") {
    HomeStatCard(
        kind: .water,
        displayValue: "2.3 L",
        tintColorName: "sand"
    ) {
        print("Water tapped")
    }
    .frame(width: 170)
    .padding()
}

#Preview("All Cards Grid") {
    let mockCards: [MetricCardData] = [
        MetricCardData(id: .steps, displayValue: "8,766", tintColorName: "mint"),
        MetricCardData(id: .calories, displayValue: "841", tintColorName: "mint"),
        MetricCardData(id: .stand, displayValue: "91", tintColorName: "sand"),
        MetricCardData(id: .water, displayValue: "2.3 L", tintColorName: "sand"),
        MetricCardData(id: .sleep, displayValue: "9.0", tintColorName: "mint"),
        MetricCardData(id: .distance, displayValue: "6.57", tintColorName: "mint")
    ]
    
    VStack(spacing: 14) {
        ForEach(0..<3) { row in
            StatCardRow(
                cards: Array(mockCards[row*2..<row*2+2])
            ) { kind in
                print("\(kind.title) tapped")
            }
        }
    }
    .padding(16)
}

#Preview("Expanded Card") {
    ExpandedStatCard(
        kind: .steps,
        headerValue: "8,766",
        chartValues: [1200, 2400, 1800, 3200, 2800, 4100, 2900, 3500, 2100, 1500, 800, 500],
        tintColorName: "mint",
        selectedScope: .constant(.day)
    ) {
        print("Close tapped")
    }
    .padding()
}

#Preview("Bar Chart") {
    SimpleBarChart(
        values: [1200, 2400, 1800, 3200, 2800, 4100, 2900, 3500, 2100, 1500, 800, 500],
        barColor: .mintTint
    )
    .frame(height: 120)
    .padding()
}

#Preview("Interactive Card") {
    StatCardDemo()
}

/// Demo view to test value change animations
struct StatCardDemo: View {
    @State private var steps: Int = 8766
    
    var body: some View {
        VStack(spacing: 30) {
            HomeStatCard(
                kind: .steps,
                displayValue: NumberFormatter.localizedString(from: NSNumber(value: steps), number: .decimal),
                tintColorName: "mint"
            )
            .frame(width: 170)
            
            HStack(spacing: 20) {
                Button("-100") {
                    steps = max(0, steps - 100)
                }
                .buttonStyle(.bordered)
                
                Button("+100") {
                    steps += 100
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}
