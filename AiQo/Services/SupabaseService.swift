import Foundation
import Supabase

public final class SupabaseService {
    public static let shared = SupabaseService()

    // خليه public (أو بدون modifier) حتى تقدر توصله من MealsRepository
    public let client: SupabaseClient

    private init() {
        guard
            let url = URL(string: K.Supabase.url),
            !K.Supabase.anonKey.isEmpty
        else {
            fatalError("❌ Missing SUPABASE_URL or SUPABASE_ANON_KEY in Info.plist")
        }

        client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: K.Supabase.anonKey
        )
    }

    // MARK: - Model

    public struct Profile: Decodable, Identifiable {
        public let id: UUID
        public let name: String?
    }

    // MARK: - Queries

    // تحميل كل profiles
    public func loadProfiles() async throws -> [Profile] {
        let response = try await client
            .from("profiles")
            .select()
            .execute()

        let data = response.data
        return try JSONDecoder().decode([Profile].self, from: data)
    }

    // تحميل profile واحد عبر id
    public func loadProfile(id: UUID) async throws -> Profile? {
        let response = try await client
            .from("profiles")
            .select()
            .eq("id", value: id.uuidString)
            .single()
            .execute()

        let data = response.data
        return try JSONDecoder().decode(Profile.self, from: data)
    }
}
