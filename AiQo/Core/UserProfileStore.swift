import Foundation
import UIKit

struct UserProfile: Codable {
    var name: String
    var age: Int
    var heightCm: Int
    var weightKg: Int
    var goalText: String   // مثل: "Stronger • Leaner"
}

final class UserProfileStore {
    static let shared = UserProfileStore()
    
    private let profileKey = "aiqo.userProfile"
    private let avatarKey  = "aiqo.userAvatar"
    
    private init() {}
    
    // MARK: - Profile Data
    
    var current: UserProfile {
        get {
            if let data = UserDefaults.standard.data(forKey: profileKey),
               let profile = try? JSONDecoder().decode(UserProfile.self, from: data) {
                return profile
            }
            // قيم افتراضية أول مرة
            return UserProfile(
                name: "حمّودي",
                age: 23,
                heightCm: 175,
                weightKg: 90,
                goalText: "Stronger • Leaner"
            )
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: profileKey)
            }
        }
    }
    
    // MARK: - Avatar
    
    func saveAvatar(_ image: UIImage?) {
        guard let image else {
            UserDefaults.standard.removeObject(forKey: avatarKey)
            return
        }
        
        if let data = image.jpegData(compressionQuality: 0.85) {
            UserDefaults.standard.set(data, forKey: avatarKey)
        }
    }
    
    func loadAvatar() -> UIImage? {
        guard let data = UserDefaults.standard.data(forKey: avatarKey) else { return nil }
        return UIImage(data: data)
    }
}
