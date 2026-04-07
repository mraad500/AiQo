import SwiftUI
import UIKit

enum CinematicPlatform: String, CaseIterable, Identifiable, Hashable {
    case netflix = "Netflix"
    case youtube = "YouTube"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .netflix:
            return L10n.t("cinematic.platform.netflix.subtitle")
        case .youtube:
            return L10n.t("cinematic.platform.youtube.subtitle")
        }
    }

    var icon: String {
        switch self {
        case .netflix:
            return "play.rectangle.fill"
        case .youtube:
            return "play.tv.fill"
        }
    }

    var accent: Color {
        switch self {
        case .netflix:
            return Color(hex: "FF8B88")
        case .youtube:
            return Color(hex: "BEE9FF")
        }
    }

    var secondaryAccent: Color {
        switch self {
        case .netflix:
            return Color(hex: "FFDCC6")
        case .youtube:
            return Color(hex: "E7F9BF")
        }
    }

    var appURL: URL? {
        switch self {
        case .netflix:
            return URL(string: "nflx://")
        case .youtube:
            return URL(string: "youtube://")
        }
    }

    func fallbackURL(for query: String) -> URL? {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query

        switch self {
        case .netflix:
            return URL(string: "https://www.netflix.com/search?q=\(encoded)")
        case .youtube:
            return URL(string: "https://www.youtube.com/results?search_query=\(encoded)")
        }
    }
}

enum CinematicMood: String, CaseIterable, Identifiable, Hashable {
    case actionEpic = "Action/Epic"
    case comedyFunny = "Comedy/Funny"
    case inspirationMotivation = "Inspiration/Motivation"
    case chillStory = "Chill/Story"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .actionEpic:
            return "bolt.fill"
        case .comedyFunny:
            return "face.smiling.fill"
        case .inspirationMotivation:
            return "figure.run.circle.fill"
        case .chillStory:
            return "sparkles.tv.fill"
        }
    }

    var accent: Color {
        switch self {
        case .actionEpic:
            return Color(hex: "FFD4B3")
        case .comedyFunny:
            return Color(hex: "FFF0A8")
        case .inspirationMotivation:
            return Color(hex: "CFF7D3")
        case .chillStory:
            return Color(hex: "D9D2FF")
        }
    }
}

struct CinematicGrindSuggestion: Equatable, Hashable {
    let title: String
    let duration: Int
    let description: String
    let captainLine: String
    let searchQuery: String
    let vibeLabel: String
}

struct CinematicGrindLaunchContext: Equatable, Hashable {
    let duration: Int
    let platform: CinematicPlatform
    let mood: CinematicMood
    let suggestion: CinematicGrindSuggestion
}

