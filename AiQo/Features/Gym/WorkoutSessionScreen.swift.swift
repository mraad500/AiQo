//
//  WorkoutSessionScreen.swift
//  Final Version: Optimized for Sheet & Scroll
//

import SwiftUI
import HealthKit

// MARK: - Main Screen
struct WorkoutSessionScreen: View {
    
    @ObservedObject var session: LiveWorkoutSession
    
    @State private var showSummary = false
    @State private var showActiveRecovery = false
    @State private var showSpotifyLibrary = false
    @State private var summaryData: (
        duration: TimeInterval,
        calories: Double,
        avgHeartRate: Double,
        recovery1: Int?,
        recovery2: Int?
    )?
    @State private var activeRecoveryContext: ActiveRecoveryContext?
    @State private var pendingRecoveryResult: PendingRecoveryResult?
    @State private var pendingCoachingSummary: WorkoutCoachingSummary?
    @State private var pendingEndWorkoutSnapshot: WorkoutCompletionSnapshot?

    var body: some View {
        ZStack {
            // الخلفية (ثابتة)
            StarryBackground()
            
            // 🔥 استخدمنا GeometryReader لضبط التخطيط
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    
                    // 1. منطقة المحتوى القابلة للتمرير (ScrollView)
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 20) {
                            
                            // --- Header ---
                            Text(session.title.uppercased())
                                .font(.system(.headline, design: .rounded).weight(.heavy))
                                .foregroundStyle(WorkoutTheme.pastelBeige)
                                .italic()
                                .padding(.top, 40) // مسافة علوية مناسبة للكارت
                            
                            // --- Timer ---
                            Text(formatTime(session.elapsedSeconds))
                                .font(.system(size: 54, weight: .black, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.black)
                                .frame(height: 65)
                                .padding(.horizontal, 40)
                                .background(
                                    Capsule()
                                        .fill(WorkoutTheme.pastelBeige)
                                        .shadow(color: WorkoutTheme.pastelBeige.opacity(0.4), radius: 20, x: 0, y: 0)
                                )

                            if session.isZone2GuidedWorkout {
                                Zone2AuraCard(
                                    auraState: session.zone2AuraState,
                                    rangeLabel: session.zone2RangeLabel,
                                    warmupRemainingSeconds: session.zone2WarmupRemainingSeconds,
                                    heartRate: session.heartRate
                                )
                                .padding(.horizontal, 20)
                            }
                            
                            // --- Stats Grid ---
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                                StatCard(
                                    title: "HEART RATE", value: "\(Int(session.heartRate))", unit: "BPM", icon: "heart.fill", color: WorkoutTheme.pastelBeige, textColor: .black, shouldPulse: session.phase == .running
                                )
                                StatCard(
                                    title: "CALORIES", value: "\(Int(session.activeEnergy))", unit: "KCAL", icon: "flame.fill", color: WorkoutTheme.pastelBeige, textColor: .black, shouldPulse: false
                                )
                                StatCard(
                                    title: "DISTANCE", value: formatDist(session.distanceMeters).val, unit: formatDist(session.distanceMeters).unit, icon: "figure.run", color: WorkoutTheme.pastelMint, textColor: .black, shouldPulse: false
                                )
                                StatCard(
                                    title: "STATUS", value: session.statusText, unit: "LIVE", icon: "waveform.path.ecg", color: WorkoutTheme.pastelMint, textColor: .black, shouldPulse: session.phase == .running
                                )
                            }
                            .padding(.horizontal, 20)
                            
                            // --- Music / Spotify Section ---
                            SpotifyWorkoutPlayerView {
                                showSpotifyLibrary = true
                            }
                                .padding(.horizontal, 20)
                                .padding(.top, 10)
                            
                            // 🔥 مسافة فارغة في النهاية حتى لا يغطي الزر المحتوى عند السكرول
                            Spacer().frame(height: 110)
                        }
                    }
                    
