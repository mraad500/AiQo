import Foundation
import os.log

/// Central prompt registry for on-device Foundation Models.
///
/// Apple recommends pinning prompt versions in code so each runtime uses
/// the prompt revision that was validated for that model and OS behavior.
final class AiQoPromptManager {
    static let shared = AiQoPromptManager()

    private enum PromptKey {
        static let zone2CoachV1 = "zone2-coach-v1.0"
        static let zone2CoachV2 = "zone2-coach-v2.0"
    }

    private enum PromptIdentifier {
        static let zone2Coach = "zone2-coach"
    }

    private enum Constants {
        static let promptTableName = "Prompts"
        static let cachedRemoteConfigurationKey = "aiqo.promptManager.cachedRemoteConfiguration"
    }

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "AiQo",
        category: "AiQoPromptManager"
    )
    private let userDefaults: UserDefaults
    private let remoteConfigurationStore: PromptConfigurationStore

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.remoteConfigurationStore = PromptConfigurationStore(
            configuration: Self.loadCachedConfiguration(from: userDefaults)
        )
    }

    /// Returns the Zone 2 coaching prompt version that matches the validated OS runtime.
    func getZone2CoachPrompt() -> String {
        let promptKey: String

        if #available(iOS 26.4, macOS 26.4, visionOS 26.4, *) {
            promptKey = PromptKey.zone2CoachV2
        } else {
            promptKey = PromptKey.zone2CoachV1
        }

        return localizedPrompt(forKey: promptKey)
    }

    /// Placeholder for a future Firebase/Gemini-backed prompt rollout.
    ///
    /// This simulates fetching a remote prompt manifest, then caching it locally
    /// so the app can reuse the latest known configuration while offline.
    func fetchRemotePrompts() async {
        do {
            try await Task.sleep(nanoseconds: 750_000_000)
        } catch {
            logger.debug("remote_prompt_fetch_cancelled")
            return
        }

        let configuration = RemotePromptConfiguration(
            fetchedAt: Date(),
            source: "firebase-gemini-simulation",
            promptKeys: [
                PromptIdentifier.zone2Coach: PromptKey.zone2CoachV2
            ]
        )

        await remoteConfigurationStore.update(with: configuration)
        persist(configuration)

        logger.notice(
            "remote_prompt_fetch_succeeded source=\(configuration.source, privacy: .public)"
        )
    }

    private func localizedPrompt(forKey key: String) -> String {
        NSLocalizedString(
            key,
            tableName: Constants.promptTableName,
            bundle: .main,
            value: key,
            comment: "Versioned prompt entry used by on-device Foundation Models."
        )
    }

    private func persist(_ configuration: RemotePromptConfiguration) {
        do {
            let data = try JSONEncoder().encode(configuration)
            userDefaults.set(data, forKey: Constants.cachedRemoteConfigurationKey)
        } catch {
            logger.error(
                "remote_prompt_cache_persist_failed error=\(error.localizedDescription, privacy: .public)"
            )
        }
    }

    private static func loadCachedConfiguration(
        from userDefaults: UserDefaults
    ) -> RemotePromptConfiguration? {
        guard let data = userDefaults.data(forKey: Constants.cachedRemoteConfigurationKey) else {
            return nil
        }

        do {
            return try JSONDecoder().decode(RemotePromptConfiguration.self, from: data)
        } catch {
            return nil
        }
    }
}

private struct RemotePromptConfiguration: Codable, Sendable {
    let fetchedAt: Date
    let source: String
    let promptKeys: [String: String]
}

private actor PromptConfigurationStore {
    private var configuration: RemotePromptConfiguration?

    init(configuration: RemotePromptConfiguration? = nil) {
        self.configuration = configuration
    }

    func update(with configuration: RemotePromptConfiguration) {
        self.configuration = configuration
    }
}