func generateSuggestion(duration: Int, platform: String, mood: String) -> CinematicGrindSuggestion {
    let resolvedPlatform = CinematicPlatform(rawValue: platform) ?? .netflix
    let resolvedMood = CinematicMood(rawValue: mood) ?? .actionEpic
    let cadence = CinematicCadence(duration: duration)

    let seed: CinematicSeed
    switch (resolvedPlatform, resolvedMood) {
    case (.netflix, .actionEpic):
        seed = CinematicSeed(
            shortTitle: "Action Pilot Rush",
            mediumTitle: "Blockbuster Grind Cut",
            longTitle: "Epic Franchise Night",
            searchQuery: "action thriller series",
            vibeLabel: "Heart up, pace controlled"
        )
    case (.netflix, .comedyFunny):
        seed = CinematicSeed(
            shortTitle: "Stand-Up Sprint",
            mediumTitle: "Comedy Cruise",
            longTitle: "Laugh Marathon",
            searchQuery: "stand up comedy special",
            vibeLabel: "Low stress, smooth cadence"
        )
    case (.netflix, .inspirationMotivation):
        seed = CinematicSeed(
            shortTitle: "Victory Arc Warmup",
            mediumTitle: "Champion Story Session",
            longTitle: "Documentary Grind Mode",
            searchQuery: "sports documentary",
            vibeLabel: "Focused breathing, steady drive"
        )
    case (.netflix, .chillStory):
        seed = CinematicSeed(
            shortTitle: "Story Drift",
            mediumTitle: "Slow-Burn Glide",
            longTitle: "Cinema Float Mode",
            searchQuery: "feel good drama",
            vibeLabel: "Soft rhythm, easy Zone 2"
        )
    case (.youtube, .actionEpic):
        seed = CinematicSeed(
            shortTitle: "Action Clip Burst",
            mediumTitle: "Epic Edit Session",
            longTitle: "Stunt Reel Marathon",
            searchQuery: "cinematic action compilation",
            vibeLabel: "Energy high, breathing calm"
        )
    case (.youtube, .comedyFunny):
        seed = CinematicSeed(
            shortTitle: "Comedy Clip Loop",
            mediumTitle: "Laugh Track Cruise",
            longTitle: "Sketch Marathon",
            searchQuery: "funny sketches compilation",
            vibeLabel: "Relaxed jaw, relaxed heart"
        )
    case (.youtube, .inspirationMotivation):
        seed = CinematicSeed(
            shortTitle: "Mindset Sprint",
            mediumTitle: "Motivation Flow",
            longTitle: "Discipline Documentary Stack",
            searchQuery: "motivational documentary",
            vibeLabel: "Head locked in, legs automatic"
        )
    case (.youtube, .chillStory):
        seed = CinematicSeed(
            shortTitle: "Storytelling Escape",
            mediumTitle: "Narrative Glide",
            longTitle: "Longform Chill Session",
            searchQuery: "cinematic storytelling video",
            vibeLabel: "Steady stride, quiet nervous system"
        )
    }

    let title: String
    switch cadence {
    case .short:
        title = seed.shortTitle
    case .medium:
        title = seed.mediumTitle
    case .long:
        title = seed.longTitle
    }

    let description = "Captain Hammoudi lined up a \(cadence.watchFormat) on \(resolvedPlatform.rawValue) so your eyes stay busy while your effort stays clean in Zone 2."
    let captainLine = "Captain Hammoudi: \(seed.vibeLabel). Hold this for \(duration) minutes and let the story carry the cardio."

    return CinematicGrindSuggestion(
        title: title,
        duration: duration,
        description: description,
        captainLine: captainLine,
        searchQuery: seed.searchQuery,
        vibeLabel: seed.vibeLabel
    )
}

@MainActor
struct CinematicGrindFlowView: View {
    let exercise: GymExercise
    @ObservedObject var session: LiveWorkoutSession
    @Binding var launchContext: CinematicGrindLaunchContext?
    let onClose: () -> Void

    @State private var stage: CinematicGrindStage

    init(
        exercise: GymExercise,
        session: LiveWorkoutSession,
        launchContext: Binding<CinematicGrindLaunchContext?>,
        onClose: @escaping () -> Void
    ) {
        self.exercise = exercise
        self.session = session
        _launchContext = launchContext
        self.onClose = onClose
        _stage = State(
            initialValue: launchContext.wrappedValue == nil || session.phase == .idle
            ? .setup
            : .active
        )
    }

    var body: some View {
        ZStack {
            CinematicBackdrop(style: stage == .setup ? .setup : .active)
                .ignoresSafeArea()

            switch stage {
            case .setup:
                CinematicGrindSetupView(
                    session: session,
                    initialContext: launchContext,
                    onClose: handleClose,
                    onStart: handleStart
                )
                .transition(.opacity.combined(with: .scale(scale: 0.98)))

            case .active:
                if let launchContext {
                    CinematicGrindActiveView(
                        session: session,
                        context: launchContext,
                        onReturnToPlatform: { openPlatform(for: launchContext) },
                        onClose: handleClose
                    )
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
                }
            }
        }
        .onChange(of: session.phase) { _, newPhase in
            guard stage == .active, newPhase == .idle else { return }
            launchContext = nil
            onClose()
        }
    }

