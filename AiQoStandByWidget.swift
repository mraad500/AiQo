import Foundation
import SwiftData
import SwiftUI
import WidgetKit

// Architecture drop-in:
// Move this file into the widget extension target once shared SwiftData models
// `PlayerStats` and `QuestStage` are available to the extension target.

@available(iOS 17.0, *)
private struct AiQoStandByEntry: TimelineEntry {
    let date: Date
    let totalAura: Double
    let stageNumber: Int?
    let stageTitle: String?
    let whisper: String

    static let placeholder = AiQoStandByEntry(
        date: .now,
        totalAura: 420,
        stageNumber: 4,
        stageTitle: "Ascension",
        whisper: "Rest well Captain, Stage 4 awaits tomorrow."
    )
}

@available(iOS 17.0, *)
private struct AiQoStandBySnapshot {
    let totalAura: Double
    let stageNumber: Int?
    let stageTitle: String?
}

@available(iOS 17.0, *)
@ModelActor
private actor AiQoStandByModelActor {
    func fetchSnapshot() throws -> AiQoStandBySnapshot {
        let stats = try modelContext.fetch(FetchDescriptor<PlayerStats>())
        let stages = try modelContext.fetch(FetchDescriptor<QuestStage>())

        let totalAura = stats.max(by: { lhs, rhs in
            Self.timestamp(from: lhs) < Self.timestamp(from: rhs)
        }).flatMap {
            Self.doubleValue(in: $0, keys: ["totalAura", "aura", "currentAura"])
        } ?? 0

        let currentStage = stages.first(where: {
            Self.boolValue(in: $0, keys: ["isCurrent", "current", "isActive"]) == true
        }) ?? stages.max(by: { lhs, rhs in
            Self.stageNumber(from: lhs) < Self.stageNumber(from: rhs)
        })

        return AiQoStandBySnapshot(
            totalAura: totalAura,
            stageNumber: currentStage.flatMap { Self.stageNumber(from: $0) },
            stageTitle: currentStage.flatMap { Self.stringValue(in: $0, keys: ["title", "name", "label"]) }
        )
    }

    private static func stageNumber(from value: Any) -> Int? {
        intValue(in: value, keys: ["stageIndex", "stageNumber", "number", "index"])
    }

    private static func timestamp(from value: Any) -> Date {
        dateValue(in: value, keys: ["updatedAt", "lastUpdatedAt", "modifiedAt", "createdAt"]) ?? .distantPast
    }

    private static func stringValue(in value: Any, keys: [String]) -> String? {
        let mirror = Mirror(reflecting: value)

        for child in mirror.children {
            guard let label = child.label, keys.contains(label) else { continue }
            if let string = child.value as? String, !string.isEmpty {
                return string
            }
        }

        return nil
    }

    private static func doubleValue(in value: Any, keys: [String]) -> Double? {
        let mirror = Mirror(reflecting: value)

        for child in mirror.children {
            guard let label = child.label, keys.contains(label) else { continue }

            switch child.value {
            case let value as Double:
                return value
            case let value as Int:
                return Double(value)
            default:
                continue
            }
        }

        return nil
    }

    private static func intValue(in value: Any, keys: [String]) -> Int? {
        let mirror = Mirror(reflecting: value)

        for child in mirror.children {
            guard let label = child.label, keys.contains(label) else { continue }

            switch child.value {
            case let value as Int:
                return value
            case let value as Double:
                return Int(value.rounded())
            default:
                continue
            }
        }

        return nil
    }

    private static func boolValue(in value: Any, keys: [String]) -> Bool? {
        let mirror = Mirror(reflecting: value)

        for child in mirror.children {
            guard let label = child.label, keys.contains(label) else { continue }
            return child.value as? Bool
        }

        return nil
    }

    private static func dateValue(in value: Any, keys: [String]) -> Date? {
        let mirror = Mirror(reflecting: value)

        for child in mirror.children {
            guard let label = child.label, keys.contains(label) else { continue }
            return child.value as? Date
        }

        return nil
    }
}

@available(iOS 17.0, *)
private enum AiQoStandByStore {
    static let modelContainer: ModelContainer = {
        do {
            return try ModelContainer(for: PlayerStats.self, QuestStage.self)
        } catch {
            fatalError("Failed to create SwiftData container for AiQo StandBy widget: \(error)")
        }
    }()

