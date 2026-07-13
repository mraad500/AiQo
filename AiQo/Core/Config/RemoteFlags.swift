import Foundation

/// Remote-config bridge for the small set of flags we need to flip without
/// shipping a new build. Backed by a single Supabase row keyed by
/// `flag_name` so we don't need a full feature-flag SDK.
///
/// Design choices:
/// - Reads return the **cached** value synchronously (UserDefaults). Cold launch
///   is never blocked on the network.
/// - `refresh()` is fire-and-forget. It runs on cold launch and on background
///   fetch. If Supabase is unreachable, the cached value stands.
/// - Defaults to "kill switch OFF" (V4 enabled) so a missing row / 404 / 500
///   does not unintentionally disable V4 globally.
///
/// Server-side contract (Supabase Postgres):
///
///   create table public.remote_flags (
///       flag_name text primary key,
///       bool_value boolean not null default false,
///       updated_at timestamptz not null default now()
///   );
///
///   -- read-only access for the anon role:
///   create policy "anon-read"
///     on public.remote_flags for select
///     to anon
///     using (true);
///
/// Mohammed flips a kill switch by upserting a row, e.g.
/// `('memory_v4_globally_disabled', true)`,
/// `('notification_brain_globally_disabled', true)`, or
/// `('captain_brain_v2_globally_disabled', true)`. Propagation = next cold
/// launch or next BG fetch tick on each device.
final class RemoteFlags: @unchecked Sendable {
    static let shared = RemoteFlags()

    private static let userDefaultsPrefix = "aiqo.remoteflags."
    private static let memoryV4DisabledKey = "memory_v4_globally_disabled"
    private static let notificationBrainDisabledKey = "notification_brain_globally_disabled"
    private static let captainBrainV2DisabledKey = "captain_brain_v2_globally_disabled"

    /// Every remote flag fetched in one round-trip. Add new kill switches here.
    private static let allFlagKeys = [
        memoryV4DisabledKey,
        notificationBrainDisabledKey,
        captainBrainV2DisabledKey,
    ]

    private let session: URLSession
    private let defaults: UserDefaults

    private init(session: URLSession = .shared, defaults: UserDefaults = .standard) {
        self.session = session
        self.defaults = defaults
    }

    /// Synchronous read. Returns the last cached value (default false = not disabled).
    var memoryV4GloballyDisabled: Bool { cachedDisabled(Self.memoryV4DisabledKey) }

    /// Remote kill switch for the proactive NotificationBrain pipeline.
    var notificationBrainGloballyDisabled: Bool { cachedDisabled(Self.notificationBrainDisabledKey) }

    /// Remote kill switch for Captain Brain V2 features.
    var captainBrainV2GloballyDisabled: Bool { cachedDisabled(Self.captainBrainV2DisabledKey) }

    private func cachedDisabled(_ flagKey: String) -> Bool {
        defaults.bool(forKey: Self.userDefaultsPrefix + flagKey)
    }

    /// Background refresh. Failures are swallowed — the cache is the source of truth
    /// for the current launch. Safe to call any time. No-op when Supabase is not
    /// configured (e.g., DEBUG without Secrets.xcconfig).
    func refresh() async {
        guard
            let urlString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            !urlString.isEmpty,
            !urlString.hasPrefix("$("),
            let anonKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
            !anonKey.isEmpty,
            !anonKey.hasPrefix("$("),
            let baseURL = URL(string: urlString)
        else {
            diag.info("RemoteFlags.refresh skipped: Supabase not configured")
            return
        }

        let url = baseURL
            .appending(path: "/rest/v1/remote_flags")
            .appending(queryItems: [
                URLQueryItem(name: "select", value: "flag_name,bool_value"),
                URLQueryItem(name: "flag_name", value: "in.(\(Self.allFlagKeys.joined(separator: ",")))")
            ])

        var request = URLRequest(url: url, timeoutInterval: 8)
        request.httpMethod = "GET"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                diag.info("RemoteFlags.refresh non-2xx; keeping cache")
                return
            }
            let rows = (try? JSONDecoder().decode([Row].self, from: data)) ?? []
            // A flag absent from the response means "not disabled" — write false so
            // a previously-true row that was deleted/flipped resets to enabled.
            for key in Self.allFlagKeys {
                let value = rows.first(where: { $0.flag_name == key })?.bool_value ?? false
                defaults.set(value, forKey: Self.userDefaultsPrefix + key)
            }
            diag.info("RemoteFlags.refresh ok: \(rows.count) flag row(s) cached")
        } catch {
            diag.info("RemoteFlags.refresh failed (\(error.localizedDescription)); keeping cache")
        }
    }

    private struct Row: Decodable {
        let flag_name: String
        let bool_value: Bool
    }
}