    private func handleStart(_ context: CinematicGrindLaunchContext) {
        launchContext = context
        session.title = exercise.title

        if session.phase == .idle {
            session.startFromPhone()
        }

        withAnimation(.spring(response: 0.55, dampingFraction: 0.92)) {
            stage = .active
        }

        openPlatform(for: context)
    }

    private func handleClose() {
        if session.phase == .idle {
            launchContext = nil
        }
        onClose()
    }

    private func openPlatform(for context: CinematicGrindLaunchContext) {
        guard let url = context.platform.appURL else { return }

        UIApplication.shared.open(url, options: [:]) { success in
            guard !success, let fallback = context.platform.fallbackURL(for: context.suggestion.searchQuery) else { return }
            UIApplication.shared.open(fallback, options: [:], completionHandler: nil)
        }
    }
}

struct CinematicGrindSetupView: View {
    @Environment(\.layoutDirection) private var layoutDirection

    @ObservedObject var session: LiveWorkoutSession
    let initialContext: CinematicGrindLaunchContext?
    let onClose: () -> Void
    let onStart: (CinematicGrindLaunchContext) -> Void

    @State private var selectedDuration: Int
    @State private var selectedPlatform: CinematicPlatform
    @State private var selectedMood: CinematicMood
    @State private var suggestion: CinematicGrindSuggestion?
    @State private var acceptedSuggestion: CinematicGrindSuggestion?
    @State private var isThinking = false

    private let durations = [30, 45, 60, 90, 120]

    init(
        session: LiveWorkoutSession,
        initialContext: CinematicGrindLaunchContext?,
        onClose: @escaping () -> Void,
        onStart: @escaping (CinematicGrindLaunchContext) -> Void
    ) {
        self.session = session
        self.initialContext = initialContext
        self.onClose = onClose
        self.onStart = onStart
        _selectedDuration = State(initialValue: initialContext?.duration ?? 45)
        _selectedPlatform = State(initialValue: initialContext?.platform ?? .netflix)
        _selectedMood = State(initialValue: initialContext?.mood ?? .actionEpic)
        _suggestion = State(initialValue: initialContext?.suggestion)
        _acceptedSuggestion = State(initialValue: initialContext?.suggestion)
    }

