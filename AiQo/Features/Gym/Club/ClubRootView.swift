import SwiftUI

enum ClubTopTab: String, CaseIterable, Identifiable {
    case body
    case plan
    case challenges
    case impact

    var id: Self { self }

    var titleKey: String {
        switch self {
        case .body: return "tab_body"
        case .plan: return "tab_plan"
        case .challenges: return "tab_challenges"
        case .impact: return "tab_impact"
        }
    }

    var accessibilityLabelKey: String {
        switch self {
        case .body: return "club.tab.body.accessibility.label"
        case .plan: return "club.tab.plan.accessibility.label"
        case .challenges: return "club.tab.challenges.accessibility.label"
        case .impact: return "club.tab.impact.accessibility.label"
        }
    }

    var accessibilityHintKey: String {
        switch self {
        case .body: return "club.tab.body.accessibility.hint"
        case .plan: return "club.tab.plan.accessibility.hint"
        case .challenges: return "club.tab.challenges.accessibility.hint"
        case .impact: return "club.tab.impact.accessibility.hint"
        }
    }
}

@MainActor
struct ClubRootView: View {
    @State private var selectedTab: ClubTopTab = .body
    @State private var selectedExercise: GymExercise?
    @State private var selectedCinematicExercise: GymExercise?
    @State private var activeExercise: GymExercise?
    @State private var activeSession: LiveWorkoutSession?
    @State private var activeCinematicContext: CinematicGrindLaunchContext?
    @State private var showMatchesSheet = false
    @State private var matchesSheetDetent: PresentationDetent = .fraction(0.5)

    @StateObject private var winsStore: WinsStore
    @StateObject private var questEngine: QuestEngine

    private let displayedTabs: [ClubTopTab] = [.impact, .challenges, .plan, .body]

    init() {
        _questEngine = StateObject(wrappedValue: .shared)
        _winsStore = StateObject(wrappedValue: WinsStore())
    }

    init(
        questEngine: QuestEngine,
        winsStore: WinsStore
    ) {
        _questEngine = StateObject(wrappedValue: questEngine)
        _winsStore = StateObject(wrappedValue: winsStore)
    }

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            ZStack {
                selectedContentView
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .animation(.spring(response: 0.34, dampingFraction: 0.84), value: selectedTab)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            topHeaderBar
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showMatchesSheet) {
            FootballSheetView()
                .presentationDetents([.fraction(0.5), .large], selection: $matchesSheetDetent)
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(30)
                .presentationBackground(.ultraThinMaterial)
        }
        .sheet(item: $selectedExercise) { exercise in
            ZStack(alignment: .topTrailing) {
                if let session = sessionForExercise(exercise) {
                    WorkoutSessionScreen(session: session)
                        .background(Color.clear)
                }

                Button {
                    selectedExercise = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(.white.opacity(0.8))
                        .background(
                            Circle()
                                .fill(.black.opacity(0.2))
                                .padding(2)
                        )
                }
                .padding(.top, 20)
                .padding(.trailing, 20)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(.ultraThinMaterial)
            .presentationCornerRadius(30)
        }
        .fullScreenCover(item: $selectedCinematicExercise) { exercise in
            if let session = sessionForExercise(exercise) {
                CinematicGrindFlowView(
                    exercise: exercise,
                    session: session,
                    launchContext: $activeCinematicContext
                ) {
                    selectedCinematicExercise = nil
                    if session.phase == .idle {
                        activeExercise = nil
                        activeSession = nil
                        activeCinematicContext = nil
                    }
                }
            }
        }
    }

    private var topHeaderBar: some View {
        HStack(alignment: .center, spacing: 12) {
            GlobalTopCapsuleTabsView(
                tabs: displayedTabs.map { L10n.t($0.titleKey) },
                selection: displayedSelectedTabIndex
            )

            footballToolbarButton
        }
        .padding(.top, 10)
        .padding(.horizontal, 18)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private var selectedContentView: some View {
        switch selectedTab {
        case .body:
            BodyView(onSelectExercise: handleExerciseSelection)
                .transition(.opacity)

        case .plan:
            PlanView()
                .transition(.opacity)

        case .challenges:
            ChallengesView(questEngine: questEngine)
                .transition(.opacity)

        case .impact:
            ImpactContainerView(winsStore: winsStore)
                .transition(.opacity)
        }
    }

    private func handleExerciseSelection(_ exercise: GymExercise) {
        if let session = activeSession, session.phase != .idle, let activeExercise {
            presentExercise(activeExercise)
            return
        }

        if exercise.workoutKind == .cinematicGrind {
            activeExercise = exercise
            activeSession = sessionForExercise(exercise)
            selectedCinematicExercise = exercise
            return
        }

        activeExercise = exercise
        activeSession = LiveWorkoutSession(
            title: exercise.title,
            activityType: exercise.type,
            locationType: exercise.location,
            currentWorkout: exercise.workoutKind,
            coachingProfile: exercise.coachingProfile
        )
        selectedExercise = exercise
    }

    private func sessionForExercise(_ exercise: GymExercise) -> LiveWorkoutSession? {
        if let session = activeSession, let activeExercise, activeExercise == exercise {
            return session
        }

        activeExercise = exercise
        let session = LiveWorkoutSession(
            title: exercise.title,
            activityType: exercise.type,
            locationType: exercise.location,
            currentWorkout: exercise.workoutKind,
            coachingProfile: exercise.coachingProfile
        )
        activeSession = session
        return session
    }

    private func presentExercise(_ exercise: GymExercise) {
        if exercise.workoutKind == .cinematicGrind {
            selectedCinematicExercise = exercise
        } else {
            selectedExercise = exercise
        }
    }

    private var displayedSelectedTabIndex: Binding<Int> {
        Binding(
            get: {
                displayedTabs.firstIndex(of: selectedTab) ?? 0
            },
            set: { newValue in
                guard displayedTabs.indices.contains(newValue) else { return }
                selectedTab = displayedTabs[newValue]
            }
        )
    }

    private var footballToolbarButton: some View {
        Button {
            matchesSheetDetent = .fraction(0.5)
            showMatchesSheet = true
        } label: {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)

                Circle()
                    .stroke(Color.white.opacity(0.14), lineWidth: 0.8)

                Image("football")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
            }
            .frame(width: 44, height: 44)
            .frame(width: 56, height: 56)
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: L10n.t("matches_button")))
        .accessibilityHint(Text(verbatim: L10n.t("club.header.football.accessibility.hint")))
    }
}

#Preview("Club Root RTL") {
    NavigationStack {
        ClubRootView()
    }
    .environment(\.layoutDirection, .rightToLeft)
}