    static let reader = AiQoStandByModelActor(modelContainer: modelContainer)

    static func loadEntry(for date: Date) async -> AiQoStandByEntry {
        do {
            let snapshot = try await reader.fetchSnapshot()
            let stagePhrase: String

            if let stageNumber = snapshot.stageNumber {
                stagePhrase = "Stage \(stageNumber)"
            } else {
                stagePhrase = "your next stage"
            }

            return AiQoStandByEntry(
                date: date,
                totalAura: snapshot.totalAura,
                stageNumber: snapshot.stageNumber,
                stageTitle: snapshot.stageTitle,
                whisper: "Rest well Captain, \(stagePhrase) awaits tomorrow."
            )
        } catch {
            return AiQoStandByEntry(
                date: date,
                totalAura: 0,
                stageNumber: nil,
                stageTitle: nil,
                whisper: "Rest well Captain, the ledger will return by sunrise."
            )
        }
    }
}

@available(iOS 17.0, *)
struct AiQoStandByProvider: TimelineProvider {
    func placeholder(in context: Context) -> AiQoStandByEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (AiQoStandByEntry) -> Void) {
        Task {
            completion(await AiQoStandByStore.loadEntry(for: .now))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AiQoStandByEntry>) -> Void) {
        Task {
            let now = Date()
            let entry = await AiQoStandByStore.loadEntry(for: now)
            let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: now) ?? now.addingTimeInterval(1800)
            completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
        }
    }
}

@available(iOS 17.0, *)
struct AiQoStandByWidgetView: View {
    let entry: AiQoStandByEntry
    @Environment(\.widgetFamily) private var family

    private let mint = Color(red: 0.72, green: 0.92, blue: 0.86)
    private let beige = Color(red: 0.94, green: 0.89, blue: 0.82)
    private let ink = Color(red: 0.14, green: 0.19, blue: 0.18)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    mint.opacity(0.45),
                    beige.opacity(0.62),
                    Color.white.opacity(0.35)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(mint.opacity(0.22))
                .blur(radius: 28)
                .offset(x: -90, y: -50)

            Circle()
                .fill(beige.opacity(0.30))
                .blur(radius: 34)
                .offset(x: 120, y: 70)

            glassCard
                .padding(family == .systemLarge ? 20 : 16)
        }
        .containerBackground(for: .widget) {
            Color.clear
        }
    }

    private var glassCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("SUBCONSCIOUS PREP")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(ink.opacity(0.65))
                        .tracking(1.1)

                    Text("Aura \(Int(entry.totalAura.rounded()))")
                        .font(.system(size: family == .systemLarge ? 38 : 30, weight: .bold, design: .rounded))
                        .foregroundStyle(ink)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(entry.stageNumber.map { "Stage \($0)" } ?? "No Stage")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(ink)

                    if let stageTitle = entry.stageTitle {
                        Text(stageTitle)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(ink.opacity(0.62))
                            .multilineTextAlignment(.trailing)
                    }
                }
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 10) {
                Text("Tomorrow’s whisper")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(ink.opacity(0.64))

                Text(entry.whisper)
                    .font(.system(size: family == .systemLarge ? 22 : 18, weight: .medium, design: .rounded))
                    .foregroundStyle(ink)
                    .lineLimit(3)
            }

            HStack(spacing: 10) {
                Capsule(style: .continuous)
                    .fill(mint.opacity(0.55))
                    .frame(width: 58, height: 8)

                Capsule(style: .continuous)
                    .fill(beige.opacity(0.72))
                    .frame(width: 26, height: 8)
            }
        }
        .padding(22)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.42), lineWidth: 1)
        )
        .shadow(color: ink.opacity(0.08), radius: 18, x: 0, y: 10)
    }
}

@available(iOS 17.0, *)
struct AiQoStandByWidget: Widget {
    let kind = "AiQoStandByWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AiQoStandByProvider()) { entry in
            AiQoStandByWidgetView(entry: entry)
        }
        .configurationDisplayName("AiQo StandBy Aura")
        .description("A calm nightstand widget with Aura status and tomorrow’s subconscious whisper.")
        .supportedFamilies([.systemLarge])
    }
}
