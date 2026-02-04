import SwiftUI

// MARK: - HomeStatCard

/// A card displaying a single health metric with title, value, unit, and icon.
/// Supports tap interaction with wave animation and haptic feedback.
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
    
    /// Scale for tap wave animation
    @State private var tapScale: CGFloat = 1.0
    
    /// Rotation for tap wave animation (3D tilt effect)
    @State private var tapRotation: Double = 0.0
    
    /// Floating animation offset
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
            return Color(red: 0.77, green: 0.94, blue: 0.86) // default to mint
        }
    }
    
    /// Title text color
    private var titleColor: Color {
        Color(white: 0.1, opacity: 0.85)
    }
    
    // MARK: - Body
    
    var body: some View {
        cardContent
            // 1. Floating animation offset
            .offset(y: floatOffsetY)
            // 2. Wave tap scale effect
            .scaleEffect(tapScale)
            // 3. 3D tilt rotation on tap
            .rotation3DEffect(.degrees(tapRotation), axis: (x: 1, y: 0, z: 0))
            .onAppear {
                startFloatingAnimation()
            }
            .onTapGesture {
                triggerWaveAnimation()
                onTap?()
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
    
    // MARK: - Card Content
    
    private var cardContent: some View {
        ZStack(alignment: .topTrailing) {
            // Background
            RoundedRectangle(cornerRadius: 22)
                .fill(tintColor)
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                // Title (uses kind.title from your existing MetricKind)
                Text(kind.title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(titleColor)
                    .lineLimit(1)
                
                // Value + Unit
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(displayValue)
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundColor(.black)
                        .contentTransition(.numericText())
                        .id(valueChangeID)
                    
                    // Uses kind.unit from your existing MetricKind
                    if !kind.unit.isEmpty {
                        Text(kind.unit)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.black)
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                
                Spacer(minLength: 0)
            }
            .padding(.top, 18)
            .padding(.leading, 16)
            .padding(.trailing, 40) // Space for icon
            .padding(.bottom, 16)
            
            // Icon (uses kind.icon from your existing MetricKind)
            Image(systemName: kind.icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 20, height: 20)
                .padding(.top, 12)
                .padding(.trailing, 12)
        }
        .frame(height: 132)
    }
    
    // MARK: - Animations
    
    /// Starts the subtle floating animation (cloud-like movement)
    private func startFloatingAnimation() {
        // Random delay so cards don't move in sync
        let randomDelay = Double.random(in: 0...2.0)
        let randomDuration = Double.random(in: 4.0...6.0)
        
        withAnimation(
            Animation
                .easeInOut(duration: randomDuration)
                .repeatForever(autoreverses: true)
                .delay(randomDelay)
        ) {
            floatOffsetY = -6.0
        }
    }
    
    /// Triggers the wave animation with haptic feedback on tap
    private func triggerWaveAnimation() {
        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        
        // Phase 1: Shrink and tilt
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0)) {
            tapScale = 0.92
            tapRotation = 8.0
        }
        
        // Phase 2: Bounce back to normal
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.4, blendDuration: 0)) {
                tapScale = 1.0
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
        VStack(alignment: .leading, spacing: 12) {
            // Header row
            HStack {
                Text(kind.title)
                    .font(.system(size: 18, weight: .heavy))
                
                Spacer()
                
                Button(action: { onClose?() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                }
            }
            
            // Value
            Text(headerValue)
                .font(.system(size: 28, weight: .heavy))
            
            // Scope picker
            Picker("Time Scope", selection: $selectedScope) {
                ForEach(TimeScope.allCases) { scope in
                    Text(scope.title).tag(scope)
                }
            }
            .pickerStyle(.segmented)
            .tint(tintColor.opacity(0.25))
            
            // Chart
            SimpleBarChart(values: chartValues)
                .frame(height: 120)
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        }
        .frame(minHeight: 220)
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
                    let barHeight = max(0, CGFloat(ratio) * geometry.size.height)
                    
                    RoundedRectangle(cornerRadius: min(barWidth, 6))
                        .fill(barColor)
                        .frame(width: barWidth, height: barHeight)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(.horizontal, spacing)
        }
    }
}

// MARK: - Color Definitions (for use throughout app)

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
        values: [1200, 2400, 1800, 3200, 2800, 4100, 2900, 3500, 2100, 1500, 800, 500]
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
