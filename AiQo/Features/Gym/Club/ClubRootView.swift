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
    private static let gratitudeExerciseKey = "gym.exercise.gratitude"

    private struct PresentedExercise: Identifiable {
        let exercise: GymExercise
        let session: LiveWorkoutSession

        var id: UUID { exercise.id }
    }

    @State private var selectedTab: ClubTopTab = .body
    @State private var presentedExercise: PresentedExercise?
    @State private var presentedCinematicExercise: PresentedExercise?
    @State private var isGratitudeSessionPresented = false
    @State private var isTribePresented = false
    @State private var activeExercise: GymExercise?
    @State private var activeSession: LiveWorkoutSession?
    @State private var activeCinematicContext: CinematicGrindLaunchContext?

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
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                topHeaderBar
                selectedContentView
                    .padding(.top, 19.5)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .animation(.easeInOut(duration: 0.3), value: selectedTab)
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $isTribePresented) {
            TribeScreen()
        }
        .sheet(item: $presentedExercise) { presented in
            ZStack(alignment: .topTrailing) {
                WorkoutSessionSheetView(session: presented.session)
                    .background(Color.clear)

                Button {
                    presentedExercise = nil
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
        .fullScreenCover(item: $presentedCinematicExercise) { presented in
            CinematicGrindFlowView(
                exercise: presented.exercise,
                session: presented.session,
                launchContext: $activeCinematicContext
            ) {
                presentedCinematicExercise = nil
                if presented.session.phase == .idle {
                    activeExercise = nil
                    activeSession = nil
                    activeCinematicContext = nil
                }
            }
        }
        .fullScreenCover(isPresented: $isGratitudeSessionPresented) {
            GratitudeSessionView()
        }
    }

    private var topHeaderBar: some View {
        HStack(spacing: 10) {
            // Tabs — appear on RIGHT in RTL (first in code)
            PrimarySegmentedTabs(
                tabs: displayedTabs,
                selection: $selectedTab
            )

            // Tribe icon — appears on LEFT in RTL (second in code)
            Button {
                isTribePresented = true
            } label: {
                Image("Tribe_icon")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 42, height: 42)
                    .clipShape(Circle())
                    .shadow(color: Color(hex: "D4B87A").opacity(0.3), radius: 4, y: 2)
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 10)
        .padding(.vertical, 6)
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
        if let activeSession, activeSession.phase != .idle, let activeExercise {
            presentExercise(activeExercise, session: activeSession)
            return
        }

        if exercise.titleKey == Self.gratitudeExerciseKey {
            presentedExercise = nil
            presentedCinematicExercise = nil
            isGratitudeSessionPresented = true
            return
        }

        let session = makeSession(for: exercise)
        activeExercise = exercise
        activeSession = session
        activeCinematicContext = nil
        presentExercise(exercise, session: session)
    }

    private func makeSession(for exercise: GymExercise) -> LiveWorkoutSession {
        LiveWorkoutSession(
            title: exercise.title,
            activityType: exercise.type,
            locationType: exercise.location,
            currentWorkout: exercise.workoutKind,
            coachingProfile: exercise.coachingProfile
        )
    }

    private func presentExercise(_ exercise: GymExercise, session: LiveWorkoutSession) {
        if exercise.workoutKind == .cinematicGrind {
            presentedExercise = nil
            presentedCinematicExercise = PresentedExercise(exercise: exercise, session: session)
        } else {
            presentedCinematicExercise = nil
            presentedExercise = PresentedExercise(exercise: exercise, session: session)
        }
    }

}

#Preview("Club Root RTL") {
    NavigationStack {
        ClubRootView()
    }
    .environment(\.layoutDirection, .rightToLeft)
}
