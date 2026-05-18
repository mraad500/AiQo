//
//  RunRecordStore.swift
//  AiQo
//
//  On-device persistence for finished Outdoor Runs so the route map + stats
//  summary can be reopened later from the History ("الأثر") screen. The route
//  only exists in memory during the run, and is never written to HealthKit, so
//  this is the single source of truth for replaying a past run's map. Stored as
//  a local JSON file (Application Support) — nothing leaves the device.
//

import CoreLocation
import Foundation

struct RunRouteCoordinate: Codable {
    let lat: Double
    let lon: Double

    init(_ coordinate: CLLocationCoordinate2D) {
        lat = coordinate.latitude
        lon = coordinate.longitude
    }

    var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

struct RunRecord: Codable, Identifiable {
    let id: UUID
    let title: String
    let startedAt: Date
    let finishedAt: Date
    let distanceMeters: Double
    let elapsedSeconds: Int
    let averagePaceSecondsPerKm: Double?
    let elevationGainMeters: Double
    let calories: Double
    let averageHeartRate: Double
    let route: [RunRouteCoordinate]

    var routeCoordinates: [CLLocationCoordinate2D] {
        route.map(\.clCoordinate)
    }
}

/// Everything `RunSummaryView` needs, sourced either from a saved on-device
/// run (with its GPS route) or, when no route was recorded, from the workout's
/// own HealthKit stats so the cinematic summary still opens with real numbers.
struct RunSummaryInput: Identifiable {
    let id = UUID()
    let title: String
    let distanceMeters: Double
    let elapsedSeconds: Int
    let averagePaceSecondsPerKm: Double?
    let elevationGainMeters: Double
    let calories: Double
    let averageHeartRate: Double
    let routeCoordinates: [CLLocationCoordinate2D]
    let finishedAt: Date?

    init(record r: RunRecord) {
        title = r.title
        distanceMeters = r.distanceMeters
        elapsedSeconds = r.elapsedSeconds
        averagePaceSecondsPerKm = r.averagePaceSecondsPerKm
        elevationGainMeters = r.elevationGainMeters
        calories = r.calories
        averageHeartRate = r.averageHeartRate
        routeCoordinates = r.routeCoordinates
        finishedAt = r.finishedAt
    }

    init(
        title: String,
        distanceMeters: Double,
        elapsedSeconds: Int,
        calories: Double,
        averageHeartRate: Double,
        finishedAt: Date?
    ) {
        self.title = title
        self.distanceMeters = distanceMeters
        self.elapsedSeconds = elapsedSeconds
        self.averagePaceSecondsPerKm = (distanceMeters > 0 && elapsedSeconds > 0)
            ? Double(elapsedSeconds) / (distanceMeters / 1000.0)
            : nil
        self.elevationGainMeters = 0
        self.calories = calories
        self.averageHeartRate = averageHeartRate
        self.routeCoordinates = []
        self.finishedAt = finishedAt
    }
}

@MainActor
final class RunRecordStore {
    static let shared = RunRecordStore()

    private let maxRecords = 50
    private let fileURL: URL
    private var cache: [RunRecord]?

    private init() {
        let directory = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        fileURL = directory.appendingPathComponent("aiqo_run_records.json")
    }

    func save(_ record: RunRecord) {
        var records = load()
        records.insert(record, at: 0)
        if records.count > maxRecords {
            records = Array(records.prefix(maxRecords))
        }
        persist(records)
    }

    /// The saved run that best matches a workout starting at `date`. The phone
    /// (run start) and the watch-saved `HKWorkout` start can drift by launch
    /// latency, so we accept a run if the workout start is near its start OR
    /// falls within its time span, then pick the closest. The window is wide
    /// enough to absorb skew yet still resolves to the nearest run when several
    /// exist the same day.
    func record(matchingStart date: Date, tolerance: TimeInterval = 600) -> RunRecord? {
        load()
            .filter { record in
                abs(record.startedAt.timeIntervalSince(date)) <= tolerance
                    || (date >= record.startedAt.addingTimeInterval(-tolerance)
                        && date <= record.finishedAt.addingTimeInterval(tolerance))
            }
            .min {
                abs($0.startedAt.timeIntervalSince(date))
                    < abs($1.startedAt.timeIntervalSince(date))
            }
    }

    private func load() -> [RunRecord] {
        if let cache { return cache }
        guard let data = try? Data(contentsOf: fileURL) else {
            cache = []
            return []
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let records = (try? decoder.decode([RunRecord].self, from: data)) ?? []
        cache = records
        return records
    }

    private func persist(_ records: [RunRecord]) {
        cache = records
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(records) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
