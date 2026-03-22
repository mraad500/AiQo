import SwiftUI
import SwiftData
import Supabase
import Auth
import HealthKit
import Combine

private enum OnboardingKeys {
    static let didCompleteLegacyCalculation = "didCompleteLegacyCalculation"
    static let didShowFirstAuthScreen = "didShowFirstAuthScreen"
    static let didCompleteDatingProfile = "didCompleteDatingProfile"
    static let didCompleteWalkthrough = "didCompleteWalkthrough"
    static let didSelectLanguage = "didSelectLanguage"
}

@MainActor
final class AppFlowController: ObservableObject {
    static let shared = AppFlowController()

    enum RootScreen {
        case languageSelection
        case welcome
        case login
        case profileSetup
        case legacy
        case main
    }

    @Published private(set) var currentScreen: RootScreen
    @Published private(set) var refreshID = UUID()

    private let protectionModel = ProtectionModel.shared

    private init() {
        QuestPersistenceController.shared.installQuestPersistence()
        currentScreen = Self.resolveCurrentScreen()
    }

    func didSelectLanguage() {
        UserDefaults.standard.set(true, forKey: OnboardingKeys.didSelectLanguage)
        transition(to: .welcome)
    }

    func didCompleteWalkthrough() {
        UserDefaults.standard.set(true, forKey: OnboardingKeys.didCompleteWalkthrough)
        transition(to: .login)
    }

    func didLoginSuccessfully() {
        UserDefaults.standard.set(true, forKey: OnboardingKeys.didShowFirstAuthScreen)
        transition(to: Self.nextScreenAfterLogin())
    }

    func didCompleteProfileSetup() {
        UserDefaults.standard.set(true, forKey: OnboardingKeys.didCompleteDatingProfile)
        transition(to: .legacy)
    }

    func didCompleteDatingProfile() {
        didCompleteProfileSetup()
    }

    func finishOnboardingWithoutAdditionalPermissions() {
        Task { @MainActor in
            // User chose to skip — don't prompt for FamilyControls or HealthKit permissions
            finalizeOnboarding()
        }
    }

    func finishOnboardingRequestingPermissions() {
        Task { @MainActor in
            await requestFullHealthKitPermissions()
            requestNotificationAuthorizationIfNeeded()
            await protectionModel.requestAuthorization()
            finalizeOnboarding()
        }
    }

    func onboardingFinished() {
        finishOnboardingRequestingPermissions()
    }

    private func finalizeOnboarding() {
            UserDefaults.standard.set(true, forKey: OnboardingKeys.didCompleteLegacyCalculation)
            FreeTrialManager.shared.startTrialIfNeeded()
            MainTabRouter.shared.navigate(to: .home)
            transition(to: .main)
    }

    private func requestFullHealthKitPermissions() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let healthStore = HKHealthStore()

