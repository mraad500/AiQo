//
//  RunSummaryView.swift
//  AiQo
//
//  Post-run summary: an interactive 3D satellite map of the exact route the
//  user ran, their stats arranged like a trophy, and one-tap sharing of a
//  polished 1080×1920 card (route + stats + AiQo branding) — built so the
//  user *wants* to post it.
//

import CoreLocation
import MapKit
import SwiftUI
import UIKit

struct RunSummaryView: View {

    let title: String
    let distanceMeters: Double
    let elapsedSeconds: Int
    let averagePaceSecondsPerKm: Double?
    let elevationGainMeters: Double
    let calories: Double
    let averageHeartRate: Double
    let routeCoordinates: [CLLocationCoordinate2D]
    let finishedAt: Date?
    let onDone: () -> Void

    @State private var camera: MapCameraPosition = .automatic
    @State private var isSharing = false

    private let mint = Color(red: 0.718, green: 0.890, blue: 0.792)
    private let runOrange = Color(red: 1.0, green: 0.45, blue: 0.13)
    private var hasRoute: Bool { routeCoordinates.count >= 2 }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.07, blue: 0.07),
                    Color(red: 0.10, green: 0.12, blue: 0.11),
                    Color(red: 0.04, green: 0.05, blue: 0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    header
                    routeMap
                    distanceHero
                    statsRow
                    brandMark
                    actionButtons
                        .padding(.top, 6)
                }
                .padding(.horizontal, 22)
                .padding(.top, 26)
                .padding(.bottom, 40)
            }
        }
        .onAppear(perform: fitCameraToRoute)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 46, weight: .bold))
                .foregroundStyle(mint)

            Text(L10n.t("run.summary.title"))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
                .textCase(.uppercase)
                .tracking(4)

            Text(title)
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            if let dateText {
                Text(dateText)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
    }

    // MARK: - Route map (interactive)

    @ViewBuilder
    private var routeMap: some View {
        Group {
            if hasRoute {
                Map(position: $camera, interactionModes: .all) {
                    MapPolyline(coordinates: routeCoordinates)
                        .stroke(runOrange.opacity(0.28),
                                style: StrokeStyle(lineWidth: 13, lineCap: .round, lineJoin: .round))
                    MapPolyline(coordinates: routeCoordinates)
                        .stroke(runOrange,
                                style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))

                    if let start = routeCoordinates.first {
                        Annotation("", coordinate: start, anchor: .center) {
                            RouteEndDot(color: mint)
                        }
                    }
                    if let finish = routeCoordinates.last {
                        Annotation("", coordinate: finish, anchor: .center) {
                            RouteEndDot(color: runOrange)
                        }
                    }
                }
                .mapStyle(.imagery(elevation: .realistic))
            } else {
                ZStack {
                    LinearGradient(
                        colors: [runOrange.opacity(0.4), Color(red: 0.10, green: 0.12, blue: 0.11)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    VStack(spacing: 10) {
                        Image(systemName: "location.slash.fill")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(.white.opacity(0.8))
                        Text(L10n.t("run.gps.searching"))
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
        }
        .frame(height: 360)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.45), radius: 18, y: 10)
    }

    // MARK: - Distance hero

    private var distanceHero: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(distanceValue)
                .font(.system(size: 76, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text(distanceUnit)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(mint)
        }
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: 0) {
            stat(icon: "clock.fill", value: timeText, label: L10n.t("run.metrics.timeLabel"))
            statDivider
            stat(icon: "speedometer", value: paceText, label: L10n.t("gym.metrics.pace"))
            statDivider
            stat(icon: "heart.fill", value: heartRateText, label: L10n.t("gym.metrics.heartRate"))
            statDivider
            stat(icon: "flame.fill", value: caloriesText, label: L10n.t("run.metrics.calories"))
            statDivider
            stat(icon: "mountain.2.fill", value: elevationText, label: L10n.t("gym.metric.elevation"))
        }
        .padding(.vertical, 22)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(.white.opacity(0.10), lineWidth: 1)
                )
        )
    }

    private var statDivider: some View {
        Rectangle().fill(.white.opacity(0.10)).frame(width: 1, height: 54)
    }

    private func stat(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(mint)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
    }

    private var brandMark: some View {
        HStack(spacing: 6) {
            Image(systemName: "location.north.fill")
                .font(.system(size: 13, weight: .bold))
            Text(L10n.t("run.share.tagline"))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(.white.opacity(0.4))
    }

    // MARK: - Actions

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: shareRun) {
                HStack(spacing: 10) {
                    if isSharing {
                        ProgressView().tint(.black)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                    }
                    Text(L10n.t("run.summary.shareButton"))
                }
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(mint)
                .clipShape(Capsule())
                .shadow(color: mint.opacity(0.4), radius: 12, y: 6)
            }
            .disabled(isSharing)

            Button(action: onDone) {
                Text(L10n.t("run.summary.done"))
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(.white.opacity(0.08))
                    .clipShape(Capsule())
            }
        }
    }

    private func shareRun() {
        guard !isSharing else { return }
        isSharing = true
        Task {
            let routeImage = await RunRouteSnapshotter.snapshot(
                coordinates: routeCoordinates,
                size: CGSize(width: 1080, height: 1080)
            )
            let card = await ShareCardRenderer.renderOutdoorRunCard(
                routeImage: routeImage,
                kicker: L10n.t("run.summary.title"),
                title: title,
                dateText: dateText ?? "",
                distanceValue: distanceValue,
                distanceUnit: distanceUnit,
                duration: timeText,
                pace: paceText,
                paceUnit: L10n.t("run.metrics.paceUnit"),
                heartRate: heartRateText,
                elevation: elevationText,
                calories: caloriesText,
                userName: UserProfileStore.shared.current.name
            )
            await MainActor.run {
                isSharing = false
                guard let card else { return }
                let caption = String(
                    format: L10n.t("run.share.caption"),
                    "\(distanceValue) \(distanceUnit)"
                )
                ShareCardRenderer.presentShareSheet(image: card, text: caption)
            }
        }
    }

    // MARK: - Camera

    private func fitCameraToRoute() {
        guard hasRoute else { return }
        var minLat = routeCoordinates[0].latitude
        var maxLat = routeCoordinates[0].latitude
        var minLon = routeCoordinates[0].longitude
        var maxLon = routeCoordinates[0].longitude
        for c in routeCoordinates {
            minLat = min(minLat, c.latitude)
            maxLat = max(maxLat, c.latitude)
            minLon = min(minLon, c.longitude)
            maxLon = max(maxLon, c.longitude)
        }
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: (minLon + maxLon) / 2
            ),
            span: MKCoordinateSpan(
                latitudeDelta: min(max((maxLat - minLat) * 1.5, 0.0030), 160),
                longitudeDelta: min(max((maxLon - minLon) * 1.5, 0.0030), 320)
            )
        )
        camera = .region(region)
    }

    // MARK: - Formatting

    private var distanceValue: String {
        distanceMeters >= 1000
            ? String(format: "%.2f", locale: questAppLocale(), distanceMeters / 1000)
            : "\(Int(distanceMeters))"
    }

    private var distanceUnit: String {
        distanceMeters >= 1000
            ? L10n.t("gym.metrics.kmShort")
            : L10n.t("gym.metrics.meterShort")
    }

    private var timeText: String {
        let h = elapsedSeconds / 3600
        let m = (elapsedSeconds % 3600) / 60
        let s = elapsedSeconds % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
    }

    private var paceText: String {
        guard let pace = averagePaceSecondsPerKm, pace.isFinite, pace > 0, pace < 60 * 60 else {
            return "—:—"
        }
        let total = Int(pace.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private var elevationText: String {
        "\(Int(elevationGainMeters.rounded())) \(L10n.t("gym.metrics.meterShort"))"
    }

    private var caloriesText: String {
        "\(Int(calories.rounded()))"
    }

    private var heartRateText: String {
        let bpm = Int(averageHeartRate.rounded())
        return bpm > 0 ? "\(bpm)" : "—"
    }

    private var dateText: String? {
        guard let finishedAt else { return nil }
        let formatter = DateFormatter()
        formatter.locale = questAppLocale()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: finishedAt)
    }
}

// MARK: - Route endpoint marker

private struct RouteEndDot: View {
    let color: Color

    var body: some View {
        ZStack {
            Circle().fill(.white).frame(width: 22, height: 22)
            Circle().fill(color).frame(width: 14, height: 14)
        }
        .shadow(color: .black.opacity(0.4), radius: 3)
    }
}
