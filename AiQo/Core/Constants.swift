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

// MARK: - Football API

enum APIConstants {
    static let footballBaseURL = URL(string: "https://api.football-data.org/v4")!

    static let footballAPIKey: String = {
        Bundle.main.object(forInfoDictionaryKey: "FOOTBALL_DATA_API_KEY") as? String ?? ""
    }()
}
