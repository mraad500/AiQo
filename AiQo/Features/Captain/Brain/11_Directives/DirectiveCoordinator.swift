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
    }

    // MARK: - Hydrate (relaunch)

    /// On launch, reconcile the MemoryStore mirror from the DirectiveStore
    /// source of truth. This guarantees that even if the memory entry was
    /// trimmed/evicted between launches, every still-active standing order is
    /// re-surfaced into the prompt — the directive truly never gets forgotten.
    func hydratePromptMirror() async {
        guard isGateOpen else { return }

        let active = await store.activeDirectives()
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
    /// It states the standing order AND that it is already being executed
    /// automatically, so the Captain confirms instead of re-asking.
    private func canonicalDescription(
        trigger: DirectiveTrigger,
        action: DirectiveAction,
        rawInstruction: String,
        localeCode: String
    ) -> String {
        if localeCode == "en" {
            return """
            Standing order from the user (\(trigger.rawValue)): \(action.displayEn). \
            Original words: "\(rawInstruction)". \
            This is already running automatically after every workout — confirm you'll keep doing it, never claim you can't.
            """
        }
        return """
        تعليمات دائمة من المستخدم (\(trigger.displayAr)): \(action.displayAr). \
        نص المستخدم: «\(rawInstruction)». \
        هذا منفّذ تلقائياً بعد كل تمرين فعلاً — أكّد للمستخدم إنك راح تستمر تسويه ولا تنساه ولا تقول ما تكدر.
        """
    }
}
