import Foundation
import FamilyControls
import UserNotifications

/// The awareness + personality bridge between «النواة» (Kernel) and Captain
/// Hamoudi's brain. App-target only (it reaches the Captain notification brain +
/// app-only stores, which the extensions can't see).
///
/// Three jobs:
///  1. **Chat awareness** — `contextLine()` builds a compact, privacy-safe Kernel
///     status the Captain context-builder injects into the chat prompt, so the
///     Captain can answer "شلون نواتي؟" with real numbers. NEVER includes app
///     identities/tokens — counts and states only.
///  2. **Live-trainer copy** — ready-made Iraqi/English encouragement banks for the
///     in-app challenge session (intro → start/25/50/75/almost → celebration →
///     "next is harder" → "enough for today"). All local strings; the view speaks
///     them through Apple on-device TTS (`.realtime`) — ZERO cloud in the loop.
///  3. **Notifications** — fires shield-dropped / unlocked notifications in the
///     Captain's voice through the existing `NotificationBrain` pipeline (budget +
///     quiet-hours + privacy), falling back to a plain local notification when the
///     notification brain is off so the user still hears from the Captain.
///
/// No fake data: the numbers come from `KernelSharedStore` / the real mining loop.
enum KernelCaptainBridge {

    // MARK: - 1. Chat awareness (compact, privacy-safe)

    /// A single language-neutral line (English keys + numbers, mirroring the
    /// bio-state layer) describing the user's Kernel state for the chat prompt, or
    /// `nil` when the feature is off entirely. The Captain layer wraps this with a
    /// bilingual header. Privacy: counts/states only — never app names or tokens.
    @MainActor
    static func contextLine() -> String? {
        guard FeatureFlags.kernelEnabled else { return nil }
        let store = KernelSharedStore.shared
        let state = store.load()
        let energy = UserDefaults.standard.integer(forKey: "aiqo.mining.lastAwardedCoins")

        guard state.isProtectionEnabled else {
            return "state: off (the lock isn't enabled today); energy_today: \(energy)"
        }

        let triggered = store.triggeredTodayCount()
        var parts = [
            "state: on",
            "protected_apps: \(protectedCount(state.selectionData))",
            "shields_today: \(triggered)",
            "opened_today: \(store.openedTodayCount())",
            "energy_today: \(energy)"
        ]
        if state.isLocked, let challenge = state.activeChallenge {
            let enough = KernelEscalation.isEnoughForToday(shield: max(1, triggered))
            parts.append("status: \(enough ? "locked_enough_for_today" : "locked")(needs \(challenge.stepTarget) steps)")
        } else if let minutes = openSessionMinutesLeft(state) {
            parts.append("status: open(session ~\(minutes)m left)")
        } else {
            parts.append("status: armed(no shield active right now)")
        }
        return parts.joined(separator: ", ")
    }

    /// Token count of the chosen selection (apps + categories + web domains). Just a
    /// number — the tokens themselves never leave `KernelSharedStore`.
    private static func protectedCount(_ data: Data?) -> Int {
        guard let data,
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else { return 0 }
        return selection.applicationTokens.count
            + selection.categoryTokens.count
            + selection.webDomainTokens.count
    }

    private static func openSessionMinutesLeft(_ state: KernelState) -> Int? {
        guard state.isUnlocked, let expiry = state.unlockExpiry, expiry > Date() else { return nil }
        return max(1, Int(expiry.timeIntervalSinceNow / 60) + 1)
    }

    // MARK: - 2. Live-trainer copy (local phrase banks)

    /// Where the user is in the live challenge — drives which encouragement fires.
    enum Milestone: Int, CaseIterable { case start, quarter, half, threeQuarter, almost }

    /// The Captain's opening line when the trainer card appears.
    static func introLine(target: Int, language: AppLanguage) -> String {
        language == .arabic
            ? "كمّل هذا التحدي وأفتحلك الدرع — \(target) خطوة وأني وياك 💪"
            : "Finish this and I'll open the shield — \(target) steps, I'm with you 💪"
    }

    /// Short milestone encouragement (ready-made, no network).
    static func encouragement(_ milestone: Milestone, language: AppLanguage) -> String {
        pick(milestone == .start ? startBank(language)
            : milestone == .quarter ? quarterBank(language)
            : milestone == .half ? halfBank(language)
            : milestone == .threeQuarter ? threeQuarterBank(language)
            : almostBank(language))
    }

    /// The one-moment celebration line when the shield opens.
    static func celebrationLine(language: AppLanguage) -> String {
        pick(language == .arabic
            ? ["انفتح! 🔋 جسمك هو المفتاح", "كفو بطل — فتحتها بنفسك 💪", "هذا اللي أقصده 🔥"]
            : ["Open! 🔋 your body is the key", "That's my champ — you earned it 💪", "Exactly what I mean 🔥"])
    }

