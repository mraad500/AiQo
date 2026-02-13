//
//  WorkoutSessionScreen.swift
//  Final Version: Optimized for Sheet & Scroll
//

import SwiftUI
import HealthKit
import MediaPlayer
internal import Combine

// MARK: - Main Screen
struct WorkoutSessionScreen: View {
    
    @ObservedObject var session: LiveWorkoutSession
    @StateObject private var music = WorkoutMusicController()
    
    @State private var showSummary = false
    @State private var summaryData: (duration: TimeInterval, calories: Double, avgHeartRate: Double)?

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
                            
                            let mediaHeight = max(360, geometry.size.height * 0.48)
                            
                            // --- Music / Spotify Section ---
                            VStack(spacing: 12) {
                                MediaCardView(mode: .songs, musicController: music)
                                HStack(spacing: 12) {
                                    Button(action: {
                                        SpotifyAuthManager.shared.startLogin()
                                        music.pickProvider(.spotify)
                                    }) {
                                        HStack {
                                            Image(systemName: "link")
                                            Text("Connect Spotify")
                                        }
                                        .font(.headline.bold())
                                        .foregroundColor(.black)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 52)
                                        .background(WorkoutTheme.pastelMint)
                                        .clipShape(Capsule())
                                    }
                                    
                                    Button(action: {
                                        music.pickProvider(.spotify)
                                        music.playPause()
                                    }) {
                                        HStack {
                                            Image(systemName: "play.fill")
                                            Text("Open Spotify")
                                        }
                                        .font(.headline.bold())
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 52)
                                        .background(Color.black.opacity(0.85))
                                        .clipShape(Capsule())
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                            .frame(height: mediaHeight)
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
                                        music.onWorkoutPause()
                                    } else {
                                        if session.phase == .idle {
                                            session.startFromPhone()
                                        } else {
                                            session.resumeFromPhone()
                                        }
                                        music.onWorkoutStart()
                                    }
                                }
                            }) {
                                HStack {
                                    Image(systemName: session.phase == .running ? "pause.fill" : "play.fill")
                                    Text(session.phase == .running ? "Pause Workout" : (session.phase == .idle ? "Start Workout" : "Resume"))
                                }
                                .font(.system(.title3, design: .rounded).weight(.bold))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 65)
                                .background(WorkoutTheme.pastelMint)
                                .clipShape(Capsule())
                                .shadow(color: WorkoutTheme.pastelMint.opacity(0.3), radius: 10)
                            }
                            
                            if session.phase == .paused {
                                Button(action: { endWorkout() }) {
                                    Image(systemName: "stop.fill")
                                        .font(.title2)
                                        .foregroundStyle(.white)
                                        .frame(width: 65, height: 65)
                                        .background(Color(red: 1.0, green: 0.35, blue: 0.40))
                                        .clipShape(Circle())
                                }
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
        }
        .onAppear {
            if music.provider == .none { music.pickProvider(.appleMusic) }
        }
        .fullScreenCover(isPresented: $showSummary) {
            if let data = summaryData {
                PhoneWorkoutSummaryView(
                    duration: data.duration,
                    calories: data.calories,
                    avgHeartRate: data.avgHeartRate,
                    heartRateSamples: [],
                    onDismiss: { showSummary = false }
                )
            }
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
        let finalDuration = TimeInterval(session.elapsedSeconds)
        let finalCalories = session.activeEnergy
        let finalAvgHR = session.heartRate
        let finalDistance = session.distanceMeters
        let estimatedSteps = max(Int((finalDistance / 1000.0) * 1300.0), 0)

        self.summaryData = (finalDuration, finalCalories, finalAvgHR)
        session.endFromPhone()
        music.onWorkoutEnd()
        showSummary = true

        Task {
            await CaptainSmartNotificationService.shared.handleWorkoutCompleted(
                summary: WorkoutCoachingSummary(
                    duration: finalDuration,
                    calories: finalCalories,
                    averageHeartRate: finalAvgHR,
                    distanceMeters: finalDistance,
                    estimatedSteps: estimatedSteps
                )
            )
        }
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

struct MediaCardView: View {
    let mode: MediaMode
    @ObservedObject var musicController: WorkoutMusicController
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.3))
                if let art = musicController.artwork {
                    Image(uiImage: art).resizable().aspectRatio(contentMode: .fill)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    Image(systemName: mode == .songs ? "music.note" : "play.rectangle.fill")
                        .font(.title2).foregroundStyle(.white)
                }
            }
            .frame(width: 50, height: 50)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(mode == .songs ? musicController.trackTitle : "Training Video")
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(mode == .songs ? musicController.artistName : "Coach Tip")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                    .lineLimit(1)
            }
            Spacer()
            HStack(spacing: 15) {
                Button(action: { musicController.previous() }) {
                    Image(systemName: "backward.fill").font(.title3).foregroundStyle(.gray)
                }
                Button(action: { musicController.playPause() }) {
                    Circle()
                        .fill(Color(red: 0.0, green: 0.85, blue: 0.65))
                        .frame(width: 45, height: 45)
                        .overlay(Image(systemName: musicController.isPlaying ? "pause.fill" : "play.fill").foregroundStyle(.white).font(.title3))
                        .shadow(color: Color.green.opacity(0.4), radius: 8)
                }
                Button(action: { musicController.next() }) {
                    Image(systemName: "forward.fill").font(.title3).foregroundStyle(.gray)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(red: 0.15, green: 0.15, blue: 0.18))
                .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - Music Controller
@MainActor
final class WorkoutMusicController: ObservableObject {
    enum Provider { case appleMusic, spotify, none }
    @Published var provider: Provider = .none
    @Published var trackTitle: String = "Not Playing"
    @Published var artistName: String = "Select Music"
    @Published var isPlaying: Bool = false
    @Published var artwork: UIImage? = nil
    private var cancellables = Set<AnyCancellable>()
    private let applePlayer = MPMusicPlayerController.systemMusicPlayer

    init() {
        NotificationCenter.default.publisher(for: .MPMusicPlayerControllerNowPlayingItemDidChange)
            .sink { [weak self] _ in self?.refreshAppleNowPlaying() }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: .MPMusicPlayerControllerPlaybackStateDidChange)
            .sink { [weak self] _ in self?.refreshApplePlaybackState() }
            .store(in: &cancellables)
        applePlayer.beginGeneratingPlaybackNotifications()
    }
    func pickProvider(_ p: Provider) { provider = p; refreshAppleNowPlaying() }
    func playPause() {
        if provider == .appleMusic { if applePlayer.playbackState == .playing { applePlayer.pause() } else { applePlayer.play() } }
        else if provider == .spotify { openSpotify() }
    }
    func next() { if provider == .appleMusic { applePlayer.skipToNextItem() } }
    func previous() { if provider == .appleMusic { applePlayer.skipToPreviousItem() } }
    func onWorkoutStart() { if provider == .appleMusic { applePlayer.play() } }
    func onWorkoutPause() { if provider == .appleMusic { applePlayer.pause() } }
    func onWorkoutEnd() { if provider == .appleMusic { applePlayer.pause() } }
    private func refreshAppleNowPlaying() {
        guard provider == .appleMusic else { return }
        if let item = applePlayer.nowPlayingItem {
            trackTitle = item.title ?? "Unknown"
            artistName = item.artist ?? "Unknown"
            artwork = item.artwork?.image(at: CGSize(width: 150, height: 150))
        }
    }
    private func refreshApplePlaybackState() { isPlaying = (applePlayer.playbackState == .playing) }
    private func openSpotify() {
        if let url = URL(string: "spotify://") { if UIApplication.shared.canOpenURL(url) { UIApplication.shared.open(url) } }
    }
}