                    // 2. منطقة التحكم (مثبتة بالأسفل)
                    VStack {
                        HStack(spacing: 15) {
                            Button(action: {
                                withAnimation {
                                    if session.phase == .running {
                                        session.pauseFromPhone()
                                    } else if session.phase == .paused {
                                        session.resumeFromPhone()
                                    } else if session.phase == .idle {
                                        session.startFromPhone()
                                    }
                                }
                            }) {
                                HStack {
                                    Image(systemName: primaryControlIcon)
                                    Text(primaryControlTitle)
                                }
                                .font(.system(.title3, design: .rounded).weight(.bold))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 65)
                                .background(WorkoutTheme.pastelMint)
                                .clipShape(Capsule())
                                .shadow(color: WorkoutTheme.pastelMint.opacity(0.3), radius: 10)
                            }
                            .disabled(session.phase == .starting || session.phase == .ending || session.isControlPending)
                            
                            if session.canEnd {
                                Button(action: { endWorkout() }) {
                                    Image(systemName: "stop.fill")
                                        .font(.title2)
                                        .foregroundStyle(.white)
                                        .frame(width: 65, height: 65)
                                        .background(Color(red: 1.0, green: 0.35, blue: 0.40))
                                        .clipShape(Circle())
                                }
                                .disabled(session.isControlPending)
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(.horizontal, 30)
                        .padding(.bottom, 30) // مسافة من حافة الشاشة
                        .padding(.top, 15)
                    }
                    .background(
                        // تدرج لوني خلف الأزرار لدمجها مع الخلفية
                        LinearGradient(
                            colors: [Color.black.opacity(0), Color.black.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .ignoresSafeArea()
                    )
                }
            }
            
            // Milestone Alert (فوق كل شيء)
            if session.showMilestoneAlert {
                VStack {
                    Text(session.milestoneAlertText)
                        .font(.system(.title, design: .rounded).weight(.heavy))
                        .foregroundStyle(.white)
                        .padding()
                        .background(WorkoutTheme.pastelMint.opacity(0.9))
                        .clipShape(Capsule())
                        .shadow(radius: 10)
                        .transition(.move(edge: .top))
                    Spacer()
                }
                .padding(.top, 60)
                .zIndex(100)
            }

            if let recoveryPromptSnapshot = pendingEndWorkoutSnapshot {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(105)

                OptionalRecoveryPromptCard(
                    onConfirm: {
                        beginActiveRecovery(using: recoveryPromptSnapshot)
                    },
                    onSkip: {
                        let snapshot = recoveryPromptSnapshot
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                            pendingEndWorkoutSnapshot = nil
                        }
                        bypassRecoveryAndFinishWorkout(using: snapshot)
                    }
                )
                .padding(.horizontal, 24)
                .zIndex(110)
                .transition(.scale(scale: 0.94).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showSpotifyLibrary) {
            SpotifyVibesLibrarySheet(playlistID: "37i9dQZF1DX4sWSpwq3LiO")
                .presentationDetents([.fraction(0.6), .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
        }
        .fullScreenCover(isPresented: $showSummary) {
            if let data = summaryData {
                PhoneWorkoutSummaryView(
                    duration: data.duration,
                    calories: data.calories,
                    avgHeartRate: data.avgHeartRate,
                    heartRateSamples: [],
                    recovery1: data.recovery1,
                    recovery2: data.recovery2,
                    onDismiss: { showSummary = false }
                )
            }
        }
        .fullScreenCover(isPresented: $showActiveRecovery) {
            Group {
                if let context = activeRecoveryContext {
                    ActiveRecoveryView(
                        session: session,
                        peakHeartRate: context.peakHeartRate
                    ) { recovery1, recovery2 in
                        pendingRecoveryResult = PendingRecoveryResult(
                            snapshot: context.snapshot,
                            recovery1: recovery1,
                            recovery2: recovery2
                        )
                        showActiveRecovery = false
                        activeRecoveryContext = nil
                    }
                } else {
                    Color.clear
                }
            }
        }
        .onChange(of: showActiveRecovery) { _, isPresented in
            guard !isPresented, let pendingRecoveryResult else { return }
            self.pendingRecoveryResult = nil
            DispatchQueue.main.async {
                completeWorkout(
                    snapshot: pendingRecoveryResult.snapshot,
                    recovery1: pendingRecoveryResult.recovery1,
                    recovery2: pendingRecoveryResult.recovery2
                )
            }
        }
        .onChange(of: session.phase) { _, newPhase in
            guard newPhase == .idle else { return }
            guard summaryData != nil, !showSummary else { return }

            if let pendingCoachingSummary {
                let summary = pendingCoachingSummary
                self.pendingCoachingSummary = nil
                Task {
                    await CaptainSmartNotificationService.shared.handleWorkoutCompleted(summary: summary)
                }
            }

            showSummary = true
        }
    }
    
    // MARK: - Helpers
    private func formatTime(_ totalSeconds: Int) -> String {
        let h = totalSeconds / 3600
        let m = (totalSeconds % 3600) / 60
        let s = totalSeconds % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        else { return String(format: "%02d:%02d", m, s) }
    }
    
    private func formatDist(_ m: Double) -> (val: String, unit: String) {
        if m >= 1000 { return (String(format: "%.2f", m/1000), "KM") }
        return ("\(Int(m))", "M")
    }
    
    private func endWorkout() {
        let snapshot = buildWorkoutCompletionSnapshot()

        if isCaptainHamoudiCardioWorkout {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
                pendingEndWorkoutSnapshot = snapshot
            }
            return
        }

        completeWorkout(snapshot: snapshot, recovery1: nil, recovery2: nil)
    }

    private func buildWorkoutCompletionSnapshot() -> WorkoutCompletionSnapshot {
        let finalDuration = TimeInterval(session.elapsedSeconds)
        let finalCalories = session.activeEnergy
        let finalAvgHR = session.heartRate
        let finalDistance = session.distanceMeters
        let estimatedSteps = max(Int((finalDistance / 1000.0) * 1300.0), 0)
        return WorkoutCompletionSnapshot(
            duration: finalDuration,
            calories: finalCalories,
            avgHeartRate: finalAvgHR,
            distanceMeters: finalDistance,
            estimatedSteps: estimatedSteps,
            workoutTitle: session.title
        )
    }

    private func beginActiveRecovery(using snapshot: WorkoutCompletionSnapshot) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
            pendingEndWorkoutSnapshot = nil
        }

