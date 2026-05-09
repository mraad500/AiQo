import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Entry

struct HydrationEntry: TimelineEntry {
    let date: Date
    /// Committed consumed mL written by the app (HealthKit source of truth).
    let consumedML: Int
    /// Daily goal in mL written by the app.
    let goalML: Int
    /// Pending taps not yet drained into HealthKit by the app.
    /// Included in the display so the widget never regresses.
    let pendingTaps: Int

    var effectiveConsumedML: Int {
        consumedML + pendingTaps * HydrationWidgetShared.tapIncrementML
    }

    var safeGoalML: Int {
        goalML > 0 ? goalML : 2500
    }

    var progress: Double {
        let goal = Double(safeGoalML)
        guard goal > 0 else { return 0 }
        return min(1, Double(effectiveConsumedML) / goal)
    }

    var percentText: String {
        "\(Int((progress * 100).rounded()))%"
    }

    /// "1.60 / 2.50 L" — localized decimal separator.
    func amountText(arabic: Bool) -> String {
        let consumedL = Double(effectiveConsumedML) / 1000.0
        let goalL = Double(safeGoalML) / 1000.0
        let fmt = arabic ? "%.2f / %.2f ل" : "%.2f / %.2f L"
        return String(format: fmt, consumedL, goalL)
    }

    static let placeholder = HydrationEntry(
        date: .now,
        consumedML: 1250,
        goalML: 2500,
        pendingTaps: 0
    )
}

// MARK: - Provider

struct HydrationProvider: TimelineProvider {
    func placeholder(in context: Context) -> HydrationEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (HydrationEntry) -> Void) {
        completion(readEntry(at: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HydrationEntry>) -> Void) {
        let now = Date()
        // Refresh after 15 minutes as a fallback; interactive taps + app-side
        // `WidgetCenter.reloadTimelines` provide the real-time refresh path.
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: now) ?? now.addingTimeInterval(900)
        let timeline = Timeline(entries: [readEntry(at: now)], policy: .after(next))
        completion(timeline)
    }

    private func readEntry(at date: Date) -> HydrationEntry {
        let defaults = HydrationWidgetShared.sharedDefaults
        let consumed = defaults?.integer(forKey: HydrationWidgetShared.Keys.consumedML) ?? 0
        let goal = defaults?.integer(forKey: HydrationWidgetShared.Keys.goalML) ?? 0
        let counter = defaults?.integer(forKey: HydrationWidgetShared.Keys.tapCounter) ?? 0
        let seen = defaults?.integer(forKey: HydrationWidgetShared.Keys.tapCounterSeen) ?? 0
        return HydrationEntry(
            date: date,
            consumedML: consumed,
            goalML: goal,
            pendingTaps: max(0, counter - seen)
        )
    }
}

// MARK: - View

struct HydrationWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: HydrationEntry

    var body: some View {
        // The ENTIRE small widget is the "+0.25 L" button — matches the
        // reference widget's no-button minimalism while staying discoverable:
        // a single tap anywhere adds water.
        Button(intent: AddWaterIntent()) {
            smallCard
        }
        .buttonStyle(.plain)
    }

    private var isArabic: Bool {
        HydrationPalette.currentAppLanguage() == "ar"
    }

    private var smallCard: some View {
        ZStack {
            // Card: dark glass matching AiQoWidget motion card
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(HydrationPalette.cardGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(HydrationPalette.stroke, lineWidth: 1)
                )

            // Warm accent glow (sand), mirrors motion widget's cool glow
            Circle()
                .fill(HydrationPalette.glow)
                .frame(width: 180, height: 180)
                .blur(radius: 24)
                .offset(x: -88, y: 22)

            VStack(alignment: .leading, spacing: 10) {
                headerRow
                Spacer(minLength: 0)
                ringWithCenter
                    .frame(maxWidth: .infinity)
                Spacer(minLength: 0)
                amountRow
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
        }
    }

    // MARK: - Subviews

    private var headerRow: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(HydrationPalette.teal)
                .frame(width: 7, height: 7)
            Text(isArabic ? "ماء" : "WATER")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(HydrationPalette.textSecondary)
                .kerning(isArabic ? 0 : 0.6)
            Spacer()
        }
    }

    private var ringWithCenter: some View {
        ZStack {
            // Track
            Circle()
                .stroke(HydrationPalette.track, lineWidth: 8)

            // Progress arc — mint → warm sand, matching AiQo family tones
            Circle()
                .trim(from: 0, to: entry.progress)
                .stroke(
                    HydrationPalette.ringGradient,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: HydrationPalette.teal.opacity(0.35), radius: 6, x: 0, y: 0)

            // Subtle water identity + percentage
            VStack(spacing: 2) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(HydrationPalette.textSecondary)
                Text(entry.percentText)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(HydrationPalette.textPrimary)
                    .contentTransition(.numericText())
            }
        }
        .frame(width: 92, height: 92)
    }

    private var amountRow: some View {
        Text(entry.amountText(arabic: isArabic))
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(HydrationPalette.textMuted)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Widget

struct HydrationWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: HydrationWidgetShared.widgetKind,
            provider: HydrationProvider()
        ) { entry in
            HydrationWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    HydrationPalette.cardGradient
                }
        }
        .configurationDisplayName("AiQo Hydration")
        .description("Daily hydration progress. Tap to log +0.25 L.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

// MARK: - Palette (scoped to hydration widget)

/// Mirrors the motion widget's `Palette` grammar. Duplicated intentionally —
/// the motion widget's enum is file-scoped `private`, and we'd rather ship a
/// local copy than loosen its visibility. Keep this in sync if the design
/// system evolves (low churn; only 7 values).
private enum HydrationPalette {
    static let teal = Color(red: 0.10, green: 0.86, blue: 0.78)
    static let sand = Color(red: 0.91, green: 0.79, blue: 0.59)
    static let glow = Color(red: 0.76, green: 0.62, blue: 0.38).opacity(0.28)

    static let cardGradient = LinearGradient(
        colors: [
            Color(red: 0.05, green: 0.09, blue: 0.11),
            Color(red: 0.06, green: 0.17, blue: 0.17),
            Color(red: 0.11, green: 0.16, blue: 0.18)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let ringGradient = AngularGradient(
        gradient: Gradient(colors: [teal, sand, teal]),
        center: .center,
        startAngle: .degrees(-90),
        endAngle: .degrees(270)
    )

    static let textPrimary = Color.white.opacity(0.96)
    static let textSecondary = Color.white.opacity(0.78)
    static let textMuted = Color.white.opacity(0.58)
    static let stroke = Color.white.opacity(0.13)
    static let track = Color.white.opacity(0.14)

    /// Reads the app-side language preference from the App Group suite first
    /// (if the app has mirrored it), falling back to the user's preferred
    /// locale. Keeps widget text in sync with the app without requiring its
    /// own `Localizable.strings` bundle.
    static func currentAppLanguage() -> String {
        if let shared = HydrationWidgetShared.sharedDefaults,
           let stored = shared.string(forKey: "aiqo.app.language") {
            return stored
        }
        if let stored = UserDefaults.standard.string(forKey: "aiqo.app.language") {
            return stored
        }
        return Locale.current.language.languageCode?.identifier ?? "en"
    }
}
