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

    // MARK: - Model
    public struct Profile: Decodable, Identifiable {
        public let id: UUID
        public let name: String?
    }

    // MARK: - Queries
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

    // MARK: - Notification Logic (الحل النهائي)

    /// تستدعى من AppDelegate فور وصول التوكن
    public func updateDeviceToken(_ token: String) {
        // 1. نحفظ التوكن دائماً في ذاكرة الهاتف
        UserDefaults.standard.set(token, forKey: "push_device_token")
        print("💾 Device token saved locally.")

        // 2. نحاول رفعه فوراً إذا كان هناك مستخدم
        Task {
            try? await syncStoredDeviceToken()
        }
    }

    /// تستدعى عند فتح الصفحة الرئيسية لرفع التوكن المحفوظ
    public func syncStoredDeviceToken() async throws {
        // هل يوجد مستخدم مسجل دخول؟
        guard let currentUser = client.auth.currentUser else {
            print("⏳ No user logged in yet. Token waiting locally.")
            return
        }
        
        // هل لدينا توكن محفوظ؟
        guard let token = UserDefaults.standard.string(forKey: "push_device_token") else {
            return
        }

        print("🔄 Syncing device token for user: \(currentUser.id)...")

        let updateData = ["device_token": token]

        try await client
            .from("profiles")
            .update(updateData)
            .eq("user_id", value: currentUser.id) // استخدام user_id حسب إعداداتك السابقة
            .execute()
            
        print("✅✅ SUCCESS: Device token synced to Supabase for user \(currentUser.id)")
    }
}
