//
//  OutdoorRunSessionView.swift
//  AiQo
//
//  Full-screen Outdoor Running experience: a live 3D satellite map that flies
//  behind the runner like a chase drone, with the route drawn in orange and
//  Pace / Elevation / Distance laid over the top.
//

import CoreLocation
import MapKit
import SwiftUI
import UIKit

struct OutdoorRunSessionView: View {

    let onClose: () -> Void

    @StateObject private var location = RunLocationManager()
    @StateObject private var session: OutdoorRunSession
    @ObservedObject private var connectivity = PhoneConnectivityManager.shared

    @State private var camera: MapCameraPosition = .automatic
    @State private var showCloseConfirm = false
    /// 0 = no fix yet, 1 = wide establishing shot shown, 2+ = locked chase glide.
    @State private var introStage = 0

    init(title: String, onClose: @escaping () -> Void) {
        self.onClose = onClose
        _session = StateObject(wrappedValue: OutdoorRunSession(title: title))
    }

    var body: some View {
        ZStack {
            mapLayer
                .ignoresSafeArea()

            topGradient
            bottomGradient

            VStack(spacing: 0) {
                statsBar
                    .padding(.horizontal, 22)
                    .padding(.top, 8)
                Spacer()
                controlBar
                    .padding(.horizontal, 24)
                    .padding(.bottom, 34)
            }

            closeButton

            if session.showMilestone {
                milestonePill
                    .transition(.scale.combined(with: .opacity))
            }

            if shouldShowGPSSearching {
                gpsSearchingBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            if !location.isAuthorized {
                RunPermissionGate(
                    isDenied: location.isDenied,
                    onAllow: { location.requestAuthorization() },
                    onOpenSettings: openSystemSettings,
                    onClose: closeImmediately
                )
                .transition(.opacity)
            }

            if session.phase == .finished {
                RunSummaryView(
                    title: session.title,
                    distanceMeters: session.distanceMeters,
                    elapsedSeconds: session.elapsedSeconds,
                    averagePaceSecondsPerKm: session.averagePaceSecondsPerKm,
                    elevationGainMeters: location.elevationGainMeters,
                    calories: session.finalCalories,
                    averageHeartRate: session.finalAvgHeartRate,
                    routeCoordinates: location.routeCoordinates,
                    finishedAt: session.finishedAt,
                    onDone: closeImmediately
                )
                .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: session.phase)
        .animation(.easeInOut(duration: 0.25), value: location.authorizationStatus)
        .onAppear(perform: handleAppear)
        .onDisappear { location.endRun() }
        .onChange(of: location.authorizationStatus) { _, _ in
            if location.isAuthorized { location.beginPreview() }
        }
        .onChange(of: location.fixTick) { _, _ in
            updateCameraToRunner()
        }
        .onChange(of: location.distanceMeters) { _, meters in
            session.updateDistance(meters)
        }
        .alert(L10n.t("run.close.confirm.title"), isPresented: $showCloseConfirm) {
            Button(L10n.t("run.close.confirm.finish")) {
                finishRun()
            }
            Button(L10n.t("run.close.confirm.keep"), role: .cancel) {}
        } message: {
            Text(L10n.t("run.close.confirm.message"))
        }
    }

    // MARK: - Map

    private var mapLayer: some View {
        Map(position: $camera, interactionModes: .all) {
            if location.routeCoordinates.count >= 2 {
                // Soft wide under-glow for the cinematic Strava-flyover look…
                MapPolyline(coordinates: location.routeCoordinates)
                    .stroke(
                        Color(red: 1.0, green: 0.42, blue: 0.12).opacity(0.28),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round, lineJoin: .round)
                    )
                // …with a bright crisp core on top.
                MapPolyline(coordinates: location.routeCoordinates)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.55, blue: 0.18),
                                Color(red: 1.0, green: 0.34, blue: 0.10)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)
                    )
            }
            if let runner = location.currentLocation {
                Annotation("", coordinate: runner.coordinate, anchor: .center) {
                    RunnerLocationDot()
                }
            }
        }
        .mapStyle(.imagery(elevation: .realistic))
    }

    private func updateCameraToRunner() {
        guard let runner = location.currentLocation else { return }
        switch introStage {
        case 0:
            // First fix: snap to a high, wide establishing shot.
            introStage = 1
            camera = .camera(MapCamera(
                centerCoordinate: runner.coordinate,
                distance: 5200,
                heading: location.smoothedCourseDegrees,
                pitch: 40
            ))
        case 1:
            // Cinematic descent from the establishing shot into the chase.
            introStage = 2
            withAnimation(.easeInOut(duration: 2.2)) {
                camera = .camera(chaseCamera(for: runner))
            }
        default:
            // Linear chaining turns the ~1 Hz fixes into one continuous glide.
            withAnimation(.linear(duration: 1.15)) {
                camera = .camera(chaseCamera(for: runner))
            }
        }
    }

    /// The locked "drone right behind and above you" framing.
    private func chaseCamera(for runner: CLLocation) -> MapCamera {
        MapCamera(
            centerCoordinate: runner.coordinate,
            distance: 480,
            heading: location.smoothedCourseDegrees,
            pitch: 66
        )
    }

    // MARK: - Stats

    private var statsBar: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                RunHeroStat(
                    value: distanceValueText,
                    unit: distanceUnitText,
                    label: L10n.t("gym.metrics.distance")
                )
                RunHeroStat(
                    value: timeValueText,
                    unit: "",
                    label: L10n.t("run.metrics.timeLabel")
                )
            }

            HStack(alignment: .top, spacing: 0) {
                RunStatColumn(
                    value: paceValueText,
                    unit: L10n.t("run.metrics.paceUnit"),
                    label: L10n.t("gym.metrics.pace")
                )
                .frame(maxWidth: .infinity)

                RunStatColumn(
                    value: heartRateText,
                    unit: L10n.t("heart.bpmUnit"),
                    label: L10n.t("gym.metrics.heartRate")
                )
                .frame(maxWidth: .infinity)

                RunStatColumn(
                    value: caloriesText,
                    unit: L10n.t("gym.metrics.kcalShort"),
                    label: L10n.t("run.metrics.calories")
                )
                .frame(maxWidth: .infinity)

                RunStatColumn(
                    value: elevationValueText,
                    unit: L10n.t("gym.metrics.meterShort"),
                    label: L10n.t("gym.metric.elevation")
                )
                .frame(maxWidth: .infinity)
            }

            if session.isWatchActive {
                watchChip
            }
        }
        .environment(\.layoutDirection, .leftToRight)
    }

    private var watchChip: some View {
        HStack(spacing: 6) {
            Image(systemName: "applewatch.radiowaves.left.and.right")
                .font(.system(size: 12, weight: .bold))
            Text(L10n.t("run.watch.connected"))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(.white.opacity(0.85))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.black.opacity(0.35), in: Capsule())
    }

    // MARK: - Controls

    @ViewBuilder
    private var controlBar: some View {
        switch session.phase {
        case .ready:
            RunPrimaryButton(
                title: L10n.t("run.control.start"),
                systemImage: "figure.run",
                tint: Color(red: 1.0, green: 0.42, blue: 0.12),
                isEnabled: location.isAuthorized
            ) {
                startRun()
            }

        case .running, .paused:
            HStack(spacing: 14) {
                RunPrimaryButton(
                    title: session.phase == .paused
                        ? L10n.t("run.control.resume")
                        : L10n.t("run.control.pause"),
                    systemImage: session.phase == .paused ? "play.fill" : "pause.fill",
                    tint: WorkoutTheme.pastelBeige,
                    foreground: .black,
                    isEnabled: true
                ) {
                    togglePause()
                }

                Button(action: finishRun) {
                    Image(systemName: "stop.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .background(Color(red: 1.0, green: 0.35, blue: 0.40))
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                }
            }

        case .finished:
            EmptyView()
        }
    }

    private var closeButton: some View {
        VStack {
            HStack {
                Spacer()
                Button(action: handleCloseTap) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(.black.opacity(0.4))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1))
                }
            }
            Spacer()
        }
        .padding(.top, 14)
        .padding(.horizontal, 18)
    }

    // MARK: - Overlays

    private var milestonePill: some View {
        VStack {
            Spacer()
            Text(session.milestoneText)
                .font(.system(size: 44, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 34)
                .padding(.vertical, 18)
                .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: .black.opacity(0.4), radius: 16)
            Spacer()
        }
    }

    private var gpsSearchingBanner: some View {
        VStack {
            HStack(spacing: 8) {
                ProgressView()
                    .tint(.white)
                Text(L10n.t(location.signalIsWeak ? "run.gps.weak" : "run.gps.searching"))
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(.black.opacity(0.5), in: Capsule())
            .padding(.top, 70)
            Spacer()
        }
    }

    private var topGradient: some View {
        VStack {
            LinearGradient(
                colors: [.black.opacity(0.55), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 200)
            .ignoresSafeArea()
            Spacer()
        }
        .allowsHitTesting(false)
    }

    private var bottomGradient: some View {
        VStack {
            Spacer()
            LinearGradient(
                colors: [.clear, .black.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 220)
            .ignoresSafeArea()
        }
        .allowsHitTesting(false)
    }

    // MARK: - Actions

    private func handleAppear() {
        if location.needsPrompt {
            location.requestAuthorization()
        } else if location.isAuthorized {
            location.beginPreview()
        }
    }

    private func startRun() {
        location.startRun()
        session.start()
    }

    private func togglePause() {
        if session.phase == .running {
            session.pause()
            location.pauseRun()
        } else if session.phase == .paused {
            session.resume()
            location.resumeRun()
        }
    }

    private func finishRun() {
        session.finish()
        location.endRun()
    }

    private func handleCloseTap() {
        if session.isActive {
            showCloseConfirm = true
        } else {
            closeImmediately()
        }
    }

    private func closeImmediately() {
        location.endRun()
        onClose()
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private var shouldShowGPSSearching: Bool {
        location.isAuthorized
            && session.phase != .finished
            && (!location.hasFix || (session.isActive && location.signalIsWeak))
    }

    // MARK: - Formatting

    private var paceValueText: String {
        let pace: Double?
        if session.isActive {
            pace = session.livePaceSecondsPerKm(
                currentSpeedMetersPerSecond: location.speedMetersPerSecond
            )
        } else {
            pace = session.averagePaceSecondsPerKm
        }
        guard let pace, pace.isFinite, pace > 0, pace < 60 * 60 else { return "—:—" }
        let total = Int(pace.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private var elevationValueText: String {
        guard location.hasFix else { return "—" }
        return "\(Int(location.altitudeMeters.rounded()))"
    }

    private var distanceValueText: String {
        let meters = session.distanceMeters
        if meters >= 1000 {
            return String(format: "%.2f", locale: questAppLocale(), meters / 1000)
        }
        return "\(Int(meters))"
    }

    private var distanceUnitText: String {
        session.distanceMeters >= 1000
            ? L10n.t("gym.metrics.kmShort")
            : L10n.t("gym.metrics.meterShort")
    }

    private var timeValueText: String {
        let total = session.elapsedSeconds
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
    }

    private var heartRateText: String {
        let bpm = Int(session.heartRate.rounded())
        return bpm > 0 ? "\(bpm)" : "—"
    }

    private var caloriesText: String {
        session.phase == .ready ? "—" : "\(Int(session.liveCalories.rounded()))"
    }
}

// MARK: - Stat Column

private struct RunStatColumn: View {
    let value: String
    let unit: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(unit)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.65))
                .textCase(.uppercase)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.top, 2)
        }
        .shadow(color: .black.opacity(0.5), radius: 6, y: 1)
    }
}

