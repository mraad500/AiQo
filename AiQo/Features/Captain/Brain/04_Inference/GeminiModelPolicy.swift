import Foundation

/// Single source of truth for which Gemini model a cloud call should use.
///
/// `gemini-3-flash-preview` is a *preview* model — Google can change its
/// behavior, tighten its rate limits, or withdraw it without notice. Binding it
/// directly to the paid Pro tier is therefore a production risk. This policy
/// centralizes the kill switch so every call site (chat, kitchen vision, memory
/// extraction, weekly review) is gated together by `GEMINI_3_PREVIEW_ENABLED`.
///
/// - Flag OFF (default): `reasoning == fast`, so the whole app uses the stable
///   `gemini-2.5-flash` for every tier — no preview call is ever made.
/// - Flag ON: `reasoning == preview`, re-enabling the preview model for the
///   paths that opt into the reasoning model (typically the Pro tier).
///
/// The Supabase Edge Function (`captain-chat`) already whitelists both models,
/// so flipping this flag is purely client-side — no backend deploy required.
enum GeminiModelPolicy {
    /// Always-available stable production model. Also the universal fallback target.
    static let fast = "gemini-2.5-flash"

    /// The gated preview reasoning model. Never reference this literal at a call
    /// site — go through `reasoning` so the flag is always respected.
    static let preview = "gemini-3-flash-preview"

    /// The reasoning-tier model, gated by `GEMINI_3_PREVIEW_ENABLED`. Returns
    /// `fast` when the flag is OFF so no preview call is ever made.
    static var reasoning: String {
        FeatureFlags.gemini3PreviewEnabled ? preview : fast
    }
}
