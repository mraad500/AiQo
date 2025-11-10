import Foundation
import Supabase

public final class SupabaseService {
    public static let shared = SupabaseService()

    private let client: SupabaseClient

    private init() {
        guard let url = URL(string: K.Supabase.url), !K.Supabase.anonKey.isEmpty else {
            fatalError("⚠️ SUPABASE_URL or SUPABASE_ANON_KEY missing in Info.plist")
        }
        client = SupabaseClient(supabaseURL: url, supabaseKey: K.Supabase.anonKey)
    }

    // مثال بسيط: قراءة جدول profiles
    public struct Profile: Decodable { public let id: UUID; public let name: String? }

    public func loadProfiles() async throws -> [Profile] {
        try await client.database.from("profiles").select().execute().value
    }
}
