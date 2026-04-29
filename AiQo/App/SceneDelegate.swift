import SwiftUI
import SwiftData
import Supabase
import Auth
import HealthKit
import Combine

enum OnboardingKeys {
    static let didCompleteLegacyCalculation = "didCompleteLegacyCalculation"
    static let didCompleteCaptainPersonalization = "didCompleteCaptainPersonalization"
    static let didCompleteFeatureIntro = "didCompleteFeatureIntro"
    static let didShowFirstAuthScreen = "didShowFirstAuthScreen"
    static let didContinueWithoutAccount = "didContinueWithoutAccount"
    static let didCompleteDatingProfile = "didCompleteDatingProfile"
    static let didSelectLanguage = "didSelectLanguage"
    static let didCompleteAIConsent = "didCompleteAIConsent"
    static let didAcknowledgeMedicalDisclaimer = "didAcknowledgeMedicalDisclaimer"
    static let didCompleteHealthScreening = "didCompleteHealthScreening"
    static let didCompleteQuickStart = "didCompleteQuickStart"
    static let didCompleteSubscriptionIntro = "didCompleteSubscriptionIntro"
}

@MainActor
final class AppFlowController: ObservableObject {
    static let shared = AppFlowController()

    enum RootScreen {
        case languageSelection
        case login
        case profileSetup
        case legacy
        case aiConsent
        case medicalDisclaimer
        case quickStart
        case featureIntro
        case subscriptionIntro
        case main
    }

    @Published private(set) var currentScreen: RootScreen
    @Published private(set) var refreshID = UUID()

    private init() {
        // Migration: existing users who already completed featureIntro before
        // the subscriptionIntro step existed should not be re-prompted with the
        // paywall on app upgrade.
        let didCompleteFeatureIntro = UserDefaults.standard.bool(forKey: OnboardingKeys.didCompleteFeatureIntro)
        let hasSubscriptionIntroKey = UserDefaults.standard.object(forKey: OnboardingKeys.didCompleteSubscriptionIntro) != nil
        if didCompleteFeatureIntro && !hasSubscriptionIntroKey {
            UserDefaults.standard.set(true, forKey: OnboardingKeys.didCompleteSubscriptionIntro)
        }

        Task { @MainActor in
            await Task.yield()
            QuestPersistenceController.shared.installQuestPersistence()
        }
        currentScreen = Self.resolveCurrentScreen()
    }

    func didSelectLanguage() {
        UserDefaults.standard.set(true, forKey: OnboardingKeys.didSelectLanguage)
        transition(to: .login)
    }

    func didLoginSuccessfully() {
        UserDefaults.standard.set(true, forKey: OnboardingKeys.didShowFirstAuthScreen)
        UserDefaults.standard.set(false, forKey: OnboardingKeys.didContinueWithoutAccount)
        if let userID = SupabaseService.shared.currentUserID {
            CrashReportingService.shared.setUser(id: userID)
        }
        transition(to: Self.nextScreenAfterLogin())
    }