    private var suggestionKey: String {
        "\(selectedDuration)-\(selectedPlatform.rawValue)-\(selectedMood.rawValue)"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AiQoSpacing.lg) {
                setupHeader

                CinemaSetupSection(
                    title: L10n.t("cinematic.duration.title"),
                    subtitle: L10n.t("cinematic.duration.subtitle")
                ) {
                    AiQoPillSegment(
                        options: durations,
                        selection: $selectedDuration,
                        accent: selectedPlatform.accent,
                        title: { "\($0)" },
                        subtitle: { _ in L10n.t("cinematic.duration.minutes.short") }
                    )
                }

                CinemaSetupSection(
                    title: L10n.t("cinematic.platform.title"),
                    subtitle: L10n.t("cinematic.platform.subtitle")
                ) {
                    AiQoPlatformPicker(
                        options: CinematicPlatform.allCases,
                        selection: $selectedPlatform,
                        title: { $0.rawValue },
                        subtitle: { $0.subtitle },
                        systemImage: { $0.icon },
                        accent: { $0.accent }
                    )
                }

                CinemaSetupSection(
                    title: L10n.t("cinematic.mood.title"),
                    subtitle: L10n.t("cinematic.mood.subtitle")
                ) {
                    AiQoChoiceGrid(
                        options: CinematicMood.allCases,
                        selection: $selectedMood,
                        title: { $0.rawValue },
                        systemImage: { $0.icon },
                        accent: { $0.accent }
                    )
                }

                recommendationSection
            }
            .padding(.horizontal, AiQoSpacing.md)
            .padding(.top, AiQoSpacing.md)
            .padding(.bottom, AiQoSpacing.lg)
        }
        .background(AiQoTheme.Colors.primaryBackground)
        .safeAreaInset(edge: .bottom) {
            if let acceptedSuggestion {
                AiQoBottomCTA(
                    title: L10n.t("cinematic.start.button"),
                    systemImage: "play.fill"
                ) {
                    onStart(
                        CinematicGrindLaunchContext(
                            duration: selectedDuration,
                            platform: selectedPlatform,
                            mood: selectedMood,
                            suggestion: acceptedSuggestion
                        )
                    )
                }
            }
        }
        .task(id: suggestionKey) {
            acceptedSuggestion = nil
            isThinking = true
            suggestion = nil

            try? await Task.sleep(nanoseconds: 850_000_000)
            guard !Task.isCancelled else { return }

            let next = generateSuggestion(
                duration: selectedDuration,
                platform: selectedPlatform.rawValue,
                mood: selectedMood.rawValue
            )

            withAnimation(.spring(response: 0.52, dampingFraction: 0.88)) {
                suggestion = next
                isThinking = false
            }
        }
    }

    private var setupHeader: some View {
        VStack(alignment: .leading, spacing: AiQoSpacing.md) {
            HStack(alignment: .top, spacing: AiQoSpacing.md) {
                VStack(alignment: .leading, spacing: AiQoSpacing.xs) {
                    Text(L10n.t("cinematic.header.eyebrow").uppercased())
                        .font(AiQoTheme.Typography.caption.weight(.semibold))
                        .tracking(1.2)
                        .foregroundStyle(AiQoTheme.Colors.textSecondary)

                    Text(L10n.t("cinematic.header.title"))
                        .font(AiQoTheme.Typography.screenTitle)
                        .foregroundStyle(AiQoTheme.Colors.textPrimary)
                        .multilineTextAlignment(.leading)

                    Text("\(selectedDuration) \(L10n.t("cinematic.duration.minutes.short")) • \(selectedPlatform.rawValue) • \(selectedMood.rawValue)")
                        .font(AiQoTheme.Typography.caption)
                        .foregroundStyle(AiQoTheme.Colors.textSecondary)
                }

                Spacer(minLength: AiQoSpacing.sm)

                Button(action: onClose) {
                    Image(systemName: closeIconName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AiQoTheme.Colors.textPrimary)
                        .frame(width: AiQoMetrics.minimumTapTarget, height: AiQoMetrics.minimumTapTarget)
                        .background(AiQoTheme.Colors.surface, in: RoundedRectangle(cornerRadius: AiQoRadius.control, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: AiQoRadius.control, style: .continuous)
                                .stroke(AiQoTheme.Colors.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }

            Divider()
                .overlay(AiQoTheme.Colors.border)
        }
    }

    @ViewBuilder
    private var recommendationSection: some View {
        if isThinking {
            CinemaSetupSection(
                title: L10n.t("cinematic.recommendation.title"),
                subtitle: L10n.t("cinematic.thinking.subtitle")
            ) {
                VStack(spacing: AiQoSpacing.md) {
                    ZStack {
                        Circle()
                            .stroke(AiQoTheme.Colors.border, lineWidth: 8)
                            .frame(width: 52, height: 52)

                        Circle()
                            .trim(from: 0.08, to: 0.74)
                            .stroke(
                                LinearGradient(
                                    colors: [selectedPlatform.accent, selectedMood.accent],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 6, lineCap: .round)
                            )
                            .frame(width: 52, height: 52)
                            .rotationEffect(.degrees(isThinking ? 360 : 0))
                            .animation(.linear(duration: 1.4).repeatForever(autoreverses: false), value: isThinking)
                    }

                    VStack(spacing: AiQoSpacing.xs) {
                        Text(L10n.t("cinematic.thinking.title"))
                            .font(AiQoTheme.Typography.sectionTitle)
                            .foregroundStyle(AiQoTheme.Colors.textPrimary)

                        Text(L10n.t("cinematic.thinking.subtitle"))
                            .font(AiQoTheme.Typography.body)
                            .foregroundStyle(AiQoTheme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        } else if let suggestion {
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: AiQoSpacing.md) {
                        HStack(spacing: AiQoSpacing.xs) {
                            RecommendationPill(title: "\(suggestion.duration) \(L10n.t("cinematic.duration.minutes.short"))")
                            RecommendationPill(title: selectedPlatform.rawValue)
                        }
                        .padding(.top, 28)

                        Text(suggestion.title)
                            .font(.system(.title2, design: .rounded).weight(.bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [AiQoTheme.Colors.textPrimary, selectedPlatform.accent, selectedMood.accent],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .fixedSize(horizontal: false, vertical: true)

                        Text(suggestion.captainLine)
                            .font(AiQoTheme.Typography.body.weight(.medium))
                            .foregroundStyle(AiQoTheme.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: AiQoSpacing.xs) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 12, weight: .semibold))
                            Text(suggestion.searchQuery)
                                .font(AiQoTheme.Typography.body)
                                .lineLimit(1)
                        }
                        .foregroundStyle(AiQoTheme.Colors.textSecondary)
                        .padding(.horizontal, AiQoSpacing.md)
                        .padding(.vertical, AiQoSpacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: AiQoRadius.control, style: .continuous)
                                .fill(AiQoTheme.Colors.surfaceSecondary)
                        )

                        Button {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) {
                                acceptedSuggestion = suggestion
                            }
                        } label: {
                            HStack(spacing: AiQoSpacing.sm) {
                                Image(systemName: acceptedSuggestion == suggestion ? "checkmark.circle.fill" : "sparkles")
                                Text(L10n.t("cinematic.accept.button"))
                            }
                            .font(AiQoTheme.Typography.cta)
                            .foregroundStyle(AiQoTheme.Colors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 50)
                            .background(
                                RoundedRectangle(cornerRadius: AiQoRadius.card, style: .continuous)
                                    .fill(AiQoTheme.Colors.surfaceSecondary)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: AiQoRadius.card, style: .continuous)
                                    .stroke(
                                        acceptedSuggestion == suggestion
                                        ? selectedPlatform.accent.opacity(0.7)
                                        : AiQoTheme.Colors.border,
                                        lineWidth: 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(AiQoSpacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: AiQoRadius.card, style: .continuous)
                            .fill(AiQoTheme.Colors.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AiQoRadius.card, style: .continuous)
                            .stroke(AiQoTheme.Colors.border, lineWidth: 1)
                    )
                }
                .padding(.top, 34)

                ZStack {
                    Circle()
                        .fill(selectedPlatform.accent.opacity(0.16))
                        .frame(width: 104, height: 104)

                    Image("Hammoudi5")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 110, height: 110)
                        .offset(y: -40)
                }
                .accessibilityHidden(true)
            }
        }
    }

    private var closeIconName: String {
        layoutDirection == .rightToLeft ? "arrow.forward" : "arrow.backward"
    }
}

private struct CinemaSetupSection<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: AiQoSpacing.md) {
            VStack(alignment: .leading, spacing: AiQoSpacing.xs) {
                Text(title)
                    .font(AiQoTheme.Typography.sectionTitle)
                    .foregroundStyle(AiQoTheme.Colors.textPrimary)

                Text(subtitle)
                    .font(AiQoTheme.Typography.caption)
                    .foregroundStyle(AiQoTheme.Colors.textSecondary)
            }

