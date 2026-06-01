import Foundation
import ManagedSettings
import FamilyControls
import os

/// Applies / clears the Kernel app shield through a single **named**
/// `ManagedSettingsStore` so the app and every extension shield through the same
/// store. Compiled into the app **and** all three extensions (next to
/// `KernelSharedStore`).
///
/// Decode-safety is the rule here: `applyShield()` NEVER writes an empty shield
/// over an existing one when the selection fails to decode or comes back empty —
/// a transient read glitch must not silently tear down the user's protection.
final class KernelShieldController: @unchecked Sendable {
    static let shared = KernelShieldController()

    /// One named store shared across processes by its name.
    private let managed = ManagedSettingsStore(named: ManagedSettingsStore.Name("aiqo.kernel"))
    private let store = KernelSharedStore.shared
    private let log = Logger(subsystem: "com.mraad500.aiqo.kernel", category: "Shield")

    /// Decode the persisted `FamilyActivitySelection` and shield exactly those
    /// tokens. CRITICAL: if the decode fails, or yields an unexpectedly empty
    /// selection, log and return WITHOUT writing — never clobber an existing
    /// shield on a glitch.
    func applyShield() {
        guard let data = store.selectionData else {
            log.notice("applyShield: no selection stored — skipping")
            return
        }
        guard let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
            log.error("applyShield: selection decode FAILED — refusing to write empty shield")
            return
        }
        let apps = selection.applicationTokens
        let categories = selection.categoryTokens
        let webs = selection.webDomainTokens
        guard !(apps.isEmpty && categories.isEmpty && webs.isEmpty) else {
            log.error("applyShield: decoded selection empty — refusing to clobber existing shield")
            return
        }

        managed.shield.applications = apps
        managed.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories)
        managed.shield.webDomains = webs.isEmpty ? nil : webs
        let dayKey = store.todayKey()   // computed outside the lock (pure Calendar math)
        store.mutate {
            // Stamp the step-baseline only on a fresh lock transition so redundant
            // re-applies don't reset the user's walk progress — and, in the same
            // transition, advance the escalation counter (shield N → N+1). Daily-reset
            // inline so the first shield of a new day starts the ramp at 1.
            if !$0.isLocked {
                $0.unlockBaselineAt = Date()
                if $0.shieldsTriggeredDayKey != dayKey {
                    $0.shieldsTriggeredDayKey = dayKey
                    $0.shieldsTriggeredToday = 0
                }
                $0.shieldsTriggeredToday += 1
            }
            $0.isLocked = true
        }
        log.notice("applyShield: apps=\(apps.count, privacy: .public) cats=\(categories.count, privacy: .public) webs=\(webs.count, privacy: .public)")
    }

    /// Lift the shield entirely.
    func clearShield() {
        managed.shield.applications = nil
        managed.shield.applicationCategories = nil
        managed.shield.webDomains = nil
        store.mutate { $0.isLocked = false }
        log.notice("clearShield: shield lifted")
    }

    /// Re-shield guard shared by all three re-shield layers (app on foreground,
    /// monitor on interval-end, shield extension on open). Re-applies the shield
    /// once a temporary unlock window has expired. Idempotent + decode-safe; does
    /// nothing unless an unlock window is actually open and past its expiry.
    func reshieldIfNeeded() {
        let s = store.load()
        guard s.isProtectionEnabled, s.isUnlocked, let expiry = s.unlockExpiry else { return }
        guard Date() >= expiry else { return }
        applyShield()
        store.mutate { $0.isUnlocked = false; $0.unlockExpiry = nil }
        log.notice("reshieldIfNeeded: unlock expired — re-shielded")
    }
}
