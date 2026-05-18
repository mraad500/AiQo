//
//  RunRouteSnapshotter.swift
//  AiQo
//
//  Renders the run's GPS path onto a satellite map image. Used by the
//  shareable summary card — SwiftUI `ImageRenderer` cannot rasterize a live
//  `Map`, so the hero image is produced here with `MKMapSnapshotter` and the
//  route is stroked on top with Core Graphics.
//

import CoreLocation
import MapKit
import UIKit

enum RunRouteSnapshotter {

    private static let routeOrange = UIColor(red: 1.0, green: 0.45, blue: 0.13, alpha: 1)
    private static let startGreen = UIColor(red: 0.46, green: 0.84, blue: 0.66, alpha: 1)
    private static let finishRed = UIColor(red: 1.0, green: 0.34, blue: 0.10, alpha: 1)

    static func snapshot(
        coordinates: [CLLocationCoordinate2D],
        size: CGSize
    ) async -> UIImage? {
        guard coordinates.count >= 2 else { return nil }

        let options = MKMapSnapshotter.Options()
        options.region = boundingRegion(for: coordinates)
        options.size = size
        options.scale = 1
        options.preferredConfiguration = MKHybridMapConfiguration(elevationStyle: .realistic)
        options.pointOfInterestFilter = .excludingAll
        options.traitCollection = UITraitCollection(userInterfaceStyle: .dark)

        let snapshotter = MKMapSnapshotter(options: options)

        let snapshot: MKMapSnapshotter.Snapshot? = await withCheckedContinuation { continuation in
            snapshotter.start(with: DispatchQueue.global(qos: .userInitiated)) { snapshot, _ in
                continuation.resume(returning: snapshot)
            }
        }
        guard let snapshot else { return nil }

        return draw(route: coordinates, on: snapshot, size: size)
    }

    // MARK: - Region

    private static func boundingRegion(
        for coordinates: [CLLocationCoordinate2D]
    ) -> MKCoordinateRegion {
        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude

        for coordinate in coordinates {
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        // 1.6× padding so the path sits inside the frame with breathing room.
        let span = MKCoordinateSpan(
            latitudeDelta: min(max((maxLat - minLat) * 1.6, 0.0030), 160),
            longitudeDelta: min(max((maxLon - minLon) * 1.6, 0.0030), 320)
        )
        return MKCoordinateRegion(center: center, span: span)
    }

    // MARK: - Drawing

    private static func draw(
        route coordinates: [CLLocationCoordinate2D],
        on snapshot: MKMapSnapshotter.Snapshot,
        size: CGSize
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            snapshot.image.draw(at: .zero)

            let points = coordinates.map { snapshot.point(for: $0) }
            let cg = context.cgContext
            cg.setLineCap(.round)
            cg.setLineJoin(.round)

            // Soft wide under-glow.
            cg.setStrokeColor(routeOrange.withAlphaComponent(0.30).cgColor)
            cg.setLineWidth(22)
            strokePath(points, in: cg)

            // Bright crisp core.
            cg.setStrokeColor(routeOrange.cgColor)
            cg.setLineWidth(9)
            strokePath(points, in: cg)

            if let start = points.first {
                drawMarker(at: start, color: startGreen, in: cg)
            }
            if let finish = points.last {
                drawMarker(at: finish, color: finishRed, in: cg)
            }
        }
    }

    private static func strokePath(_ points: [CGPoint], in cg: CGContext) {
        guard let first = points.first else { return }
        cg.beginPath()
        cg.move(to: first)
        for point in points.dropFirst() {
            cg.addLine(to: point)
        }
        cg.strokePath()
    }

    private static func drawMarker(at point: CGPoint, color: UIColor, in cg: CGContext) {
        let outer = CGRect(x: point.x - 14, y: point.y - 14, width: 28, height: 28)
        cg.setFillColor(UIColor.white.cgColor)
        cg.fillEllipse(in: outer)

        let inner = CGRect(x: point.x - 9, y: point.y - 9, width: 18, height: 18)
        cg.setFillColor(color.cgColor)
        cg.fillEllipse(in: inner)
    }
}