    func didContinueWithoutAccount() {
        UserDefaults.standard.set(true, forKey: OnboardingKeys.didShowFirstAuthScreen)
        UserDefaults.standard.set(true, forKey: OnboardingKeys.didContinueWithoutAccount)
        CrashReportingService.shared.clearUser()
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
            // User chose to skip — don't prompt for optional onboarding permissions
            finalizeLegacyStep()
        }
    }

    func finishOnboardingRequestingPermissions() {
        Task { @MainActor in
            HealthKitService.permissionFlowEnabled = true
            await requestFullHealthKitPermissions()
            requestNotificationAuthorizationIfNeeded()
            finalizeLegacyStep()

            // Start HealthKit-dependent services now that onboarding is complete
            // and permissions have been granted (deferred from AppDelegate for new users).
            UIApplication.shared.registerForRemoteNotifications()
            MorningHabitOrchestrator.shared.start()
            SleepSessionObserver.shared.start()
            Task {
                await AIWorkoutSummaryService.shared.startMonitoringWorkoutEnds()
            }
        }
    }

    func onboardingFinished() {
        finishOnboardingRequestingPermissions()
    }

    private func finalizeLegacyStep() {
        UserDefaults.standard.set(true, forKey: OnboardingKeys.didCompleteLegacyCalculation)
        FreeTrialManager.shared.startTrialIfNeeded()
        TrialJourneyOrchestrator.shared.refresh()
        transition(to: .aiConsent)
    }

    func finalizeAIConsent() {
        UserDefaults.standard.set(true, forKey: OnboardingKeys.didCompleteAIConsent)
        transition(to: .medicalDisclaimer)
    }

    func finalizeMedicalDisclaimer() {
        UserDefaults.standard.set(true, forKey: OnboardingKeys.didAcknowledgeMedicalDisclaimer)
        UserDefaults.standard.set(true, forKey: "aiqo.medicalDisclaimer.acknowledgedV1")
        transition(to: Self.resolveCurrentScreen())
    }

    func didCompleteQuickStart() {
        UserDefaults.standard.set(true, forKey: OnboardingKeys.didCompleteQuickStart)
        // Keep legacy flags in sync so any code that still reads them sees the
        // user as fully onboarded.
        UserDefaults.standard.set(true, forKey: OnboardingKeys.didCompleteHealthScreening)
        UserDefaults.standard.set(true, forKey: OnboardingKeys.didCompleteCaptainPersonalization)
        transition(to: .featureIntro)
    }

    func didCompleteFeatureIntro() {
        UserDefaults.standard.set(true, forKey: OnboardingKeys.didCompleteFeatureIntro)
        transition(to: .subscriptionIntro)
    }

    func didCompleteSubscriptionIntro() {
        UserDefaults.standard.set(true, forKey: OnboardingKeys.didCompleteSubscriptionIntro)
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
            CrashReportingService.shared.clearUser()

            UserDefaults.standard.set(false, forKey: OnboardingKeys.didCompleteLegacyCalculation)
            UserDefaults.standard.set(false, forKey: OnboardingKeys.didCompleteCaptainPersonalization)
            UserDefaults.standard.set(false, forKey: OnboardingKeys.didCompleteFeatureIntro)
            UserDefaults.standard.set(false, forKey: OnboardingKeys.didCompleteDatingProfile)
            UserDefaults.standard.set(false, forKey: OnboardingKeys.didShowFirstAuthScreen)
            UserDefaults.standard.set(false, forKey: OnboardingKeys.didContinueWithoutAccount)
            UserDefaults.standard.removeObject(forKey: OnboardingKeys.didCompleteAIConsent)
            UserDefaults.standard.removeObject(forKey: OnboardingKeys.didAcknowledgeMedicalDisclaimer)
            UserDefaults.standard.removeObject(forKey: OnboardingKeys.didCompleteHealthScreening)
            UserDefaults.standard.removeObject(forKey: OnboardingKeys.didCompleteQuickStart)
            UserDefaults.standard.removeObject(forKey: OnboardingKeys.didCompleteSubscriptionIntro)

            LearningProofStore.shared.deleteAllLocalData()
            HealthScreeningStore.clear()

            // Voice teardown: wipe synthesized-audio cache and delete the
            // MiniMax API key from Keychain so the next account doesn't
            // inherit cloud-voice credentials or cached replies from the
            // previous one.
            await VoiceCacheStore.shared.wipeAll()
            CaptainVoiceKeychain.deleteMiniMaxAPIKey()

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
        #if DEBUG
        if ScreenshotMode.isActive { return .main }
        #endif

        let didSelectLanguage = UserDefaults.standard.bool(forKey: OnboardingKeys.didSelectLanguage)
        let didShowFirstAuthScreen = UserDefaults.standard.bool(forKey: OnboardingKeys.didShowFirstAuthScreen)
        let didContinueWithoutAccount = UserDefaults.standard.bool(forKey: OnboardingKeys.didContinueWithoutAccount)
        let didCompleteDatingProfile = UserDefaults.standard.bool(forKey: OnboardingKeys.didCompleteDatingProfile)
        let didCompleteLegacyCalculation = UserDefaults.standard.bool(forKey: OnboardingKeys.didCompleteLegacyCalculation)
        let didCompleteFeatureIntro = UserDefaults.standard.bool(forKey: OnboardingKeys.didCompleteFeatureIntro)
        let didCompleteAIConsent = UserDefaults.standard.bool(forKey: OnboardingKeys.didCompleteAIConsent)
        let didAcknowledgeMedicalDisclaimer = UserDefaults.standard.bool(forKey: OnboardingKeys.didAcknowledgeMedicalDisclaimer)
        // Migration: legacy users who completed both old screens (or feature intro) are
        // considered done with the new unified quickStart screen.
        let didCompleteQuickStart = UserDefaults.standard.bool(forKey: OnboardingKeys.didCompleteQuickStart)
            || didCompleteFeatureIntro
            || (UserDefaults.standard.bool(forKey: OnboardingKeys.didCompleteHealthScreening)
                && UserDefaults.standard.bool(forKey: OnboardingKeys.didCompleteCaptainPersonalization))

        // Check Supabase session — attempt to recover expired sessions before falling back to login
        let isLoggedIn: Bool = {
            if SupabaseService.shared.client.auth.currentUser != nil { return true }
            if didContinueWithoutAccount { return true }
            // If user completed full onboarding but session expired, let them through
            // to main screen. Supabase will refresh the token on next API call.
            if didCompleteLegacyCalculation && didCompleteDatingProfile && didShowFirstAuthScreen {
                return true
            }
            return false
        }()

        guard didSelectLanguage else { return .languageSelection }
        guard didShowFirstAuthScreen else { return .login }
        guard isLoggedIn else { return .login }

        if !didCompleteDatingProfile {
            return .profileSetup
        }

        if !didCompleteLegacyCalculation {
            return .legacy
        }

        if !didCompleteAIConsent {
            return .aiConsent
        }

        if !didAcknowledgeMedicalDisclaimer {
            return .medicalDisclaimer
        }

        if !didCompleteQuickStart {
            return .quickStart
        }

        if !didCompleteFeatureIntro {
            return .featureIntro
        }

        let didCompleteSubscriptionIntro = UserDefaults.standard.bool(forKey: OnboardingKeys.didCompleteSubscriptionIntro)
        if !didCompleteSubscriptionIntro {
            return .subscriptionIntro
        }

        return .main
    }

    private static func nextScreenAfterLogin() -> RootScreen {
        let didCompleteDatingProfile = UserDefaults.standard.bool(forKey: OnboardingKeys.didCompleteDatingProfile)
        let didCompleteLegacyCalculation = UserDefaults.standard.bool(forKey: OnboardingKeys.didCompleteLegacyCalculation)
        let didCompleteFeatureIntro = UserDefaults.standard.bool(forKey: OnboardingKeys.didCompleteFeatureIntro)
        let didCompleteAIConsent = UserDefaults.standard.bool(forKey: OnboardingKeys.didCompleteAIConsent)
        let didAcknowledgeMedicalDisclaimer = UserDefaults.standard.bool(forKey: OnboardingKeys.didAcknowledgeMedicalDisclaimer)
        let didCompleteQuickStart = UserDefaults.standard.bool(forKey: OnboardingKeys.didCompleteQuickStart)
            || didCompleteFeatureIntro
            || (UserDefaults.standard.bool(forKey: OnboardingKeys.didCompleteHealthScreening)
                && UserDefaults.standard.bool(forKey: OnboardingKeys.didCompleteCaptainPersonalization))

        if !didCompleteDatingProfile {
            return .profileSetup
        }

        if !didCompleteLegacyCalculation {
            return .legacy
        }

        if !didCompleteAIConsent {
            return .aiConsent
        }

        if !didAcknowledgeMedicalDisclaimer {
            return .medicalDisclaimer
        }

        if !didCompleteQuickStart {
            return .quickStart
        }

        if !didCompleteFeatureIntro {
            return .featureIntro
        }

        let didCompleteSubscriptionIntro = UserDefaults.standard.bool(forKey: OnboardingKeys.didCompleteSubscriptionIntro)
        if !didCompleteSubscriptionIntro {
            return .subscriptionIntro
        }

        return .main
    }

    private func requestNotificationAuthorizationIfNeeded() {
        NotificationService.shared.requestPermissions()
    }
}