        activeRecoveryContext = ActiveRecoveryContext(
            snapshot: snapshot,
            peakHeartRate: snapshot.avgHeartRate
        )
        showActiveRecovery = true
    }

    private func bypassRecoveryAndFinishWorkout(using snapshot: WorkoutCompletionSnapshot) {
        summaryData = (
            duration: snapshot.duration,
            calories: snapshot.calories,
            avgHeartRate: snapshot.avgHeartRate,
            recovery1: nil,
            recovery2: nil
        )

        pendingCoachingSummary = WorkoutCoachingSummary(
            duration: snapshot.duration,
            calories: snapshot.calories,
            averageHeartRate: snapshot.avgHeartRate,
            distanceMeters: snapshot.distanceMeters,
            estimatedSteps: snapshot.estimatedSteps,
            workoutType: snapshot.workoutTitle
        )

        session.forceEndFromPhoneImmediately()
        showSummary = true
    }

    private func completeWorkout(
        snapshot: WorkoutCompletionSnapshot,
        recovery1: Int?,
        recovery2: Int?
    ) {
        summaryData = (
            duration: snapshot.duration,
            calories: snapshot.calories,
            avgHeartRate: snapshot.avgHeartRate,
            recovery1: recovery1,
            recovery2: recovery2
        )

        session.endFromPhone()
        pendingCoachingSummary = WorkoutCoachingSummary(
            duration: snapshot.duration,
            calories: snapshot.calories,
            averageHeartRate: snapshot.avgHeartRate,
            distanceMeters: snapshot.distanceMeters,
            estimatedSteps: snapshot.estimatedSteps,
            workoutType: snapshot.workoutTitle
        )
    }

    private var isCaptainHamoudiCardioWorkout: Bool {
        session.currentWorkout == .cardioWithCaptainHamoudi
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
            return "Pause Workout"
        case .paused:
            return "Resume"
        case .idle:
            return "Start Workout"
        case .starting:
            return "Connecting..."
        case .ending:
            return "Ending..."
        }
    }
}

