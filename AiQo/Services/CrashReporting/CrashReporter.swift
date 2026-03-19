import Foundation
import UIKit

/// نظام تقارير الأعطال — يسجّل الـ crashes والأخطاء الحرجة محلياً
/// ويقدر يرسلهم لأي backend (Sentry, Crashlytics, etc.) لاحقاً
@MainActor
final class CrashReporter {
    static let shared = CrashReporter()

    private let logFileURL: URL
    private let queue = DispatchQueue(label: "com.aiqo.crashreporter", qos: .utility)
    private let maxCrashLogs = 50

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("CrashReports", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        logFileURL = dir.appendingPathComponent("crash_log.jsonl")

        setupExceptionHandling()
        setupSignalHandling()
        checkPreviousCrash()
    }

    // MARK: - Public API

    /// سجّل خطأ غير حرج (non-fatal)
    func recordError(_ error: Error, context: String = "", file: String = #file, line: Int = #line) {
        let entry = CrashEntry(
            type: "non_fatal",
            message: error.localizedDescription,
            context: context,
            file: (file as NSString).lastPathComponent,
            line: line,
            stackTrace: Thread.callStackSymbols,
            timestamp: Date(),
            appVersion: Self.appVersion,
            osVersion: UIDevice.current.systemVersion,
            deviceModel: Self.deviceModel
        )

        persistEntry(entry)

        AnalyticsService.shared.track(.errorOccurred(
            domain: context.isEmpty ? "unknown" : context,
            message: error.localizedDescription
        ))
    }

    /// سجّل خطأ من نص
    func recordError(message: String, context: String = "", file: String = #file, line: Int = #line) {
        let entry = CrashEntry(
            type: "non_fatal",
            message: message,
            context: context,
            file: (file as NSString).lastPathComponent,
            line: line,
            stackTrace: Thread.callStackSymbols,
            timestamp: Date(),
            appVersion: Self.appVersion,
            osVersion: UIDevice.current.systemVersion,
            deviceModel: Self.deviceModel
        )
        persistEntry(entry)
    }

    /// يرجّع كل التقارير المحفوظة (للتصدير أو الإرسال)
    func exportCrashLogs() -> [CrashEntry] {
        guard let content = try? String(contentsOf: logFileURL, encoding: .utf8) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return content
            .components(separatedBy: "\n")
            .filter { !$0.isEmpty }
            .compactMap { line in
                guard let data = line.data(using: .utf8) else { return nil }
                return try? decoder.decode(CrashEntry.self, from: data)
            }
    }

    #if DEBUG
    func clearLogs() {
        try? FileManager.default.removeItem(at: logFileURL)
    }
    #endif

    // MARK: - Setup

    private func setupExceptionHandling() {
        NSSetUncaughtExceptionHandler { exception in
            let entry = CrashEntry(
                type: "crash_exception",
                message: "\(exception.name.rawValue): \(exception.reason ?? "no reason")",
                context: "UncaughtException",
                file: "",
                line: 0,
                stackTrace: exception.callStackSymbols,
                timestamp: Date(),
                appVersion: CrashReporter.appVersion,
                osVersion: UIDevice.current.systemVersion,
                deviceModel: CrashReporter.deviceModel
            )
            CrashReporter.persistEntrySynchronously(entry)
        }
    }

    private func setupSignalHandling() {
        let signals: [Int32] = [SIGABRT, SIGBUS, SIGFPE, SIGILL, SIGSEGV, SIGTRAP]
        for sig in signals {
            signal(sig) { signalNumber in
                let entry = CrashEntry(
                    type: "crash_signal",
                    message: "Signal \(signalNumber)",
                    context: "SignalHandler",
                    file: "",
                    line: 0,
                    stackTrace: Thread.callStackSymbols,
                    timestamp: Date(),
                    appVersion: CrashReporter.appVersion,
                    osVersion: UIDevice.current.systemVersion,
                    deviceModel: CrashReporter.deviceModel
                )
                CrashReporter.persistEntrySynchronously(entry)
                // Re-raise signal for default handler
                signal(signalNumber, SIG_DFL)
                raise(signalNumber)
            }
        }
    }

    /// يفحص إذا كان التطبيق انهار آخر مرة
    private func checkPreviousCrash() {
        let key = "aiqo.crash.didTerminateCleanly"
        let didTerminateCleanly = UserDefaults.standard.bool(forKey: key)

        if !didTerminateCleanly {
            // ممكن التطبيق انهار — نسجل ذلك
            let logs = exportCrashLogs()
            if let lastCrash = logs.last, lastCrash.type.hasPrefix("crash") {
                print("💥 [CrashReporter] Previous crash detected: \(lastCrash.message)")
                AnalyticsService.shared.track(.errorOccurred(
                    domain: "crash",
                    message: "Previous session crash: \(lastCrash.message)"
                ))
            }
        }

        // Mark as unclean — will be set to true on clean termination
        UserDefaults.standard.set(false, forKey: key)

        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            UserDefaults.standard.set(true, forKey: key)
        }
    }

    // MARK: - Persistence

    private func persistEntry(_ entry: CrashEntry) {
        queue.async { [logFileURL, maxCrashLogs] in
            CrashReporter.writeEntry(entry, to: logFileURL, maxEntries: maxCrashLogs)
        }
    }

    /// Synchronous write for crash handlers (can't use async in signal handler)
    private static func persistEntrySynchronously(_ entry: CrashEntry) {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("CrashReports", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileURL = dir.appendingPathComponent("crash_log.jsonl")
        writeEntry(entry, to: fileURL, maxEntries: 50)
    }

    private static func writeEntry(_ entry: CrashEntry, to fileURL: URL, maxEntries: Int) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(entry),
              let line = String(data: data, encoding: .utf8) else { return }

        if let handle = try? FileHandle(forWritingTo: fileURL) {
            handle.seekToEndOfFile()
            handle.write(Data((line + "\n").utf8))
            handle.closeFile()
        } else {
            try? Data((line + "\n").utf8).write(to: fileURL, options: .atomic)
        }

        // Trim
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { return }
        var lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
        if lines.count > maxEntries {
            lines = Array(lines.suffix(maxEntries))
            try? lines.joined(separator: "\n").appending("\n").write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - Helpers

    private static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }

    private static var deviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingCString: $0) ?? "unknown"
            }
        }
    }
}

// MARK: - Crash Entry Model

struct CrashEntry: Codable {
    let type: String          // "crash_exception", "crash_signal", "non_fatal"
    let message: String
    let context: String
    let file: String
    let line: Int
    let stackTrace: [String]
    let timestamp: Date
    let appVersion: String
    let osVersion: String
    let deviceModel: String
}
