import Foundation

struct RemoteProfile: Codable {
    let user_id: UUID
    let name: String
    let age: Int
    let height_cm: Int
    let weight_kg: Int
    let goal_text: String
}

final class ProfileRemoteService {
    static let shared = ProfileRemoteService()
    
    private let session = URLSession.shared
    private let baseURL: URL
    private let anonKey: String
    
    private init() {
        guard
            let urlString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let anonKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
            let url = URL(string: urlString)
        else {
            fatalError("Missing Supabase config in Info.plist")
        }
        
        self.baseURL = url
        self.anonKey = anonKey
    }
    
    // رفع البروفايل الى Supabase عبر REST API
    func syncToRemote(userId: UUID, profile: UserProfile) async throws {
        let payload = RemoteProfile(
            user_id: userId,
            name: profile.name,
            age: profile.age,
            height_cm: profile.heightCm,
            weight_kg: profile.weightKg,
            goal_text: profile.goalText
        )
        
        let url = baseURL
            .appendingPathComponent("rest")
            .appendingPathComponent("v1")
            .appendingPathComponent("profiles")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.addValue(anonKey, forHTTPHeaderField: "apikey")
        // نستخدم upsert على user_id
        request.addValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        
        // Supabase REST يتوقع صفوف كمصفوفة أو ككائن واحد
        request.httpBody = try JSONEncoder().encode(payload)
        
        _ = try await session.data(for: request)
    }
    
    // جلب البروفايل من Supabase (مثلاً أول مرة يفتح التطبيق)
    func fetchFromRemote(userId: UUID) async throws -> UserProfile? {
        var components = URLComponents(
            url: baseURL
                .appendingPathComponent("rest")
                .appendingPathComponent("v1")
                .appendingPathComponent("profiles"),
            resolvingAgainstBaseURL: false
        )
        
        // user_id=eq.<UUID>&select=*
        components?.queryItems = [
            .init(name: "user_id", value: "eq.\(userId.uuidString)"),
            .init(name: "select", value: "*")
        ]
        
        guard let url = components?.url else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.addValue(anonKey, forHTTPHeaderField: "apikey")
        
        let (data, _) = try await session.data(for: request)
        
        let remotes = try JSONDecoder().decode([RemoteProfile].self, from: data)
        guard let remote = remotes.first else { return nil }
        
        return UserProfile(
            name: remote.name,
            age: remote.age,
            heightCm: remote.height_cm,
            weightKg: remote.weight_kg,
            goalText: remote.goal_text
        )
    }
}
