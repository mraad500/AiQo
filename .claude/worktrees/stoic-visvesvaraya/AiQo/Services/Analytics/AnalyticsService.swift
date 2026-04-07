import Foundation
import UIKit

// MARK: - Analytics Provider Protocol

/// أي backend تحليلي (PostHog, Mixpanel, Firebase, …) يطبّق هالبروتوكول
protocol AnalyticsProvider {
    func track(_ event: AnalyticsEvent)
    func identify(userId: String, traits: [String: Any])
    func reset()
}

// MARK: - Analytics Service

/// الخدمة الرئيسية للتحليلات — singleton تنادي كل الـ providers المسجلين
@MainActor
final class AnalyticsService {
    static let shared = AnalyticsService()

    private var providers: [AnalyticsProvider] = []
    private var superProperties: [String: Any] = [:]
    private var userId: String?

    private init() {
        // تسجيل الـ provider الافتراضي (console للتطوير + local storage)
        #if DEBUG
        providers.append(ConsoleAnalyticsProvider())
        #endif
        providers.append(LocalAnalyticsProvider())

        collectDeviceProperties()
    }

    // MARK: - Provider Management

    func register(provider: AnalyticsProvider) {
        providers.append(provider)
    }

    // MARK: - Tracking

    func track(_ event: AnalyticsEvent) {
        var enrichedProperties = superProperties
        for (key, value) in event.properties {
            enrichedProperties[key] = value
        }
        enrichedProperties["timestamp"] = ISO8601DateFormatter().string(from: Date())

        let enrichedEvent = AnalyticsEvent(event.name, properties: enrichedProperties)

        for provider in providers {
            provider.track(enrichedEvent)
        }
    }

    func identify(userId: String, traits: [String: Any] = [:]) {
        self.userId = userId
        superProperties["user_id"] = userId

        for provider in providers {
            provider.identify(userId: userId, traits: traits)
        }
    }

    func reset() {
        userId = nil
        superProperties.removeAll()
        collectDeviceProperties()

        for provider in providers {
            provider.reset()
        }
    }

    // MARK: - Super Properties

    func setSuperProperty(_ key: String, value: Any) {
        superProperties[key] = value
    }

    // MARK: - Device Info

    private func collectDeviceProperties() {
        let device = UIDevice.current
        superProperties["device_model"] = deviceModel()
        superProperties["os_version"] = device.systemVersion
        superProperties["app_version"] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        superProperties["build_number"] = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        superProperties["locale"] = Locale.current.identifier
        superProperties["timezone"] = TimeZone.current.identifier
    }

    private func deviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingCString: $0) ?? "unknown"
            }
        }
    }
}

// MARK: - Console Provider (DEBUG only)

struct ConsoleAnalyticsProvider: AnalyticsProvider {
    func track(_ event: AnalyticsEvent) {
        let props = event.properties
            .filter { $0.key != "timestamp" }
            .map { "\($0.key)=\($0.value)" }
            .sorted()
            .joined(separator: ", ")

        print("📊 [Analytics] \(event.name)\(props.isEmpty ? "" : " | \(props)")")
    }

    func identify(userId: String, traits: [String: Any]) {
        print("📊 [Analytics] identify: \(userId)")
    }

    func reset() {
        print("📊 [Analytics] reset")
    }
}

// MARK: - Local Provider (stores events for later export / dashboards)

final class LocalAnalyticsProvider: AnalyticsProvider {
    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.aiqo.analytics.local", qos: .utility)
    private let maxEvents = 5000

    init() {
        let baseDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = baseDir.appendingPathComponent("Analytics", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("events.jsonl")
    }

    func track(_ event: AnalyticsEvent) {
        queue.async { [fileURL, maxEvents] in
            var record: [String: Any] = ["event": event.name]
            record["properties"] = event.properties.compactMapValues { value -> Any? in
                // JSON-safe values only
                if value is String || value is Int || value is Double || value is Bool {
                    return value
                }
                return String(describing: value)
            }

            guard let data = try? JSONSerialization.data(withJSONObject: record),
                  let line = String(data: data, encoding: .utf8) else { return }

            if let handle = try? FileHandle(forWritingTo: fileURL) {
                handle.seekToEndOfFile()
                handle.write(Data((line + "\n").utf8))
                handle.closeFile()
            } else {
                try? Data((line + "\n").utf8).write(to: fileURL, options: .atomic)
            }

            // Trim old events
            Self.trimIfNeeded(fileURL: fileURL, maxEvents: maxEvents)
        }
    }

    func identify(userId: String, traits: [String: Any]) {
        var merged = traits
        merged["user_id"] = userId
        track(AnalyticsEvent("$identify", properties: merged))
    }

    func reset() {
        queue.async { [fileURL] in
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    private static func trimIfNeeded(fileURL: URL, maxEvents: Int) {
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { return }
        var lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
        if lines.count > maxEvents {
            lines = Array(lines.suffix(maxEvents))
            try? lines.joined(separator: "\n").appending("\n").write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }

    /// Returns all stored events as array of dictionaries (for debugging / export)
    func exportEvents() -> [[String: Any]] {
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { return [] }
        return content
            .components(separatedBy: "\n")
            .filter { !$0.isEmpty }
            .compactMap { line in
                guard let data = line.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
                return json
            }
    }
}
