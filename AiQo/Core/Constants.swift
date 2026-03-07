import Foundation

// MARK: - Supabase

enum K {
    enum Supabase {
        static let url: String = {
            Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String ?? ""
        }()

        static let anonKey: String = {
            Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String ?? ""
        }()
    }
}
