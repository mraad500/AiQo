import SwiftUI
import UIKit

// =========================
// File: Features/Gym/GymView.swift
// =========================

// MARK: - Tab Enum
enum GymTab: Int, CaseIterable, Identifiable {
    case body = 0
    case vitals
    case plan
    case wins
    case recap

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .body: return L10n.t("gym.tab.body")
        case .vitals: return L10n.t("gym.tab.vitals")
        case .plan: return L10n.t("gym.tab.plan")
        case .wins: return L10n.t("gym.tab.wins")
        case .recap: return L10n.t("gym.tab.recap")
        }
    }
}

// MARK: - Design Tokens
struct GymTheme {
    static let mint = Color(red: 0.77, green: 0.94, blue: 0.86)
    static let beige = Color(red: 0.97, green: 0.84, blue: 0.64)
    static let gold = Color(red: 1.00, green: 0.85, blue: 0.35)
    static let glassAlpha: Double = 0.16

    static let warmOrange = Color(red: 1.00, green: 0.65, blue: 0.20)
    static let punchyPink = Color(red: 1.00, green: 0.40, blue: 0.55)
    static let intenseTeal = Color(red: 0.00, green: 0.75, blue: 0.65)
    static let electricPurple = Color(red: 0.55, green: 0.45, blue: 0.95)
    static let brandLemon = Color(red: 1.00, green: 0.93, blue: 0.72)
    static let brandLavender = Color(red: 0.96, green: 0.88, blue: 1.00)
}

// MARK: - Main Gym View
struct GymView: View {
    @State private var selectedTab: GymTab = .body
    @State private var selectedExercise: GymExercise?
    @State private var activeExercise: GymExercise?
    @State private var activeSession: LiveWorkoutSession?
    @State private var showFootballSheet = false   // ✅ جديد
    @StateObject private var winsStore: WinsStore
    @StateObject private var questsStore: QuestDailyStore

    @Namespace private var animation
    private let topTabBarHeight: CGFloat = 72

