//
//  RunLocationManager.swift
//  AiQo
//
//  GPS tracker for the Outdoor Running workout. Owns a single CLLocationManager,
//  filters noisy fixes, and accumulates the route + distance/speed/elevation that
//  the live 3D map and the run session read from.
//

import Combine
import CoreLocation
import Foundation

/// Conventional NSObject delegate. The manager is created on the main thread
/// (instantiated from a SwiftUI `@StateObject`), so Core Location delivers its
/// callbacks on the main run loop and `@Published` mutation here is main-thread.
final class RunLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {

    // MARK: - Published GPS truth

    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var currentLocation: CLLocation?
    @Published private(set) var route: [CLLocation] = []
    @Published private(set) var distanceMeters: Double = 0
    @Published private(set) var speedMetersPerSecond: Double = 0
    @Published private(set) var altitudeMeters: Double = 0
    /// Total climb (sum of positive altitude deltas along the route).
    @Published private(set) var elevationGainMeters: Double = 0
    /// Direction of travel in degrees (0 = north). Last valid value is held while
    /// standing still so the follow-camera does not snap back to north.
    @Published private(set) var courseDegrees: Double = 0
    /// Low-pass filtered heading for the chase camera. Raw GPS course is jittery;
    /// this gives the cinematic "drone smoothly banking with you" motion.
    @Published private(set) var smoothedCourseDegrees: Double = 0
    @Published private(set) var horizontalAccuracy: CLLocationAccuracy = -1
    @Published private(set) var hasFix: Bool = false
    /// Monotonic counter bumped on every accepted fix. `CLLocation` is not
    /// `Equatable`, so SwiftUI `.onChange` observers key off this instead.
    @Published private(set) var fixTick: Int = 0

    // MARK: - Tuning

    /// Reject fixes worse than this (metres). Typical good outdoor GPS is < 10 m.
    private let maxAcceptableAccuracy: CLLocationAccuracy = 50
    /// Below this gap we treat movement as GPS jitter and don't accumulate it.
    private let minStepMeters: CLLocationDistance = 1.5
    /// Above this single-fix jump we treat it as a glitch and drop it.
    private let maxStepMeters: CLLocationDistance = 150

    // MARK: - Private

    private let manager = CLLocationManager()
    /// Updates are flowing from Core Location (used for the pre-run preview too).
    private var isReceivingUpdates = false
    /// We are inside an active run and should accumulate route + distance.
    private var isAccumulating = false
    private var lastGoodLocation: CLLocation?
    /// Altitude of the last route point used for elevation-gain accounting.
    private var lastGainAltitude: Double?
    /// Ignore sub-metre altitude wobble so GPS noise isn't counted as climb.
    private let elevationNoiseGate: Double = 1.0
    private var hasHeading = false
    /// Heading low-pass factor (0–1). Lower = smoother / more cinematic lag.
    private let headingSmoothing = 0.18

    // MARK: - Init

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.activityType = .fitness
        manager.distanceFilter = kCLDistanceFilterNone
        manager.pausesLocationUpdatesAutomatically = false
    }

    // MARK: - Derived

    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    var isDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    var needsPrompt: Bool {
        authorizationStatus == .notDetermined
    }

    /// True once we have at least one accepted fix but the live signal is poor.
    var signalIsWeak: Bool {
        hasFix && horizontalAccuracy > 25
    }

    var routeCoordinates: [CLLocationCoordinate2D] {
        route.map(\.coordinate)
    }

    // MARK: - Control

    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    /// Begin the GPS feed without accumulating a route — used so the map can
    /// centre on the runner before they press Start.
    func beginPreview() {
        guard isAuthorized, !isReceivingUpdates else { return }
        isReceivingUpdates = true
        manager.startUpdatingLocation()
    }

    func startRun() {
        route.removeAll()
        distanceMeters = 0
        speedMetersPerSecond = 0
        elevationGainMeters = 0
        lastGoodLocation = nil
        lastGainAltitude = nil
        isAccumulating = true
        isReceivingUpdates = true
        applyBackgroundUpdatesFlag(true)
        manager.startUpdatingLocation()
    }

    /// Stops accumulating but keeps the feed alive so the map still tracks the
    /// runner. Clearing the anchor prevents the paused gap being added on resume.
    func pauseRun() {
        isAccumulating = false
        lastGoodLocation = nil
    }

    func resumeRun() {
        lastGoodLocation = nil
        isAccumulating = true
    }

    func endRun() {
        isAccumulating = false
        isReceivingUpdates = false
        manager.stopUpdatingLocation()
        applyBackgroundUpdatesFlag(false)
    }

    private func applyBackgroundUpdatesFlag(_ enabled: Bool) {
        // Only legal to enable when authorized; the `location` UIBackgroundMode
        // is declared in Info.plist so the run keeps tracking with the screen off.
        guard isAuthorized else {
            manager.allowsBackgroundLocationUpdates = false
            return
        }
        manager.allowsBackgroundLocationUpdates = enabled
        manager.showsBackgroundLocationIndicator = enabled
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if isAccumulating { applyBackgroundUpdatesFlag(true) }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for location in locations { ingest(location) }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Transient errors (e.g. momentary signal loss) are expected mid-run.
        // We keep the session alive and wait for the next good fix.
    }

    // MARK: - Ingestion

    private func ingest(_ location: CLLocation) {
        guard location.horizontalAccuracy >= 0,
              location.horizontalAccuracy <= maxAcceptableAccuracy else { return }
        // Drop cached/stale fixes Core Location sometimes replays on start.
        guard location.timestamp.timeIntervalSinceNow > -10 else { return }

        currentLocation = location
        horizontalAccuracy = location.horizontalAccuracy
        altitudeMeters = location.altitude
        hasFix = true
        fixTick &+= 1

        if location.speed >= 0 {
            speedMetersPerSecond = location.speed
        }
        // Core Location's course is only trustworthy while genuinely moving;
        // below ~1 m/s we hold the last heading so the camera doesn't spin.
        if location.course >= 0, location.speed >= 1.0 {
            courseDegrees = location.course
            updateSmoothedHeading(towards: location.course)
        }

        guard isAccumulating else { return }

        if let last = lastGoodLocation {
            let step = location.distance(from: last)
            if step >= minStepMeters && step <= maxStepMeters {
                distanceMeters += step
                route.append(location)
                lastGoodLocation = location
                accumulateElevation(location.altitude)
            }
        } else {
            route.append(location)
            lastGoodLocation = location
            accumulateElevation(location.altitude)
        }
    }

    private func accumulateElevation(_ altitude: Double) {
        defer { lastGainAltitude = altitude }
        guard let previous = lastGainAltitude else { return }
        let climb = altitude - previous
        if climb > elevationNoiseGate {
            elevationGainMeters += climb
        }
    }

    /// Circular exponential smoothing of the heading, taking the shortest path
    /// across the 0°/360° wrap so the camera never spins the long way around.
    private func updateSmoothedHeading(towards newCourse: Double) {
        guard hasHeading else {
            smoothedCourseDegrees = newCourse
            hasHeading = true
            return
        }
        var delta = newCourse - smoothedCourseDegrees
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        var next = smoothedCourseDegrees + headingSmoothing * delta
        if next < 0 { next += 360 }
        if next >= 360 { next -= 360 }
        smoothedCourseDegrees = next
    }
}