// MARK: - Hero Stat (Distance / Time)

private struct RunHeroStat: View {
    let value: String
    let unit: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(value)
                    .font(.system(size: 50, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            Text(label)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.65))
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
        .shadow(color: .black.opacity(0.5), radius: 6, y: 1)
    }
}

// MARK: - Runner Dot

private struct RunnerLocationDot: View {
    @State private var pulse = false
    private let runOrange = Color(red: 1.0, green: 0.42, blue: 0.12)

    var body: some View {
        ZStack {
            // Forward beam: the chase camera is locked to the runner's heading,
            // so the direction of travel is always straight up on screen.
            ForwardBeam()
                .fill(
                    LinearGradient(
                        colors: [runOrange.opacity(0.55), runOrange.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 30, height: 40)
                .offset(y: -30)

            Circle()
                .fill(runOrange.opacity(0.30))
                .frame(width: 52, height: 52)
                .scaleEffect(pulse ? 1.3 : 0.75)

            Circle()
                .fill(.white)
                .frame(width: 26, height: 26)
                .shadow(color: .black.opacity(0.4), radius: 3)

            Circle()
                .fill(runOrange)
                .frame(width: 17, height: 17)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

private struct ForwardBeam: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Primary Button

private struct RunPrimaryButton: View {
    let title: String
    let systemImage: String
    let tint: Color
    var foreground: Color = .white
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(.system(.title3, design: .rounded).weight(.bold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(tint)
            .clipShape(Capsule())
            .shadow(color: tint.opacity(0.5), radius: 12, y: 6)
            .opacity(isEnabled ? 1 : 0.5)
        }
        .disabled(!isEnabled)
    }
}

// MARK: - Permission Gate

private struct RunPermissionGate: View {
    let isDenied: Bool
    let onAllow: () -> Void
    let onOpenSettings: () -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.82).ignoresSafeArea()

            VStack(spacing: 22) {
                Image(systemName: "location.fill.viewfinder")
                    .font(.system(size: 54, weight: .bold))
                    .foregroundStyle(WorkoutTheme.pastelMint)

                Text(L10n.t("run.permission.title"))
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(L10n.t("run.permission.body"))
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.82))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 8)

                Button(action: isDenied ? onOpenSettings : onAllow) {
                    Text(L10n.t(isDenied ? "run.permission.openSettings" : "run.permission.allow"))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(WorkoutTheme.pastelMint)
                        .clipShape(Capsule())
                }

                Button(action: onClose) {
                    Text(L10n.t("run.summary.done"))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .padding(.horizontal, 28)
        }
    }
}
