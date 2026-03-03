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
    private let footballButtonSize: CGFloat = 42

    @State private var selectedTab: ClubTopTab = .body
    @State private var selectedExercise: GymExercise?
    @State private var activeExercise: GymExercise?
    @State private var activeSession: LiveWorkoutSession?
    @State private var showMatchesSheet = false
    @State private var matchesSheetDetent: PresentationDetent = .fraction(0.5)

    @StateObject private var winsStore: WinsStore
    @StateObject private var questEngine: QuestEngine

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
            .animation(.easeInOut(duration: 0.22), value: selectedTab)
        }
        .navigationTitle(L10n.t("club_title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                PrimarySegmentedTabs(selection: $selectedTab)
                    .frame(width: segmentedTabsWidth)
            }

            ToolbarItem(placement: .topBarTrailing) {
                FootballHeaderButton(size: footballButtonSize) {
                    matchesSheetDetent = .fraction(0.5)
                    showMatchesSheet = true
                }
                .padding(.leading, 8)
            }
        }
        .clubSegmentedControlStyleScope()
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
            selectedExercise = activeExercise
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

    private var toolbarContentWidth: CGFloat {
        min(UIScreen.main.bounds.width - 24, 460)
    }

    private var segmentedTabsWidth: CGFloat {
        min(408, toolbarContentWidth - footballButtonSize - 28)
    }
}

private struct FootballHeaderButton: View {
    let size: CGFloat
    let action: () -> Void

    @State private var isPressed = false

    init(size: CGFloat = 44, action: @escaping () -> Void) {
        self.size = size
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color(uiColor: .secondarySystemBackground))

                Image("football")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size - 4, height: size - 4)
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
            .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
        }
        .frame(width: size + 10, height: 44)
        .contentShape(Rectangle())
        .buttonStyle(.plain)
        .zIndex(1)
        .scaleEffect(isPressed ? 0.94 : 1.0)
        .animation(.easeInOut(duration: 0.12), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    isPressed = true
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
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