    /// Honest heads-up that the next shield costs more — reads `KernelEscalation`.
    static func nextShieldHint(nextSteps: Int, language: AppLanguage) -> String {
        language == .arabic
            ? "الدرع الجاي أصعب شوي — \(nextSteps) خطوة. مو مشكلة، إنت تكدر 👊"
            : "Next shield's a bit harder — \(nextSteps) steps. No worries, you've got it 👊"
    }

    /// The Captain leads the "enough for today" moment (shield ≥ 5).
    static func enoughForTodayLead(language: AppLanguage) -> String {
        language == .arabic
            ? "كافي اليوم — عقلك ارتاح كفاية، تعال باچر 🌙"
            : "Enough for today — your mind's had its rest, come back tomorrow 🌙"
    }

    // MARK: - 3. Notifications (Captain voice, via the existing brain)

    /// Reframed unlock notification ("you moved, so it opened"). Always delivers
    /// (transactional) — through `NotificationBrain` when on, else a plain local one.
    @MainActor
    static func sendUnlockNotification() {
        guard FeatureFlags.kernelEnabled else { return }
        let language = AppSettingsStore.shared.appLanguage
        let title = captainName(language)
        let body = pick(language == .arabic
            ? ["تحركت فانفتح — نواتك اتشحنت 🔋", "كفو! مشيت وفتحتها بنفسك 💪", "جسمك فتح القفل — هذا اللي أقصده 🔋"]
            : ["You moved, so it opened — kernel charged 🔋", "Nice! You walked it open yourself 💪", "Your body unlocked it — respect 🔋"])
        deliver(title: title, body: body, kind: .achievementUnlocked, source: "kernel.unlock", identifier: "aiqo.kernel.unlocked")
    }

    /// New-shield-dropped notification in the Captain's voice. Fired once per fresh
    /// shield by `KernelBioEngine` (de-duped there).
    @MainActor
    static func sendShieldDroppedNotification(shield: Int) {
        guard FeatureFlags.kernelEnabled else { return }
        let language = AppSettingsStore.shared.appLanguage
        let title = captainName(language)
        let body = pick(language == .arabic
            ? ["نزل درع جديد — تعال نتمشّى ونفكّه سوا 🌙", "وكّفنا شوي... درع جديد. تحرّك تفتحه 💪", "صار وكت نتحرك — درعك ينتظرك"]
            : ["New shield is up — let's walk it off together 🌙", "Pause a sec… a shield dropped. Move to open it 💪", "Time to move — your shield is waiting"])
        deliver(title: title, body: body, kind: .inactivityNudge, source: "kernel.shieldDropped", identifier: "aiqo.kernel.shieldDropped")
    }

    // MARK: - Notification plumbing

    private static func captainName(_ language: AppLanguage) -> String {
        language == .arabic ? "كابتن حمودي" : "Captain Hamoudi"
    }

    /// Route through the existing Captain `NotificationBrain` (budget + quiet hours +
    /// privacy) when it's enabled; otherwise post a plain local notification so the
    /// user still hears from the Captain. Reuses existing `NotificationKind`s +
    /// precomposed copy — no changes to the notification taxonomy.
    @MainActor
    private static func deliver(title: String, body: String, kind: NotificationKind, source: String, identifier: String) {
        if FeatureFlags.notificationBrainEnabled {
            let intent = NotificationIntent(kind: kind, priority: .high, requestedBy: source)
            Task {
                _ = await NotificationBrain.shared.request(
                    intent,
                    precomposedTitle: title,
                    precomposedBody: body,
                    userInfo: ["source": source],
                    identifier: identifier
                )
            }
        } else {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            UNUserNotificationCenter.current().add(
                UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
            )
        }
    }

    // MARK: - Phrase banks (Iraqi / English)

    private static func pick(_ options: [String]) -> String { options.randomElement() ?? "" }

    private static func startBank(_ l: AppLanguage) -> [String] {
        l == .arabic ? ["يالله نبدأ — خطوة خطوة 💪", "أني وياك، تحرّك"] : ["Let's go — one step at a time 💪", "I'm with you, move"]
    }
    private static func quarterBank(_ l: AppLanguage) -> [String] {
        l == .arabic ? ["ربع الطريق — استمر", "شد حيلك، ماشي زين"] : ["A quarter in — keep going", "Push, you're doing great"]
    }
    private static func halfBank(_ l: AppLanguage) -> [String] {
        l == .arabic ? ["نصها خلصت! 🔥", "نص الطريق — لا توقف"] : ["Halfway there! 🔥", "Half done — don't stop"]
    }
    private static func threeQuarterBank(_ l: AppLanguage) -> [String] {
        l == .arabic ? ["٣ أرباع! قرّبت", "باقي شوية بس"] : ["Three quarters! almost there", "Just a little more"]
    }
    private static func almostBank(_ l: AppLanguage) -> [String] {
        l == .arabic ? ["آخر دفعة — لا تستسلم!", "قرّبت توصل، يالله 🔥"] : ["Last push — don't quit!", "Almost there, come on 🔥"]
    }
}
