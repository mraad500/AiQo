import Foundation
import UIKit

// ✅ التغيير الأساسي: جعل الـ Struct وخصائصه public لحل خطأ SupabaseService
public struct UserProfile: Codable {
    public var name: String
    public var age: Int
    public var heightCm: Int
    public var weightKg: Int
    public var goalText: String
    public var username: String?
    public var birthDate: Date?
    public var gender: ActivityNotificationGender?
    // 🔒 Privacy Flag
    public var isPrivate: Bool

    // ✅ يجب إضافة Initializer عام (public) لكي نتمكن من استخدامه في ملفات أخرى مثل SupabaseService
    public init(
        name: String,
        age: Int,
        heightCm: Int,
        weightKg: Int,
        goalText: String,
        username: String? = nil,
        birthDate: Date? = nil,
        gender: ActivityNotificationGender? = nil,
        isPrivate: Bool = false
    ) {
        self.name = name
        self.age = age
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.goalText = goalText
        self.username = username
        self.birthDate = birthDate
        self.gender = gender
        self.isPrivate = isPrivate
    }
}

public final class UserProfileStore {
    public static let shared = UserProfileStore()
    
    private let profileKey = "aiqo.userProfile"
    private let avatarKey  = "aiqo.userAvatar"
    
    private init() {}
    
    public var current: UserProfile {
        get {
            if let data = UserDefaults.standard.data(forKey: profileKey),
               let profile = try? JSONDecoder().decode(UserProfile.self, from: data) {
                return profile
            }
            // القيم الافتراضية
            return UserProfile(
                name: "Captain",
                age: 0,
                heightCm: 0,
                weightKg: 0,
                goalText: "Stronger • Leaner",
                username: nil,
                birthDate: nil,
                gender: nil,
                isPrivate: false
            )
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: profileKey)
                // Notify observers (like the VC) that privacy/data changed
                NotificationCenter.default.post(name: .userProfileDidChange, object: nil)
            }
        }
    }
    
    // MARK: - Avatar Methods
    public func saveAvatar(_ image: UIImage?) {
        guard let image else { UserDefaults.standard.removeObject(forKey: avatarKey); return }
        if let data = image.jpegData(compressionQuality: 0.85) {
            UserDefaults.standard.set(data, forKey: avatarKey)
        }
    }
    
    public func loadAvatar() -> UIImage? {
        guard let data = UserDefaults.standard.data(forKey: avatarKey) else { return nil }
        return UIImage(data: data)
    }
}

extension Notification.Name {
    static let userProfileDidChange = Notification.Name("aiqo.userProfileDidChange")
}