private struct WorkoutCompletionSnapshot {
    let duration: TimeInterval
    let calories: Double
    let avgHeartRate: Double
    let distanceMeters: Double
    let estimatedSteps: Int
    let workoutTitle: String
}

private struct ActiveRecoveryContext {
    let snapshot: WorkoutCompletionSnapshot
    let peakHeartRate: Double
}

private struct PendingRecoveryResult {
    let snapshot: WorkoutCompletionSnapshot
    let recovery1: Int
    let recovery2: Int
}

private struct OptionalRecoveryPromptCard: View {
    let onConfirm: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                WorkoutTheme.pastelMint.opacity(0.45),
                                WorkoutTheme.pastelBeige.opacity(0.18)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 72, height: 72)
                    .blur(radius: 6)

                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white.opacity(0.92))
            }

            VStack(spacing: 10) {
                Text("قياس تعافي النبض")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("تعافي معدل ضربات القلب: هو سرعة نزول نبض القلب بعد التمرين. إذا نزل بسرعة خلال أول دقيقتين، فهذا دليل على صحة قلب ولياقة أفضل.")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.86))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            HStack(spacing: 12) {
                Button(action: onConfirm) {
                    Text("نعم")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(WorkoutTheme.pastelMint)
                        .clipShape(Capsule())
                }

                Button(action: onSkip) {
                    Text("لا شكراً")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.14), lineWidth: 1)
                        )
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 26)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(.ultraThinMaterial)

                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.16),
                                Color.white.opacity(0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            }
        )
        .shadow(color: .black.opacity(0.35), radius: 28, x: 0, y: 18)
    }
}

// MARK: - Components (Cards & Wheel)

struct StatCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    let textColor: Color
    let shouldPulse: Bool
    
    @State private var pulseScale: CGFloat = 1.0
    @State private var floatOffsetY: CGFloat = 0.0
    @State private var tapScale: CGFloat = 1.0
    @State private var tapRotation: Double = 0.0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(Color.red.opacity(0.8))
                Spacer()
                Text(unit)
                    .font(.caption)
                    .fontWeight(.bold)
                    .opacity(0.6)
            }
            Text(value)
                .font(.system(size: 32, weight: .black, design: .rounded))
                .minimumScaleFactor(0.8)
                .lineLimit(1)
            Text(title)
                .font(.caption)
                .fontWeight(.bold)
                .opacity(0.8)
        }
        .foregroundColor(textColor)
        .padding(20)
        .frame(height: 130)
        .background(color)
        .cornerRadius(24)
        .offset(y: floatOffsetY)
        .scaleEffect(tapScale * (shouldPulse ? pulseScale : 1.0))
        .rotation3DEffect(.degrees(tapRotation), axis: (x: 1, y: 0, z: 0))
        .onAppear {
            if shouldPulse {
                withAnimation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    pulseScale = 1.02
                }
            }
            startFloatingAnimation()
        }
        .onTapGesture {
            triggerWaveAnimation()
        }
    }
    
    private func startFloatingAnimation() {
        let randomDelay = Double.random(in: 0...2.0)
        let randomDuration = Double.random(in: 4.0...6.0)
        withAnimation(Animation.easeInOut(duration: randomDuration).repeatForever(autoreverses: true).delay(randomDelay)) {
            floatOffsetY = -6.0
        }
    }
    
    private func triggerWaveAnimation() {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0)) {
            tapScale = 0.92
            tapRotation = 8.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.4, blendDuration: 0)) {
                tapScale = 1.0
                tapRotation = 0.0
            }
        }
    }
}

