import SwiftUI

// MARK: - Background

struct MyVibeBackground: View {
    let state: DailyVibeState
    var isDJModeActive: Bool = false

    var body: some View {
        ZStack {
            if isDJModeActive {
                Color.black.ignoresSafeArea()
            } else {
                LinearGradient(
                    colors: [Color(hex: "FAFAF7"), Color(hex: "F3F4F1")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }

            // Primary gradient glow — shifts hue per state
            RadialGradient(
                gradient: Gradient(colors: [
                    stateAccent.opacity(isDJModeActive ? 0.18 : 0.10),
                    Color.clear
                ]),
                center: .topTrailing,
                startRadius: 40,
                endRadius: 380
            )
            .ignoresSafeArea()

            // Secondary ambient glow
            Circle()
                .fill(Color(hex: "8AE3D1").opacity(isDJModeActive ? 0.07 : 0.04))
                .frame(width: 340, height: 340)
                .blur(radius: 100)
                .offset(x: -140, y: 320)
        }
        .animation(.easeInOut(duration: 0.6), value: isDJModeActive)
        .animation(.easeInOut(duration: 1.2), value: state)
    }

    private var stateAccent: Color {
        switch state {
        case .awakening:  return Color(hex: "FFD166")
        case .deepFocus:  return Color(hex: "8AE3D1")
        case .peakEnergy: return Color(hex: "FF9F43")
        case .recovery:   return Color(hex: "A78BFA")
        case .egoDeath:   return Color(hex: "6366F1")
        }
    }
}

// MARK: - Timeline Node

struct VibeTimelineNode: View {
    let state: DailyVibeState
    let isActive: Bool
    let isPlaying: Bool

    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Outer glow ring
                if isActive {
                    Circle()
                        .fill(accentColor.opacity(0.2))
                        .frame(width: 58, height: 58)
                        .scaleEffect(pulseScale)
                        .animation(
                            isPlaying
                                ? .easeInOut(duration: 1.6).repeatForever(autoreverses: true)
                                : .default,
                            value: pulseScale
                        )
                }

                Circle()
                    .fill(
                        isActive
                            ? LinearGradient(
                                colors: [accentColor, accentColor.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [Color.white.opacity(0.08), Color.white.opacity(0.04)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                    )
                    .frame(width: 48, height: 48)
                    .overlay {
                        Circle()
                            .stroke(
                                isActive ? accentColor.opacity(0.5) : Color.white.opacity(0.08),
                                lineWidth: 1
                            )
                    }

                Image(systemName: state.systemIcon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isActive ? Color.black.opacity(0.8) : Color.white.opacity(0.4))
            }
            .shadow(color: isActive ? accentColor.opacity(0.3) : .clear, radius: 12, x: 0, y: 4)

            VStack(spacing: 2) {
                Text(state.title)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(isActive ? Color.white : Color.white.opacity(0.4))
                    .lineLimit(1)

                Text(state.timeWindow)
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(isActive ? 0.5 : 0.24))
            }
        }
        .frame(width: 72)
        .onAppear {
            if isPlaying { pulseScale = 1.08 }
        }
        .onChange(of: isPlaying) { _, playing in
            pulseScale = playing ? 1.08 : 1.0
        }
    }

    private var accentColor: Color {
        switch state {
        case .awakening:  return Color(hex: "FFD166")
        case .deepFocus:  return Color(hex: "8AE3D1")
        case .peakEnergy: return Color(hex: "FF9F43")
        case .recovery:   return Color(hex: "A78BFA")
        case .egoDeath:   return Color(hex: "6366F1")
        }
    }
}

// MARK: - Waveform Visualizer

struct VibeWaveformView: View {
    private let barCount = 24

    @State private var amplitudes: [CGFloat] = []

    var body: some View {
        HStack(spacing: 2.5) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "8AE3D1").opacity(0.7),
                                Color(hex: "8AE3D1").opacity(0.2)
                            ],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(
                        width: 3,
                        height: amplitudes.indices.contains(index) ? amplitudes[index] : 4
                    )
                    .animation(
                        .easeInOut(duration: Double.random(in: 0.4...0.8))
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.04),
                        value: amplitudes
                    )
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            amplitudes = (0..<barCount).map { _ in CGFloat.random(in: 6...28) }
            // Randomize heights continuously
            Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { _ in
                withAnimation {
                    amplitudes = (0..<barCount).map { _ in CGFloat.random(in: 6...28) }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Timeline Node") {
    ZStack {
        Color.black.ignoresSafeArea()

        HStack(spacing: 12) {
            VibeTimelineNode(state: .awakening, isActive: false, isPlaying: false)
            VibeTimelineNode(state: .deepFocus, isActive: true, isPlaying: true)
            VibeTimelineNode(state: .peakEnergy, isActive: false, isPlaying: false)
        }
    }
}

#Preview("Waveform") {
    ZStack {
        Color.black.ignoresSafeArea()

        VibeWaveformView()
            .frame(height: 32)
            .padding()
    }
}