        let allReadTypes: Set<HKObjectType> = [
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.distanceCycling),
            HKQuantityType(.heartRate),
            HKQuantityType(.heartRateVariabilitySDNN),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.walkingHeartRateAverage),
            HKQuantityType(.oxygenSaturation),
            HKQuantityType(.vo2Max),
            HKQuantityType(.bodyMass),
            HKQuantityType(.dietaryWater),
            HKQuantityType(.appleStandTime),
            HKCategoryType(.sleepAnalysis),
            HKObjectType.activitySummaryType(),
            HKObjectType.workoutType()
        ]

        let allWriteTypes: Set<HKSampleType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.heartRateVariabilitySDNN),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.vo2Max),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.dietaryWater),
            HKQuantityType(.bodyMass),
            HKObjectType.workoutType()
        ]

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            healthStore.requestAuthorization(toShare: allWriteTypes, read: allReadTypes) { _, _ in
                continuation.resume()
            }
        }
    }

    func logout() {
        Task { @MainActor in
            try? await SupabaseService.shared.client.auth.signOut()

            UserDefaults.standard.set(false, forKey: OnboardingKeys.didCompleteLegacyCalculation)
            UserDefaults.standard.set(false, forKey: OnboardingKeys.didCompleteDatingProfile)
            UserDefaults.standard.set(false, forKey: OnboardingKeys.didShowFirstAuthScreen)

            MainTabRouter.shared.navigate(to: .home)
            transition(to: .login)
        }
    }

    func reloadCurrentScreen() {
        currentScreen = Self.resolveCurrentScreen()
        refreshID = UUID()
    }

    private func transition(to screen: RootScreen) {
        withAnimation(.easeInOut(duration: 0.4)) {
            currentScreen = screen
            refreshID = UUID()
        }
    }

    private static func resolveCurrentScreen() -> RootScreen {
        let didSelectLanguage = UserDefaults.standard.bool(forKey: OnboardingKeys.didSelectLanguage)
        let didCompleteWalkthrough = UserDefaults.standard.bool(forKey: OnboardingKeys.didCompleteWalkthrough)
        let didShowFirstAuthScreen = UserDefaults.standard.bool(forKey: OnboardingKeys.didShowFirstAuthScreen)
        let didCompleteDatingProfile = UserDefaults.standard.bool(forKey: OnboardingKeys.didCompleteDatingProfile)
        let didCompleteLegacyCalculation = UserDefaults.standard.bool(forKey: OnboardingKeys.didCompleteLegacyCalculation)

        // Check Supabase session — attempt to recover expired sessions before falling back to login
        let isLoggedIn: Bool = {
            if SupabaseService.shared.client.auth.currentUser != nil { return true }
            // If user completed full onboarding but session expired, let them through
            // to main screen. Supabase will refresh the token on next API call.
            if didCompleteLegacyCalculation && didCompleteDatingProfile && didShowFirstAuthScreen {
                return true
            }
            return false
        }()

        guard didSelectLanguage else { return .languageSelection }
        guard didCompleteWalkthrough else { return .welcome }
        guard didShowFirstAuthScreen else { return .login }
        guard isLoggedIn else { return .login }

        if !didCompleteDatingProfile {
            return .profileSetup
        }

        if !didCompleteLegacyCalculation {
            return .legacy
        }

        return .main
    }

    private static func nextScreenAfterLogin() -> RootScreen {
        let didCompleteDatingProfile = UserDefaults.standard.bool(forKey: OnboardingKeys.didCompleteDatingProfile)
        let didCompleteLegacyCalculation = UserDefaults.standard.bool(forKey: OnboardingKeys.didCompleteLegacyCalculation)

        if !didCompleteDatingProfile {
            return .profileSetup
        }

        if !didCompleteLegacyCalculation {
            return .legacy
        }

        return .main
    }

    private func requestNotificationAuthorizationIfNeeded() {
        NotificationService.shared.requestPermissions()
    }
}

struct AppRootView: View {
    @StateObject private var flow = AppFlowController.shared
    @EnvironmentObject private var globalBrain: CaptainViewModel
    @Environment(\.scenePhase) private var scenePhase

    private var currentDirection: LayoutDirection {
        AppSettingsStore.shared.appLanguage == .arabic ? .rightToLeft : .leftToRight
    }

    var body: some View {
        ZStack {
            rootScreen
                .id(flow.refreshID)
        }
        .environment(\.layoutDirection, currentDirection)
        .environment(\.locale, Locale(identifier: AppSettingsStore.shared.appLanguage.rawValue))
        .withOfflineBanner()
        .animation(.easeInOut(duration: 0.4), value: flow.currentScreen)
        .modelContainer(QuestPersistenceController.shared.container)
        .onReceive(NotificationCenter.default.publisher(for: .appLanguageDidChange)) { _ in
            flow.reloadCurrentScreen()
        }
        .onChange(of: scenePhase) { _, newPhase in
            globalBrain.handleScenePhaseTransition(newPhase)
        }
    }

    @ViewBuilder
    private var rootScreen: some View {
        switch flow.currentScreen {
        case .languageSelection:
            LanguageSelectionView {
                flow.didSelectLanguage()
            }
            .transition(.asymmetric(insertion: .opacity, removal: .move(edge: .leading)))
        case .welcome:
            OnboardingWalkthroughView {
                flow.didCompleteWalkthrough()
            }
            .transition(.asymmetric(insertion: .opacity, removal: .move(edge: .leading)))
        case .login:
            LoginScreenView()
                .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing)))
        case .profileSetup:
            ProfileSetupView()
                .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing)))
        case .legacy:
            LegacyCalculationScreenView()
                .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing)))
        case .main:
            MainTabScreen()
                .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing)))
        }
    }
}
