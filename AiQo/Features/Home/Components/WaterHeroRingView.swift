import SwiftUI

/// The hero ring shown at the top of `WaterDetailSheetView`. A pure SwiftUI
/// progress ring using the AiQo soft-mint / soft-sand accent pair — no raster
/// asset, no blue fill, no emoji. The view is stateless: it takes the values
/// it needs and renders. Callers own the hydration data.
struct WaterHeroRingView: View {
    /// Today's committed intake, in liters.
    let consumedLiters: Double
    /// Daily goal, in liters. Used for both the progress arc and the sublabel.
    let goalLiters: Double

    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Derived

    /// 0...1, capped. Overflow above the goal still renders as a full ring —
    /// the consumed number keeps counting, the ring does not keep rotating.
    private var progress: Double {
        guard goalLiters > 0 else { return 0 }
        return min(1, consumedLiters / goalLiters)
    }

    /// Integer percent shown in the pill beneath the ring.
    private var percent: Int {
        Int((progress * 100).rounded())
    }

    /// Lighter track in dark mode so the mint progress stroke keeps contrast
    /// against `.ultraThinMaterial`.
    private var trackOpacity: Double {
        colorScheme == .dark ? 0.12 : 0.18
    }

    // MARK: - Constants

    private let ringSize: CGFloat = 220
    private let lineWidth: CGFloat = 16

    // MARK: - Body

    var body: some View {
        ZStack {
            ring
            center
        }
        .frame(width: ringSize, height: ringSize)
        .animation(.spring(response: 0.55, dampingFraction: 0.85), value: progress)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(NSLocalizedString("water.hero.a11y.label", comment: "")))
        .accessibilityValue(Text(accessibilityValueText))
        // Tap target for a future goal-picker / detail action. Inert today;
        // left as the reserved touch surface so callers don't have to restructure.
        .contentShape(Circle())
    }

    // MARK: - Ring

    private var ring: some View {
        ZStack {
            // Track
            Circle()
                .stroke(
                    AiQoColors.mintSoft.opacity(trackOpacity),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )

            // Progress arc — mint → sand → mint angular sweep so the ring
            // reads as one cohesive band regardless of rotation.
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            AiQoColors.mintSoft,
                            AiQoColors.sandSoft,
                            AiQoColors.mintSoft
                        ]),
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: AiQoColors.mintSoft.opacity(0.25), radius: 14, x: 0, y: 4)
        }
    }

    // MARK: - Center

    private var center: some View {
        VStack(spacing: 2) {
            Text(consumedLiters, format: .number.precision(.fractionLength(1)))
                .font(.system(size: 52, weight: .black, design: .rounded))
                .foregroundStyle(.primary)
                .contentTransition(.numericText(value: consumedLiters))
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text(unitLabel)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)

            Text(String(format: NSLocalizedString("water.hero.goal.format", comment: ""), goalLiters))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.tertiary)
                .padding(.top, 2)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Helpers

    /// Unit suffix mirrors the locale so Arabic users see "ل" and English "L".
    /// Derived from the current layout direction, which SwiftUI already sets
    /// correctly for the enclosing sheet.
    private var unitLabel: String {
        let code = Locale.current.language.languageCode?.identifier
        return code == "ar" ? "ل" : "L"
    }

    private var accessibilityValueText: String {
        let consumed = Self.numberFormatter.string(from: NSNumber(value: consumedLiters)) ?? "\(consumedLiters)"
        let goal = Self.numberFormatter.string(from: NSNumber(value: goalLiters)) ?? "\(goalLiters)"
        return String(
            format: NSLocalizedString("water.hero.a11y.value.format", comment: ""),
            consumed, goal, percent
        )
    }

    private static let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 1
        f.minimumFractionDigits = 1
        return f
    }()
}

// MARK: - Previews

#Preview("Light · AR · 60%") {
    WaterHeroRingView(consumedLiters: 1.5, goalLiters: 2.5)
        .padding(40)
        .background(Color(.systemBackground))
        .environment(\.locale, Locale(identifier: "ar"))
        .environment(\.layoutDirection, .rightToLeft)
}

#Preview("Dark · AR · 7%") {
    WaterHeroRingView(consumedLiters: 0.2, goalLiters: 3.0)
        .padding(40)
        .background(Color(.systemBackground))
        .preferredColorScheme(.dark)
        .environment(\.locale, Locale(identifier: "ar"))
        .environment(\.layoutDirection, .rightToLeft)
}

#Preview("Light · EN · 112% cap") {
    WaterHeroRingView(consumedLiters: 2.8, goalLiters: 2.5)
        .padding(40)
        .background(Color(.systemBackground))
        .environment(\.locale, Locale(identifier: "en"))
}
