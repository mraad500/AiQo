import Foundation

/// The bridge between the chat pipeline and the directive subsystem.
///
/// When the user teaches a standing instruction it must do three things at
/// once: be **saved** durably (DirectiveStore → SwiftData), be **remembered**
/// so the Captain confirms it and recalls it in future chats (mirrored into
/// MemoryStore under the `directive` category — the exact same mechanism the
/// brain already uses to surface `active_record_project` into the prompt's
/// Working Memory layer), and be **executable** (the store the engine reads).
/// This coordinator keeps those three in sync from one call.
@MainActor
final class DirectiveCoordinator {
    static let shared = DirectiveCoordinator()

    /// MemoryStore category that `CaptainCognitivePipeline` always folds into
    /// the Working Memory prompt layer (never relevance-gated), so the Captain
    /// can never "forget" an active standing order.
    static let memoryCategory = "directive"

    private let store: DirectiveStore
    private let memory: MemoryStore

    private init() {
        self.store = .shared
        self.memory = .shared
    }

    private var isGateOpen: Bool {
        DevOverride.unlockAllFeatures || TierGate.shared.canAccess(.captainDirectives)
    }

    // MARK: - Learn

    /// Persists a freshly parsed directive and mirrors it into recallable
    /// memory. Safe to call from the chat Task — it `await`s the actor store
    /// and returns before the prompt is built so the Captain confirms it in
    /// the same reply.
    func learn(draft: LearnedDirectiveDraft) async {
        guard isGateOpen else {
            diag.info("DirectiveCoordinator.learn skipped — TierGate(.captainDirectives)")
            return
        }

        guard let id = await store.upsert(draft: draft) else {
            diag.warning("DirectiveCoordinator.learn — store.upsert returned nil")
            return
        }

        memory.set(
            memoryKey(for: draft.trigger),
            value: canonicalDescription(
                trigger: draft.trigger,
                action: draft.action,
                rawInstruction: draft.rawInstruction,
                localeCode: draft.localeCode
            ),
            category: Self.memoryCategory,
            source: "user_explicit",
            confidence: 0.95
        )

        await BrainBus.shared.publish(.directiveLearned(id))
        diag.info("DirectiveCoordinator learned directive trigger=\(draft.trigger.rawValue) action=\(draft.action.rawValue)")

        // Wire the offline execution arm for time-based triggers: a repeating
        // daily notification so an "every morning / before bedtime" standing
        // order actually fires even if the app is never reopened.
        await DirectiveNotificationScheduler.reschedule(
            directives: await store.activeDirectives(),
            personalization: CaptainPersonalizationStore.shared.currentSnapshot(),
            requestAuthorization: true
        )
    }

    // MARK: - Hydrate (relaunch)

    /// On launch, reconcile the MemoryStore mirror from the DirectiveStore
    /// source of truth. This guarantees that even if the memory entry was
    /// trimmed/evicted between launches, every still-active standing order is
    /// re-surfaced into the prompt — the directive truly never gets forgotten.
    func hydratePromptMirror() async {
        guard isGateOpen else { return }

        let active = await store.activeDirectives()

        // Reconcile repeating directive notifications from the source of truth
        // (survives relaunch / reinstall, and self-heals any future
        // enable/disable/delete). Runs even when empty so stale requests are
        // cleared. Never prompts for permission on cold launch.
        await DirectiveNotificationScheduler.reschedule(
            directives: active,
            personalization: CaptainPersonalizationStore.shared.currentSnapshot(),
            requestAuthorization: false
        )

        guard !active.isEmpty else { return }

        for snapshot in active {
            memory.set(
                memoryKey(for: snapshot.trigger),
                value: canonicalDescription(
                    trigger: snapshot.trigger,
                    action: snapshot.action,
                    rawInstruction: snapshot.rawInstruction,
                    localeCode: snapshot.localeCode
                ),
                category: Self.memoryCategory,
                source: "user_explicit",
                confidence: 0.95
            )
        }
        diag.info("DirectiveCoordinator hydrated \(active.count) standing directive(s) into prompt mirror")
    }

    // MARK: - Helpers

    private func memoryKey(for trigger: DirectiveTrigger) -> String {
        "standing_directive_\(trigger.rawValue)"
    }

    /// A compact, instruction-style line the Captain reads in Working Memory.
    /// It states the standing order and how it is honored. Executable triggers
    /// fire automatically (engine / scheduled notification), so the Captain
    /// confirms the auto-execution. Recognized-but-not-yet-wired triggers
    /// (`isExecutable == false`) are still saved and surfaced — but the Captain
    /// must NOT claim a background auto-fire it can't perform; it honors them
    /// inside the conversation instead. Either way it never forgets or refuses.
    private func canonicalDescription(
        trigger: DirectiveTrigger,
        action: DirectiveAction,
        rawInstruction: String,
        localeCode: String
    ) -> String {
        if localeCode == "en" {
            let execLine = trigger.isExecutable
                ? "This is already running automatically \(trigger.displayEn) — confirm you'll keep doing it, never claim you can't."
                : "This isn't on an automatic background schedule yet, so honor it inside the conversation: raise it yourself when \(trigger.displayEn) is relevant. Promise to keep it in mind and never forget it — but don't claim it fires as an automatic notification."
            return """
            Standing order from the user (\(trigger.rawValue)): \(action.displayEn). \
            Original words: "\(rawInstruction)". \
            \(execLine)
            """
        }
        let execLine = trigger.isExecutable
            ? "هذا منفّذ تلقائياً \(trigger.displayAr) فعلاً — أكّد للمستخدم إنك راح تستمر تسويه ولا تنساه ولا تقول ما تكدر."
            : "هذا لسّه مو مجدول تلقائياً بالخلفية، فنفّذه داخل المحادثة: ذكّر بيه بنفسك لمن يجي وقته (\(trigger.displayAr)). أكّد للمستخدم إنك راح تتذكره ولا تنساه — بس لا تقول إنه يوصل كإشعار تلقائي."
        return """
        تعليمات دائمة من المستخدم (\(trigger.displayAr)): \(action.displayAr). \
        نص المستخدم: «\(rawInstruction)». \
        \(execLine)
        """
    }
}