            content
        }
        .padding(AiQoSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AiQoRadius.card, style: .continuous)
                .fill(AiQoTheme.Colors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AiQoRadius.card, style: .continuous)
                .stroke(AiQoTheme.Colors.border, lineWidth: 1)
        )
    }
}

struct CinematicGrindActiveView: View {
    @ObservedObject var session: LiveWorkoutSession
    let context: CinematicGrindLaunchContext
    let onReturnToPlatform: () -> Void
    let onClose: () -> Void

    private let indicatorColumns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                activeHeader
                timerHero
                primaryIndicators
                secondaryStatus
                returnButton
                controlButtons
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 34)
        }
    }

    private var activeHeader: some View {
        CinematicGlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.t("cinematic.active.eyebrow"))
                            .font(.system(.caption, design: .rounded).weight(.bold))
                            .foregroundStyle(.white.opacity(0.7))

                        Text(context.suggestion.title)
                            .font(.system(size: 27, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(.white.opacity(0.82))
                            .frame(width: 32, height: 32)
                            .background(.black.opacity(0.16), in: Circle())
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 10) {
                    RecommendationPill(title: context.platform.rawValue)
                    RecommendationPill(title: context.mood.rawValue)
                    RecommendationPill(title: session.statusText)
                }
            }
        }
    }

    private var timerHero: some View {
        CinematicGlassCard {
            VStack(spacing: 18) {
                Text(formatTime(session.elapsedSeconds))
                    .font(.system(size: 52, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(L10n.t("cinematic.active.goal"))
                            .font(.system(.caption, design: .rounded).weight(.bold))
                            .foregroundStyle(.white.opacity(0.66))
                        Spacer()
                        Text("\(progressMinutes)/\(context.duration) \(L10n.t("cinematic.duration.minutes.short"))")
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .foregroundStyle(.white)
                    }

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(.white.opacity(0.1))

                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [context.platform.secondaryAccent, context.platform.accent],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(geometry.size.width * progressRatio, 20))
                        }
                    }
                    .frame(height: 12)
                }

                Text(context.suggestion.captainLine)
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .foregroundStyle(.white.opacity(0.78))
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var primaryIndicators: some View {
        LazyVGrid(columns: indicatorColumns, spacing: 14) {
            CinematicIndicatorCard(
                title: L10n.t("cinematic.metrics.heart_rate"),
                value: session.heartRate > 0 ? "\(Int(session.heartRate.rounded()))" : "--",
                unit: "BPM",
                icon: "heart.fill",
                accent: Color(hex: "FFB1B7")
            )

            CinematicIndicatorCard(
                title: L10n.t("cinematic.metrics.calories"),
                value: "\(Int(session.activeEnergy.rounded()))",
                unit: "KCAL",
                icon: "flame.fill",
                accent: Color(hex: "FFE3A1")
            )

            CinematicIndicatorCard(
                title: L10n.t("cinematic.metrics.zone"),
                value: zoneStateLabel,
                unit: session.zone2RangeLabel,
                icon: "waveform.path.ecg",
                accent: Color(hex: "C9F5D5")
            )

            CinematicIndicatorCard(
                title: L10n.t("cinematic.metrics.platform"),
                value: context.platform.rawValue,
                unit: context.mood.rawValue,
                icon: context.platform.icon,
                accent: context.platform.secondaryAccent
            )
        }
    }

    private var secondaryStatus: some View {
        CinematicGlassCard {
            HStack(spacing: 14) {
                statusBadge(
                    title: L10n.t("cinematic.active.live_sync"),
                    value: session.isWatchReachable ? L10n.t("cinematic.active.connected") : L10n.t("cinematic.active.connecting")
                )

                statusBadge(
                    title: L10n.t("cinematic.active.search"),
                    value: context.suggestion.searchQuery
                )
            }
        }
    }

    private var returnButton: some View {
        Button(action: onReturnToPlatform) {
            HStack(spacing: 12) {
                Image(systemName: context.platform.icon)
                Text(String(format: L10n.t("cinematic.return.button"), context.platform.rawValue))
            }
            .font(.system(.headline, design: .rounded).weight(.bold))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .background(
                LinearGradient(
                    colors: [context.platform.secondaryAccent, context.platform.accent],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 24, style: .continuous)
            )
            .shadow(color: context.platform.accent.opacity(0.26), radius: 18, x: 0, y: 10)
        }
        .buttonStyle(.plain)
    }

    private var controlButtons: some View {
        HStack(spacing: 14) {
            Button {
                if session.phase == .running {
                    session.pauseFromPhone()
                } else if session.phase == .paused {
                    session.resumeFromPhone()
                } else if session.phase == .idle {
                    session.startFromPhone()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: primaryControlIcon)
                    Text(primaryControlTitle)
                }
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(.white.opacity(0.11), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(session.phase == .starting || session.phase == .ending || session.isControlPending)

            if session.canEnd {
                Button {
                    session.endFromPhone()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Color(hex: "FF8B88"), in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var progressRatio: CGFloat {
        guard context.duration > 0 else { return 0 }
        return min(CGFloat(session.elapsedSeconds) / CGFloat(context.duration * 60), 1)
    }

    private var progressMinutes: Int {
        min(session.elapsedSeconds / 60, context.duration)
    }

    private var zoneStateLabel: String {
        switch session.zone2AuraState {
        case .inactive:
            return L10n.t("cinematic.zone.ready")
        case .warmingUp:
            return L10n.t("cinematic.zone.warmup")
        case .inZone2:
            return L10n.t("cinematic.zone.locked")
        case .tooFast:
            return L10n.t("cinematic.zone.too_fast")
        case .tooSlow:
            return L10n.t("cinematic.zone.too_slow")
        }
    }

    private var primaryControlIcon: String {
        switch session.phase {
        case .running:
            return "pause.fill"
        case .paused, .idle:
            return "play.fill"
        case .starting, .ending:
            return "hourglass"
        }
    }

    private var primaryControlTitle: String {
        switch session.phase {
        case .running:
            return L10n.t("cinematic.control.pause")
        case .paused:
            return L10n.t("cinematic.control.resume")
        case .idle:
            return L10n.t("cinematic.control.start")
        case .starting:
            return L10n.t("cinematic.control.connecting")
        case .ending:
            return L10n.t("cinematic.control.ending")
        }
    }

    private func statusBadge(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundStyle(.white.opacity(0.62))

            Text(value)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func formatTime(_ totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%02d:%02d", minutes, seconds)
    }
}

private enum CinematicGrindStage {
    case setup
    case active
}

private enum CinematicCadence {
    case short
    case medium
    case long

    init(duration: Int) {
        switch duration {
        case ..<50:
            self = .short
        case ..<100:
            self = .medium
        default:
            self = .long
        }
    }

    var watchFormat: String {
        switch self {
        case .short:
            return "tight episode sprint"
        case .medium:
            return "smooth movie block"
        case .long:
            return "long-form cinema run"
        }
    }
}

private struct CinematicSeed {
    let shortTitle: String
    let mediumTitle: String
    let longTitle: String
    let searchQuery: String
    let vibeLabel: String
}

private struct CinematicBackdrop: View {
    enum Style {
        case setup
        case active
    }

    @Environment(\.colorScheme) private var colorScheme

    let style: Style

    var body: some View {
        ZStack {
            baseGradient

            Circle()
                .fill(primaryGlow)
                .frame(width: style == .setup ? 240 : 280, height: style == .setup ? 240 : 280)
                .blur(radius: style == .setup ? 36 : 58)
                .offset(x: -130, y: style == .setup ? -260 : -220)

            Circle()
                .fill(secondaryGlow)
                .frame(width: style == .setup ? 220 : 260, height: style == .setup ? 220 : 260)
                .blur(radius: style == .setup ? 34 : 52)
                .offset(x: 150, y: style == .setup ? -110 : 240)
        }
    }

    private var baseGradient: LinearGradient {
        switch style {
        case .setup:
            return LinearGradient(
                colors: [
                    AiQoTheme.Colors.primaryBackground,
                    AiQoTheme.Colors.primaryBackground,
                    AiQoTheme.Colors.surfaceSecondary.opacity(colorScheme == .dark ? 0.92 : 0.75)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .active:
            return LinearGradient(
                colors: [
                    Color(light: Color(hex: "EEF3FA"), dark: Color(hex: "0B1016")),
                    Color(light: Color(hex: "DCE6F3"), dark: Color(hex: "121A24")),
                    Color(light: Color(hex: "C8D7E7"), dark: Color(hex: "081018"))
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var primaryGlow: Color {
        switch style {
        case .setup:
            return AiQoTheme.Colors.accent.opacity(colorScheme == .dark ? 0.12 : 0.08)
        case .active:
            return Color(light: Color(hex: "8ADFD2"), dark: Color(hex: "89E3D5"))
                .opacity(colorScheme == .dark ? 0.2 : 0.1)
        }
    }

    private var secondaryGlow: Color {
        switch style {
        case .setup:
            return Color(light: Color(hex: "BFD4FF"), dark: Color(hex: "AFC9FF"))
                .opacity(colorScheme == .dark ? 0.12 : 0.09)
        case .active:
            return Color(light: Color(hex: "AFCBFF"), dark: Color(hex: "B8CAFF"))
                .opacity(colorScheme == .dark ? 0.18 : 0.1)
        }
    }
}

private struct CinematicGlassCard<Content: View>: View {
    let accent: Color
    let contentPadding: CGFloat
    @ViewBuilder let content: Content

    init(
        accent: Color = .white.opacity(0.16),
        contentPadding: CGFloat = 20,
        @ViewBuilder content: () -> Content
    ) {
        self.accent = accent
        self.contentPadding = contentPadding
        self.content = content()
    }

    var body: some View {
        content
            .padding(contentPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .background(
                LinearGradient(
                    colors: [
                        .white.opacity(0.08),
                        .white.opacity(0.02)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(.white.opacity(0.14), lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(accent.opacity(0.75), lineWidth: 1.1)
                    .blur(radius: 6)
            )
            .shadow(color: .black.opacity(0.24), radius: 28, x: 0, y: 18)
    }
}

private struct RecommendationPill: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(0.74))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            )
    }
}

private struct CinematicIndicatorCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(accent)
                Spacer()
                Text(unit)
                    .font(.system(.caption2, design: .rounded).weight(.bold))
                    .foregroundStyle(.white.opacity(0.56))
            }

            Text(value)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.72)

            Text(title)
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundStyle(.white.opacity(0.62))
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 144, alignment: .leading)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
    }
}

#Preview("Cinema Setup Light") {
    ZStack {
        CinematicBackdrop(style: .setup)
            .ignoresSafeArea()

        CinematicGrindSetupView(
            session: LiveWorkoutSession(
                title: "Cinema Cardio",
                currentWorkout: .cinematicGrind,
                coachingProfile: .captainHamoudiZone2
            ),
            initialContext: nil,
            onClose: {},
            onStart: { _ in }
        )
    }
}

#Preview("Cinema Setup RTL Dark") {
    ZStack {
        CinematicBackdrop(style: .setup)
            .ignoresSafeArea()

        CinematicGrindSetupView(
            session: LiveWorkoutSession(
                title: "سينماتك غرايند",
                currentWorkout: .cinematicGrind,
                coachingProfile: .captainHamoudiZone2
            ),
            initialContext: nil,
            onClose: {},
            onStart: { _ in }
        )
    }
    .environment(\.layoutDirection, .rightToLeft)
    .preferredColorScheme(.dark)
}
