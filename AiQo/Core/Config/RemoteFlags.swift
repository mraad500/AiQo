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
/// Mohammed flips the kill switch by upserting
/// `('memory_v4_globally_disabled', true)`. Propagation = next cold launch or
/// next BG fetch tick on each device.
final class RemoteFlags: @unchecked Sendable {
    static let shared = RemoteFlags()

    private static let userDefaultsPrefix = "aiqo.remoteflags."
    private static let memoryV4DisabledKey = "memory_v4_globally_disabled"

    private let session: URLSession
    private let defaults: UserDefaults

    private init(session: URLSession = .shared, defaults: UserDefaults = .standard) {
        self.session = session
        self.defaults = defaults
    }

    /// Synchronous read. Returns the last cached value (default false).
    var memoryV4GloballyDisabled: Bool {
        defaults.bool(forKey: Self.userDefaultsPrefix + Self.memoryV4DisabledKey)
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
                URLQueryItem(name: "flag_name", value: "eq.\(Self.memoryV4DisabledKey)")
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
            let nextValue = rows.first(where: { $0.flag_name == Self.memoryV4DisabledKey })?.bool_value ?? false
            defaults.set(nextValue, forKey: Self.userDefaultsPrefix + Self.memoryV4DisabledKey)
            diag.info("RemoteFlags.refresh ok: memory_v4_globally_disabled=\(nextValue)")
        } catch {
            diag.info("RemoteFlags.refresh failed (\(error.localizedDescription)); keeping cache")
        }
    }

    private struct Row: Decodable {
        let flag_name: String
        let bool_value: Bool
    }
}
