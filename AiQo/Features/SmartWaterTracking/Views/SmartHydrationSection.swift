import SwiftUI

struct SmartHydrationSection: View {
    @ObservedObject var service: HydrationService

    private var language: AppLanguage { AppSettingsStore.shared.appLanguage }
    private var isArabic: Bool { language == .arabic }

    // Brand grammar borrowed from SpotifyVibeCard: rounded 24-corner glass,
    // soft mint/beige diagonal sheen, 1px white stroke, deep drop shadow.
    private let cornerRadius: CGFloat = 24
    private let waterBlue = Color(red: 0.24, green: 0.67, blue: 0.93)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerRow
            if service.settings.smartTrackingEnabled {
                paceSummary
                lastDrinkRow
                goalEditor
            }
            guidanceBlock
        }
        .padding(18)
        .background(cardBackground)
        .overlay(cardStroke)
        .padding(.horizontal, 20)
        .task { await service.refreshState() }
    }

    // MARK: - Card styling

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                LinearGradient(
                    colors: [
                        waterBlue.opacity(0.14),
                        Color.white.opacity(0.06),
                        waterBlue.opacity(0.06)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
            .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 8)
    }

    private var cardStroke: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(Color.white.opacity(0.16), lineWidth: 1)
    }

    // MARK: - Header row (icon + toggle)

    private var headerRow: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "drop.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(waterBlue)
                .frame(width: 30, height: 30)
                .background(Circle().fill(waterBlue.opacity(0.12)))

            VStack(alignment: .leading, spacing: 2) {
                Text(NSLocalizedString("hydration.smart.toggle.title", comment: ""))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                Text(NSLocalizedString("hydration.smart.toggle.subtitle", comment: ""))
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { service.settings.smartTrackingEnabled },
                set: { newValue in
                    service.settings.smartTrackingEnabled = newValue
                    Task { await service.reevaluateAndSchedule() }
                }
            ))
            .labelsHidden()
            .tint(AiQoColors.mintSoft)
        }
    }

    // MARK: - Pace summary

    private var paceSummary: some View {
        HStack(spacing: 10) {
            paceBadge
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(remainingText)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)
                Text(consumedText)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.secondary)
            }
        }
    }

    private var paceBadge: some View {
        let label = HydrationPhrases.paceLabel(service.state.paceStatus, language: language)
        return Text(label)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(paceBaseColor.opacity(paceBackgroundOpacity))
            )
            .overlay(
                Capsule().stroke(paceBaseColor.opacity(0.6), lineWidth: 0.5)
            )
    }

    // Brand-palette only. Wellness tone: no red, no orange, no system green.
    // Mint for ahead/on-track, sand for behind — deeper-sand is the only
    // escalation signal.
    private var paceBaseColor: Color {
        switch service.state.paceStatus {
        case .ahead, .onTrack:     return AiQoColors.mintSoft
        case .behind, .veryBehind: return AiQoColors.sandSoft
        }
    }

    private var paceBackgroundOpacity: Double {
        switch service.state.paceStatus {
        case .ahead:      return 0.45
        case .onTrack:    return 0.30
        case .behind:     return 0.45
        case .veryBehind: return 0.65
        }
    }

    private var remainingText: String {
        let remainingL = service.state.remainingML / 1000.0
        return String(
            format: NSLocalizedString("hydration.remaining.format", comment: ""),
            remainingL
        )
    }

    private var consumedText: String {
        let consumedL = service.state.consumedML / 1000.0
        let goalL = service.state.goalML / 1000.0
        return String(
            format: NSLocalizedString("hydration.consumed.format", comment: ""),
            consumedL,
            goalL
        )
    }

    // MARK: - Goal editor

    private var goalEditor: some View {
        HStack(spacing: 10) {
            Image(systemName: "target")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(NSLocalizedString("hydration.goal.title", comment: ""))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Text(goalValueText)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Stepper(
                "",
                value: Binding(
                    get: { service.settings.goalML },
                    set: { newValue in
                        service.settings.goalML = newValue
                        Task { await service.reevaluateAndSchedule() }
                    }
                ),
                in: 1500...4000,
                step: 250
            )
            .labelsHidden()
        }
    }

    private var goalValueText: String {
        let liters = service.settings.goalML / 1000.0
        let fmt = isArabic ? "الهدف: %.2f ل/يوم" : "Goal: %.2f L/day"
        return String(format: fmt, liters)
    }

    // MARK: - Last drink row

    @ViewBuilder
    private var lastDrinkRow: some View {
        if let last = service.state.lastDrinkDate, let source = service.state.lastDrinkSource {
            HStack(spacing: 8) {
                Image(systemName: "clock")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text(lastDrinkText(for: last, source: source))
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
    }

    private func lastDrinkText(for date: Date, source: HydrationSource) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = Locale(identifier: isArabic ? "ar" : "en")
        let rel = formatter.localizedString(for: date, relativeTo: Date())
        let src = HydrationPhrases.sourceLabel(source, language: language)
        return isArabic ? "آخر شربة \(rel) · \(src)" : "Last sip \(rel) · \(src)"
    }

    // MARK: - Guidance block (WHO / EFSA)

    private var guidanceBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
                .overlay(Color.primary.opacity(0.08))
                .padding(.vertical, 2)

            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(waterBlue)
                Text(NSLocalizedString("hydration.guidance.title", comment: ""))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }

            Text(NSLocalizedString("hydration.guidance.body", comment: ""))
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            DisclosureGroup {
                VStack(alignment: .leading, spacing: 10) {
                    Text(NSLocalizedString("hydration.guidance.factors", comment: ""))
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        sourceChip(
                            title: NSLocalizedString("hydration.guidance.link.who", comment: ""),
                            url: URL(string: "https://www.who.int/news-room/fact-sheets/detail/healthy-diet")!
                        )
                        sourceChip(
                            title: NSLocalizedString("hydration.guidance.link.efsa", comment: ""),
                            url: URL(string: "https://www.efsa.europa.eu/en/efsajournal/pub/1459")!
                        )
                    }
                }
                .padding(.top, 6)
            } label: {
                Text(NSLocalizedString("hydration.guidance.more", comment: ""))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(waterBlue)
            }
        }
    }

    private func sourceChip(title: String, url: URL) -> some View {
        Link(destination: url) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9, weight: .semibold))
            }
            .foregroundStyle(waterBlue)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(waterBlue.opacity(0.10))
            )
            .overlay(
                Capsule().stroke(waterBlue.opacity(0.22), lineWidth: 0.5)
            )
        }
    }
}
