import Foundation
import Supabase

public final class SupabaseService {
    public static let shared = SupabaseService()

    public let client: SupabaseClient

    private init() {
        // ⚠️ المفاتيح الخاصة بك
        let mySupabaseURL = "https://zidbsrepqpbucqzxnwgk.supabase.co"
        let mySupabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InppZGJzcmVwcXBidWNxenhud2drIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI3OTc0NjAsImV4cCI6MjA3ODM3MzQ2MH0.bZYBbhHS90Leb84Ijnq1BV5XZx6uk6-DCNEPmBFnn5M"

        guard let url = URL(string: mySupabaseURL), !mySupabaseKey.isEmpty else {
            fatalError("❌ تأكد من نسخ الرابط والمفتاح بشكل صحيح!")
        }

        client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: mySupabaseKey
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
