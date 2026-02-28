import AppIntents
import Foundation
import SwiftData

// Architecture drop-in:
// Move this file into the app target once shared SwiftData models `PlayerStats`
// and `QuestStage` are available to the target.

@available(iOS 17.0, *)
private struct AuraSnapshot {
    let totalAura: Double
}

@available(iOS 17.0, *)
private struct QuestStageSnapshot {
    let stageNumber: Int
    let title: String?
}

@available(iOS 17.0, *)
@ModelActor
private actor AiQoIntentsModelActor {
    func fetchAuraSnapshot() throws -> AuraSnapshot? {
        let allStats = try modelContext.fetch(FetchDescriptor<PlayerStats>())

        guard let bestMatch = allStats.max(by: { lhs, rhs in
            Self.timestamp(from: lhs) < Self.timestamp(from: rhs)
        }) else {
            return nil
        }

        guard let totalAura = Self.doubleValue(in: bestMatch, keys: ["totalAura", "aura", "currentAura"]) else {
            return nil
        }

        return AuraSnapshot(totalAura: totalAura)
    }

    func fetchCurrentQuestStage() throws -> QuestStageSnapshot? {
        let allStages = try modelContext.fetch(FetchDescriptor<QuestStage>())
        guard !allStages.isEmpty else { return nil }

        let currentStage = allStages.first(where: {
            Self.boolValue(in: $0, keys: ["isCurrent", "current", "isActive"]) == true
        }) ?? allStages.max(by: { lhs, rhs in
            Self.stageNumber(from: lhs) < Self.stageNumber(from: rhs)
        })

        guard let currentStage, let stageNumber = Self.stageNumber(from: currentStage) else {
            return nil
        }

        return QuestStageSnapshot(
            stageNumber: stageNumber,
            title: Self.stringValue(in: currentStage, keys: ["title", "name", "label"])
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
private enum AiQoIntentsStore {
    static let modelContainer: ModelContainer = {
        do {
            return try ModelContainer(for: PlayerStats.self, QuestStage.self)
        } catch {
            fatalError("Failed to create SwiftData container for AiQo intents: \(error)")
        }
    }()

    static let reader = AiQoIntentsModelActor(modelContainer: modelContainer)
}

@available(iOS 17.0, *)
struct CheckAuraIntent: AppIntent {
    static let title: LocalizedStringResource = "Check My Aura"
    static let description = IntentDescription("Ask Captain Hamoudi for your latest Aura reading.")
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            guard let snapshot = try await AiQoIntentsStore.reader.fetchAuraSnapshot() else {
                return .result(dialog: "Captain Hamoudi can’t sense your Aura yet. Open AiQo once to hydrate your SwiftData profile.")
            }

            let roundedAura = Int(snapshot.totalAura.rounded())
            return .result(
                dialog: "Captain Hamoudi says your Aura is \(roundedAura). The field is alive. Protect it tonight."
            )
        } catch {
            return .result(
                dialog: "Captain Hamoudi lost the signal to your Aura archive. Check your local data store and try again."
            )
        }
    }
}

@available(iOS 17.0, *)
struct CurrentQuestStageIntent: AppIntent {
    static let title: LocalizedStringResource = "Current Quest Stage"
    static let description = IntentDescription("Ask Captain Hamoudi which Quest Stage is currently active.")
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            guard let snapshot = try await AiQoIntentsStore.reader.fetchCurrentQuestStage() else {
                return .result(dialog: "Captain Hamoudi can’t find a current Quest Stage yet. Open AiQo once to sync your SwiftData quest ledger.")
            }

            let suffix: String
            if let title = snapshot.title, !title.isEmpty {
                suffix = " \(title)."
            } else {
                suffix = "."
            }

            return .result(
                dialog: "Captain Hamoudi says you are standing at Quest Stage \(snapshot.stageNumber)\(suffix) Stay sharp."
            )
        } catch {
            return .result(
                dialog: "Captain Hamoudi can’t read the quest ledger right now. Check the SwiftData container and ask again."
            )
        }
    }
}

@available(iOS 17.0, *)
struct AiQoCaptainShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        [
            AppShortcut(
                intent: CheckAuraIntent(),
                phrases: [
                    "Check my Aura in \(.applicationName)",
                    "Ask Captain Hamoudi about my Aura in \(.applicationName)",
                    "What is my Aura in \(.applicationName)"
                ],
                shortTitle: "Check Aura",
                systemImageName: "sparkles"
            ),
            AppShortcut(
                intent: CurrentQuestStageIntent(),
                phrases: [
                    "What is my current Quest Stage in \(.applicationName)",
                    "Ask Captain Hamoudi about my Quest Stage in \(.applicationName)",
                    "Check my Quest Stage in \(.applicationName)"
                ],
                shortTitle: "Quest Stage",
                systemImageName: "shield.lefthalf.filled"
            )
        ]
    }
}
