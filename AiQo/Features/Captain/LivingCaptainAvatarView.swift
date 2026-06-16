import SwiftUI
import Combine
import CoreMotion

/// A "living" Captain portrait. Same grown Hamoudi for every tier — only the
/// outfit (asset) differs (free `Hammoudi4`, paid `Hammoudi5`). What makes the
/// PAID Captain feel elevated is the treatment, not a different character:
///   • a soft brand-colored aura that breathes and brightens when he speaks,
///   • gentle motion parallax (tilt the phone → depth),
///   • a breathing idle + a tap reaction.
/// Free gets the breathing + parallax (alive, but plain); the aura/particles are
/// paid-only so subscribing visibly "powers him up". Honors Reduce Motion and
/// the device performance tier. No 3D model required.
struct LivingCaptainAvatarView: View {
    /// Re-render the moment entitlement changes so the avatar + aura update the
    /// instant the user subscribes.
    @ObservedObject private var entitlements = EntitlementStore.shared
    /// Drives the speaking-reactive aura glow.
    @ObservedObject private var voice = CaptainVoiceRouter.shared
    @StateObject private var motion = CaptainMotionParallax()

    @State private var breathing = false
    @State private var auraPulse = false
    @State private var ringRotation = 0.0
    @State private var particlesRise = false
    @State private var tapScale: CGFloat = 1.0

    private var isPaid: Bool {
        DevOverride.unlockAllFeatures || TierGate.shared.canAccess(.captainChat)
    }
    private var reduceMotion: Bool { AiQoAccessibility.prefersReducedMotion }
    private var richEffects: Bool {
        isPaid && !reduceMotion && DevicePerformanceTier.shouldUseHighFidelity3D
    }
    private var speaking: Bool { voice.isSpeaking }

    var body: some View {
        let _ = entitlements
        ZStack {
            if isPaid {
                auraLayer
                    .offset(x: motion.roll * 22, y: motion.pitch * 14)
                    .animation(.easeInOut(duration: 0.45), value: speaking)
            }

            Image(CaptainAvatarAsset.current)
                .resizable()
                .aspectRatio(contentMode: .fit)
                // Fill the caller's frame so the fixed-size aura behind never
                // dictates (and shrinks/hides) the portrait — the bug where the
                // paid Captain vanished while the aura was present.
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .scaleEffect(breathing ? 1.012 : 1.0, anchor: .bottom)
                .offset(
                    x: motion.roll * 10,
                    y: (breathing ? -4 : 0) + motion.pitch * 6
                )
                .shadow(color: .black.opacity(0.15), radius: 25, x: 0, y: 15)
        }
        .scaleEffect(tapScale)
        .contentShape(Rectangle())
        .onTapGesture { reactToTap() }
        .onAppear { startLife() }
        .onDisappear { motion.stop() }
    }

    // MARK: - Aura (paid only)

    private var auraLayer: some View {
        ZStack {
            // Primary mint glow — sits behind the head/torso.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "C4F0DB").opacity(speaking ? 0.60 : 0.40), .clear],
                        center: .center, startRadius: 4, endRadius: 200
                    )
                )
                .frame(width: 320, height: 320)
                .blur(radius: 16)
                .scaleEffect(auraPulse ? 1.08 : 0.94)

            // Warm gold accent for depth.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "FFDF63").opacity(speaking ? 0.34 : 0.20), .clear],
                        center: .center, startRadius: 4, endRadius: 150
                    )
                )
                .frame(width: 220, height: 220)
                .offset(x: 26, y: -34)
                .blur(radius: 22)
                .scaleEffect(auraPulse ? 1.12 : 0.92)

            if richEffects {
                Circle()
                    .strokeBorder(
                        AngularGradient(
                            colors: [
                                Color(hex: "C4F0DB").opacity(0.0),
                                Color(hex: "CDF4E4").opacity(0.45),
                                Color(hex: "FFDF63").opacity(0.30),
                                Color(hex: "C4F0DB").opacity(0.0)
                            ],
                            center: .center
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 290, height: 290)
                    .blur(radius: 1.5)
                    .rotationEffect(.degrees(ringRotation))

                particles
            }
        }
        // Anchor the glow behind the upper body of the standing figure.
        .offset(y: -60)
        .allowsHitTesting(false)
    }

    private var particles: some View {
        ZStack {
            ForEach(Array(Self.particleSeeds.enumerated()), id: \.offset) { index, seed in
                Circle()
                    .fill(Color(hex: index % 2 == 0 ? "CDF4E4" : "FFE68C").opacity(0.5))
                    .frame(width: seed.size, height: seed.size)
                    .offset(x: seed.x, y: particlesRise ? seed.yEnd : seed.yStart)
                    .opacity(particlesRise ? 0.0 : 0.7)
                    .animation(
                        .easeInOut(duration: seed.duration).repeatForever(autoreverses: false),
                        value: particlesRise
                    )
            }
        }
    }

    // MARK: - Behavior

    private func startLife() {
        guard !reduceMotion else { return }
        motion.start()

        withAnimation(.easeInOut(duration: 3.4).repeatForever(autoreverses: true)) {
            breathing = true
        }

        guard isPaid else { return }
        withAnimation(.easeInOut(duration: 3.8).repeatForever(autoreverses: true)) {
            auraPulse = true
        }
        if richEffects {
            withAnimation(.linear(duration: 26).repeatForever(autoreverses: false)) {
                ringRotation = 360
            }
            particlesRise = true
        }
    }

    private func reactToTap() {
        HapticEngine.light()
        guard !reduceMotion else { return }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.45)) { tapScale = 0.96 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.5)) { tapScale = 1.0 }
        }
    }

    private struct ParticleSeed {
        let x: CGFloat
        let yStart: CGFloat
        let yEnd: CGFloat
        let size: CGFloat
        let duration: Double
    }

    private static let particleSeeds: [ParticleSeed] = [
        .init(x: -90, yStart: 120, yEnd: -110, size: 6, duration: 6.0),
        .init(x: 70, yStart: 140, yEnd: -90, size: 5, duration: 7.5),
        .init(x: -40, yStart: 100, yEnd: -140, size: 4, duration: 8.5),
        .init(x: 100, yStart: 90, yEnd: -120, size: 7, duration: 6.8),
        .init(x: 20, yStart: 150, yEnd: -100, size: 4, duration: 9.0),
        .init(x: -110, yStart: 80, yEnd: -130, size: 5, duration: 7.2),
        .init(x: 55, yStart: 130, yEnd: -150, size: 6, duration: 8.0),
        .init(x: -20, yStart: 110, yEnd: -120, size: 4, duration: 6.4)
    ]
}

/// Lightweight CoreMotion parallax source. Publishes smoothed, clamped roll &
/// pitch (−1…1) for the avatar/aura to drift against — the cheap depth trick
/// that makes a flat portrait feel present. Raw device-motion needs no privacy
/// prompt. Stops on disappear to save battery.
@MainActor
final class CaptainMotionParallax: ObservableObject {
    @Published var roll: Double = 0
    @Published var pitch: Double = 0

    private let manager = CMMotionManager()

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            let targetRoll = max(-1, min(1, motion.attitude.roll / 0.6))
            let targetPitch = max(-1, min(1, motion.attitude.pitch / 0.6))
            // Low-pass smoothing so the portrait glides instead of jittering.
            self.roll += (targetRoll - self.roll) * 0.12
            self.pitch += (targetPitch - self.pitch) * 0.12
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }

    deinit {
        manager.stopDeviceMotionUpdates()
    }
}