    init() {
        let winsStore = WinsStore()
        _winsStore = StateObject(wrappedValue: winsStore)
        _questsStore = StateObject(wrappedValue: QuestDailyStore(winsStore: winsStore))
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Background
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header Section
                headerSection
                    .padding(.top, 16)

                // Apple Segmented Navigation Bar
                Picker("", selection: $selectedTab) {
                    ForEach(GymTab.allCases) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: .infinity)
                .frame(height: topTabBarHeight)
                .padding(.horizontal, 6)
                .padding(.top, 12)
                .tint(.yellow)
                .controlSize(.large)
                .font(.system(size: 22, weight: .heavy, design: .rounded))

                // Content Area
                TabContentView(
                    selectedTab: selectedTab,
                    questsStore: questsStore,
                    winsStore: winsStore,
                    onSelectExercise: handleExerciseSelection
                )
                    .padding(.top, 24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .ignoresSafeArea(.container, edges: .bottom)

            // Dimming Layer for exercise sheet
            if selectedExercise != nil {
                Color.black
                    .opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture { selectedExercise = nil }
                    .transition(.opacity)
            }
        }

        // ✅ شيت كرة القدم (ورقة شفافة من الأسفل)
        .sheet(isPresented: $showFootballSheet) {
            FootballSheetView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(30)
                .presentationBackground(.ultraThinMaterial) // شفافة
        }

        // Sheet للتمرين (مثل ما عندك)
        .sheet(item: $selectedExercise) { exercise in
            ZStack(alignment: .topTrailing) {
                if let session = sessionForExercise(exercise) {
                    WorkoutSessionScreen(session: session)
                        .background(Color.clear)
                }

                Button(action: { selectedExercise = nil }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(.white.opacity(0.8))
                        .background(Circle().fill(.black.opacity(0.2)).padding(2))
                }
                .padding(.top, 20)
                .padding(.trailing, 20)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(.ultraThinMaterial)
            .presentationCornerRadius(30)
            .animation(.spring(), value: selectedExercise?.id)
        }
        .animation(.easeInOut(duration: 0.25), value: selectedExercise?.id)
        .onAppear { configureSegmentedAppearance() }
    }

    private func handleExerciseSelection(_ exercise: GymExercise) {
        // إذا في تمرين شغّال بالفعل، رجّع نفس الجلسة بدل ما نفتح تمرين جديد.
        if let session = activeSession, session.phase != .idle, let existingExercise = activeExercise {
            selectedExercise = existingExercise
            return
        }

        activeExercise = exercise
        activeSession = LiveWorkoutSession(
            title: exercise.title,
            activityType: exercise.type,
            locationType: exercise.location,
            coachingProfile: exercise.coachingProfile
        )
        selectedExercise = exercise
    }

    private func sessionForExercise(_ exercise: GymExercise) -> LiveWorkoutSession? {
        if let session = activeSession, let existingExercise = activeExercise, existingExercise == exercise {
            return session
        }

        // fallback آمن إذا صار تقديم الشيت قبل إنشاء الجلسة.
        activeExercise = exercise
        let session = LiveWorkoutSession(
            title: exercise.title,
            activityType: exercise.type,
            locationType: exercise.location,
            coachingProfile: exercise.coachingProfile
        )
        activeSession = session
        return session
    }

    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            Text(L10n.t("screen.gym.title"))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            Spacer()

            // ✅ بدل أيقونة البروفايل: كرة القدم
            FootballHeaderButton {
                showFootballSheet = true
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Segmented Appearance
private func configureSegmentedAppearance() {
    let appearance = UISegmentedControl.appearance()
    appearance.selectedSegmentTintColor = UIColor.systemBackground
    appearance.setTitleTextAttributes([.foregroundColor: UIColor.systemYellow], for: .selected)
    appearance.setTitleTextAttributes([.foregroundColor: UIColor.black], for: .normal)
}

// MARK: - Tab Content View
struct TabContentView: View {
    let selectedTab: GymTab
    @ObservedObject var questsStore: QuestDailyStore
    @ObservedObject var winsStore: WinsStore
    var onSelectExercise: (GymExercise) -> Void

    var body: some View {
        ZStack {
            switch selectedTab {
            case .body:
                ExercisesView { exercise in
                    onSelectExercise(exercise)
                }
                .transition(.opacity)

            case .vitals:
                QuestsView(questsStore: questsStore)
                    .transition(.opacity)

            case .plan:
                MyPlanView().transition(.opacity)

            case .wins:
                QuestWinsGridView(winsStore: winsStore)
                    .transition(.opacity)

            case .recap:
                RecapView().transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: selectedTab)
    }
}

// MARK: - Glass Bubble Tab Bar
struct GlassBubbleTabBar: View {
    @Binding var selectedTab: GymTab
    var animation: Namespace.ID

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 27, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 27, style: .continuous)
                        .fill(GymTheme.mint.opacity(GymTheme.glassAlpha))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 27, style: .continuous)
                        .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)

            HStack(spacing: 4) {
                ForEach(GymTab.allCases) { tab in
                    GlassTabButton(tab: tab, isSelected: selectedTab == tab, animation: animation) {
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) { selectedTab = tab }
                    }
                }
            }
            .padding(4)
        }
        .frame(height: 54)
        .sensoryFeedback(.selection, trigger: selectedTab)
    }
}

struct GlassTabButton: View {
    let tab: GymTab
    let isSelected: Bool
    var animation: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(GymTheme.beige.opacity(0.35)))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.10)))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.20), lineWidth: 0.5))
                        .matchedGeometryEffect(id: "bubble", in: animation)
                }
                Text(tab.title)
                    .font(.system(size: 14, weight: isSelected ? .heavy : .bold))
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 46)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ✅ Football Header Button
struct FootballHeaderButton: View {
    let action: () -> Void
    @State private var isPressed = false
    @State private var feedbackTrigger = 0

    var body: some View {
        Button(action: {
            feedbackTrigger += 1
            action()
        }) {
            Image("football")               // ✅ اسم الصورة بالـ Assets: football
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.92 : 1.0)
        .animation(.snappy(duration: 0.12), value: isPressed)
        .sensoryFeedback(.selection, trigger: feedbackTrigger)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}


#Preview {
    GymView()
}
