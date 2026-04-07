import Foundation
import os.log
import Supabase

public final class SupabaseService {
    public static let shared = SupabaseService()
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "AiQo",
        category: "SupabaseService"
    )

    public let client: SupabaseClient

    private init() {
        let urlString = K.Supabase.url
        let anonKey = K.Supabase.anonKey

        guard !urlString.isEmpty,
              let url = URL(string: urlString),
              url.host != nil else {
            Self.logger.fault("supabase_client_placeholder_url_missing")
            client = SupabaseClient(
                supabaseURL: URL(string: "https://placeholder.invalid")!,
                supabaseKey: "missing"
            )
            return
        }

        guard !anonKey.isEmpty else {
            Self.logger.fault("supabase_client_placeholder_anon_key_missing")
            client = SupabaseClient(
                supabaseURL: url,
                supabaseKey: "missing"
            )
            return
        }

        client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: anonKey
        )
    }

    // MARK: - 🔍 Phase 3: Search & Privacy Logic

    public func searchUsers(query: String) async throws -> [UserProfile] {
        
        struct ProfileDTO: Decodable {
            let name: String?
            let age: Int?
            let height_cm: Int?
            let weight_kg: Int?
            let goal_text: String?
            let is_private: Bool?
        }

        // ✅ التصحيح هنا: استبدلنا value بـ pattern
        let response = try await client
            .from("profiles")
            .select("name, age, height_cm, weight_kg, goal_text, is_private")
            .ilike("name", pattern: "%\(query)%")
            .limit(20)
            .execute()

        let data = response.data
        let results = try JSONDecoder().decode([ProfileDTO].self, from: data)

        return results.compactMap { dto in
            guard let name = dto.name else { return nil }
            
            return UserProfile(
                name: name,
                age: dto.age ?? 0,
                heightCm: dto.height_cm ?? 0,
                weightKg: dto.weight_kg ?? 0,
                goalText: dto.goal_text ?? "",
                isPrivate: dto.is_private ?? false
            )
        }
    }

    // MARK: - Legacy Queries
    
    public struct Profile: Decodable, Identifiable {
        public let id: UUID
        public let name: String?
        public let is_private: Bool?
    }

    public func loadProfiles() async throws -> [Profile] {
        let response = try await client
            .from("profiles")
            .select()
            .execute()
        let data = response.data
        return try JSONDecoder().decode([Profile].self, from: data)
    }

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

    // MARK: - Notification Logic

    /// The current authenticated user's UUID string, or `nil` if not logged in.
    public var currentUserID: String? {
        client.auth.currentUser?.id.uuidString
    }

    public func updateDeviceToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: "push_device_token")
        print("💾 Device token saved locally.")

        Task {
            try? await syncStoredDeviceToken()
        }
    }

    public func syncStoredDeviceToken() async throws {
        guard let currentUser = client.auth.currentUser else {
            print("⏳ No user logged in yet. Token waiting locally.")
            return
        }
        
        guard let token = UserDefaults.standard.string(forKey: "push_device_token") else {
            return
        }

        print("🔄 Syncing device token for user: \(currentUser.id)...")

        let updateData = ["device_token": token]

        try await client
            .from("profiles")
            .update(updateData)
            .eq("user_id", value: currentUser.id)
            .execute()
            
        print("✅✅ SUCCESS: Device token synced to Supabase for user \(currentUser.id)")
    }
}