struct AppRootView: View {
    @StateObject private var flow = AppFlowController.shared
    @StateObject private var aiConsentManager = AIDataConsentManager.shared
    @EnvironmentObject private var globalBrain: CaptainViewModel
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("aiqo.medicalDisclaimer.acknowledgedV1") private var medicalDisclaimerV1Acknowledged = false

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
        .sheet(isPresented: $aiConsentManager.isPresentingConsentSheet) {
            AIDataConsentView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        .fullScreenCover(isPresented: medicalDisclaimerCoverBinding) {
            MedicalDisclaimerDetailView(mode: .firstRun)
        }
    }

    /// v1.1 gate: show the fullscreen disclaimer only once onboarding is fully
    /// complete AND the user has not yet acknowledged the v1.1 wording. This
    /// covers legacy users who completed v1.0 onboarding before the new gate
    /// existed. Non-dismissible by gesture until "فهمت وأوافق" is tapped.
    private var medicalDisclaimerCoverBinding: Binding<Bool> {
        Binding(
            get: { flow.currentScreen == .main && !medicalDisclaimerV1Acknowledged },
            set: { _ in }
        )
    }

    @ViewBuilder
    private var rootScreen: some View {
        switch flow.currentScreen {
        case .languageSelection:
            LanguageSelectionView {
                flow.didSelectLanguage()
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
        case .aiConsent:
            AIConsentOnboardingView(onContinue: { flow.finalizeAIConsent() })
                .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing)))
        case .medicalDisclaimer:
            MedicalDisclaimerOnboardingView(onAcknowledge: { flow.finalizeMedicalDisclaimer() })
                .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing)))
        case .quickStart:
            QuickStartOnboardingView(onContinue: { flow.didCompleteQuickStart() })
                .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing)))
        case .featureIntro:
            FeatureIntroView {
                flow.didCompleteFeatureIntro()
            }
            .transition(.asymmetric(insertion: .opacity, removal: .move(edge: .leading)))
        case .subscriptionIntro:
            SubscriptionIntroView {
                flow.didCompleteSubscriptionIntro()
            }
            .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing)))
        case .main:
            MainTabScreen()
                .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing)))
        }
    }
}
