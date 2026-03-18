import SwiftUI
import SwiftData
import Supabase
import Auth
import HealthKit
internal import Combine

private enum OnboardingKeys {
    static let didCompleteLegacyCalculation = "didCompleteLegacyCalculation"
    static let didShowFirstAuthScreen = "didShowFirstAuthScreen"
    static let didCompleteDatingProfile = "didCompleteDatingProfile"
}

@MainActor
final class AppFlowController: ObservableObject {
    static let shared = AppFlowController()

    enum RootScreen {
        case login
        case dating
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

    func didLoginSuccessfully() {
        UserDefaults.standard.set(true, forKey: OnboardingKeys.didShowFirstAuthScreen)
        transition(to: Self.nextScreenAfterLogin())
    }

    func didCompleteDatingProfile() {
        UserDefaults.standard.set(true, forKey: OnboardingKeys.didCompleteDatingProfile)
        transition(to: .legacy)
    }

    func onboardingFinished() {
        Task { @MainActor in
            // Request all remaining HealthKit permissions
            await requestFullHealthKitPermissions()

            // Request notification permission
            requestNotificationAuthorizationIfNeeded()

            await protectionModel.requestAuthorization()

            UserDefaults.standard.set(true, forKey: OnboardingKeys.didCompleteLegacyCalculation)
            MainTabRouter.shared.navigate(to: .home)
            transition(to: .main)
        }
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
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            currentScreen = screen
            refreshID = UUID()
        }
    }

    private static func resolveCurrentScreen() -> RootScreen {
        let didShowFirstAuthScreen = UserDefaults.standard.bool(forKey: OnboardingKeys.didShowFirstAuthScreen)
        let isLoggedIn = SupabaseService.shared.client.auth.currentUser != nil
        let didCompleteDatingProfile = UserDefaults.standard.bool(forKey: OnboardingKeys.didCompleteDatingProfile)
        let didCompleteLegacyCalculation = UserDefaults.standard.bool(forKey: OnboardingKeys.didCompleteLegacyCalculation)

        guard didShowFirstAuthScreen else { return .login }
        guard isLoggedIn else { return .login }

        if !didCompleteDatingProfile {
            return .dating
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
            return .dating
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

    var body: some View {
        ZStack {
            rootScreen
                .id(flow.refreshID)
        }
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
        case .login:
            LoginScreenView()
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
        case .dating:
            DatingScreenView()
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
        case .legacy:
            LegacyCalculationScreenView()
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
        case .main:
            MainTabScreen()
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
        }
    }
}