struct Zone2AuraCard: View {
    let auraState: LiveWorkoutSession.Zone2AuraState
    let rangeLabel: String
    let warmupRemainingSeconds: Int
    let heartRate: Double

    @State private var pulse = false

    private var titleText: String {
        switch auraState {
        case .inactive:
            return L10n.t("gym.zone2.state.inactive")
        case .warmingUp:
            return L10n.t("gym.zone2.state.warming_up")
        case .inZone2:
            return L10n.t("gym.zone2.state.in_zone")
        case .tooFast:
            return L10n.t("gym.zone2.state.too_fast")
        case .tooSlow:
            return L10n.t("gym.zone2.state.too_slow")
        }
    }

    private var iconName: String {
        switch auraState {
        case .inactive: return "waveform.path.ecg"
        case .warmingUp: return "figure.walk"
        case .inZone2: return "checkmark.seal.fill"
        case .tooFast: return "hare.fill"
        case .tooSlow: return "tortoise.fill"
        }
    }

    private var auraColors: [Color] {
        switch auraState {
        case .inactive:
            return [Color.gray.opacity(0.35), Color.gray.opacity(0.15)]
        case .warmingUp:
            return [Color.orange.opacity(0.85), Color.yellow.opacity(0.45)]
        case .inZone2:
            return [Color.green.opacity(0.85), Color.mint.opacity(0.45)]
        case .tooFast:
            return [Color.red.opacity(0.85), Color.orange.opacity(0.45)]
        case .tooSlow:
            return [Color.blue.opacity(0.85), Color.cyan.opacity(0.45)]
        }
    }

    private var pulseDuration: Double {
        switch auraState {
        case .inactive: return 2.2
        case .warmingUp: return 1.9
        case .inZone2: return 1.5
        case .tooFast: return 0.8
        case .tooSlow: return 1.1
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)

                Text(L10n.t("gym.zone2.card.title"))
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(Int(heartRate.rounded())) BPM")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(.white.opacity(0.88))
            }

            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(auraColors[1])
                        .frame(width: 70, height: 70)
                        .scaleEffect(pulse ? 1.20 : 0.80)

                    Circle()
                        .stroke(auraColors[0], lineWidth: 2.0)
                        .frame(width: 54, height: 54)
                        .scaleEffect(pulse ? 1.10 : 0.86)

                    Circle()
                        .fill(auraColors[0])
                        .frame(width: 22, height: 22)
                        .shadow(color: auraColors[0], radius: 14, x: 0, y: 0)
                }
                .frame(width: 70, height: 70)

                VStack(alignment: .leading, spacing: 6) {
                    Text(titleText)
                        .font(.system(.title3, design: .rounded).weight(.heavy))
                        .foregroundStyle(.white)

                    Text(String(format: L10n.t("gym.zone2.target"), rangeLabel))
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.white.opacity(0.86))

                    if auraState == .warmingUp {
                        Text(String(format: L10n.t("gym.zone2.warmup_remaining"), formatTime(warmupRemainingSeconds)))
                            .font(.system(.footnote, design: .rounded).weight(.semibold))
                            .foregroundStyle(.white.opacity(0.78))
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.black.opacity(0.62), auraColors[0].opacity(0.35)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                )
        )
        .onAppear {
            restartPulseAnimation()
        }
        .onChange(of: auraState) { _, _ in
            restartPulseAnimation()
        }
    }

    private func restartPulseAnimation() {
        pulse = false
        withAnimation(.easeInOut(duration: pulseDuration).repeatForever(autoreverses: true)) {
            pulse = true
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remaining = seconds % 60
        return String(format: "%02d:%02d", minutes, remaining)
    }
}
