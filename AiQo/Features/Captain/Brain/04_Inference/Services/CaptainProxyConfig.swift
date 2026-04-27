import Foundation
import Supabase

/// Resolves the Supabase Edge Function URLs + per-call Supabase JWT used by
/// the Gemini and MiniMax proxy paths.
///
/// The proxy path exists so API keys for Gemini + MiniMax don't have to ship
/// inside the IPA. When `FeatureFlags.useCloudProxy` is OFF, all callers
/// fall through to the legacy direct-API path that reads keys from
/// `Info.plist` (populated from `Secrets.xcconfig` at build time).
///
/// Activation procedure (see `supabase/functions/README.md` for the full
/// runbook):
///   1. Deploy `captain-chat` and `captain-voice` Edge Functions.
///   2. Set `GEMINI_API_KEY` and `MINIMAX_API_KEY` as Supabase Edge secrets.
///   3. Flip `USE_CLOUD_PROXY = YES` in `Info.plist` (via `Secrets.xcconfig`).
///   4. Rotate the now-legacy client-side keys.
enum CaptainProxyConfig {
    enum Path {
        /// `functions/v1/captain-chat` — Gemini generation (chat + memory extractor).
        case chat
        /// `functions/v1/captain-voice` — MiniMax TTS.
        case voice

        var suffix: String {
            switch self {
            case .chat:  return "functions/v1/captain-chat"
            case .voice: return "functions/v1/captain-voice"
            }
        }
    }

    /// Live read of `FeatureFlags.useCloudProxy`. Evaluated per call so a
    /// test harness that mutates `Info.plist` between requests sees the flip
    /// immediately.
    ///
    /// Prefer the per-path getters below — `isEnabled` exists only for
    /// callers that genuinely care about the master switch (e.g. shared
    /// diagnostics).
    static var isEnabled: Bool {
        FeatureFlags.useCloudProxy
    }

    /// True when chat (Gemini + memory extractor) should route through the
    /// `captain-chat` Edge Function.
    static var isChatEnabled: Bool {
        FeatureFlags.useChatCloudProxy
    }

    /// True when MiniMax TTS should route through the `captain-voice`
    /// Edge Function.
    static var isVoiceEnabled: Bool {
        FeatureFlags.useVoiceCloudProxy
    }

    /// Resolves the full Edge Function URL for the given path. Returns `nil`
    /// if Supabase is not configured (placeholder / missing URL), which
    /// signals callers to fall back to the legacy direct path.
    static func endpointURL(for path: Path) -> URL? {
        let rawURL = K.Supabase.url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawURL.isEmpty,
              let base = URL(string: rawURL),
              base.host != nil else {
            return nil
        }
        return base.appendingPathComponent(path.suffix)
    }

    /// Fetches the current Supabase session's access token. The Edge Functions
    /// require a valid user JWT; the app must be authenticated (Sign in with
    /// Apple or equivalent) before proxy calls succeed.
    ///
    /// Throws `HybridBrainServiceError.missingAPIKey` when no session exists —
    /// this slots into existing error handling so tier-gate / network-failure
    /// branches light up the same toast as a missing API key today.
    static func currentSessionJWT() async -> String? {
        do {
            let session = try await SupabaseService.shared.client.auth.session
            let token = session.accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
            return token.isEmpty ? nil : token
        } catch {
            return nil
        }
    }

    /// The Supabase anon key used as the `apikey` header on Edge Function
    /// calls (Supabase's gateway requires both headers). Safe to ship in-app
    /// — this is the public anon key, not a service-role key.
    static var anonKey: String? {
        let key = K.Supabase.anonKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return key.isEmpty ? nil : key
    }
}
