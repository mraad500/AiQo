import Foundation

/// Remote + local decision gate for the proactive NotificationBrain pipeline.
///
/// Mirrors `MemoryV4Gate`: read sites use this instead of
/// `FeatureFlags.notificationBrainEnabled` directly so the remote kill switch is
/// always respected. `NOTIFICATION_BRAIN_ENABLED` shipped ON to real TestFlight
/// users; this gate lets the kill switch be flipped live (Supabase row) without
/// an App Store release.
///
/// Precedence (first that fires wins):
///   1. Remote kill switch — `RemoteFlags.shared.notificationBrainGloballyDisabled`.
///   2. Info.plist feature flag — `FeatureFlags.notificationBrainEnabled`.
///
/// Fail-safe: the remote default is "not disabled", so a missing row, a 404/500,
/// or an offline launch leaves the feature behaving exactly as the Info.plist
/// flag dictates — the offline experience is never broken.
enum NotificationBrainGate {
    static var isOn: Bool {
        if RemoteFlags.shared.notificationBrainGloballyDisabled { return false }
        return FeatureFlags.notificationBrainEnabled
    }
}

/// Remote + local decision gate for Captain Brain V2 features (trend synthesis,
/// contextual prediction, the quality-regeneration loop). Same pattern and same
/// fail-safe as `NotificationBrainGate` — lets Brain V2 be disabled live if it
/// misbehaves for the real users it already shipped to.
///
/// Precedence (first that fires wins):
///   1. Remote kill switch — `RemoteFlags.shared.captainBrainV2GloballyDisabled`.
///   2. Info.plist feature flag — `FeatureFlags.brainV2Enabled` (`CAPTAIN_BRAIN_V2_ENABLED`).
enum CaptainBrainV2Gate {
    static var isOn: Bool {
        if RemoteFlags.shared.captainBrainV2GloballyDisabled { return false }
        return FeatureFlags.brainV2Enabled
    }
}
