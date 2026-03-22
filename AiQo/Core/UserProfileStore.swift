import Foundation
import UIKit
public import Combine

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

public final class UserProfileStore: ObservableObject {
    public static let shared = UserProfileStore()
    
    private let profileKey = "aiqo.userProfile"
    private let avatarKey  = "aiqo.userAvatar"
    private let tribePrivacyModeKey = "aiqo.user.tribePrivacyMode"

    @Published var tribePrivacyMode: PrivacyMode = .private {
        didSet {
            UserDefaults.standard.set(tribePrivacyMode.rawValue, forKey: tribePrivacyModeKey)
            NotificationCenter.default.post(name: .userProfileDidChange, object: nil)
        }
    }
    
    private init() {
        if let rawValue = UserDefaults.standard.string(forKey: tribePrivacyModeKey),
           let storedMode = PrivacyMode(rawValue: rawValue) {
            tribePrivacyMode = storedMode
        }
    }
    
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

    private static var avatarFileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("avatar.jpg")
    }

    public func saveAvatar(_ image: UIImage?) {
        if let image, let data = image.jpegData(compressionQuality: 0.85) {
            try? data.write(to: Self.avatarFileURL)
        } else {
            try? FileManager.default.removeItem(at: Self.avatarFileURL)
        }
        // Remove legacy UserDefaults data if present
        UserDefaults.standard.removeObject(forKey: avatarKey)
    }

    public func loadAvatar() -> UIImage? {
        // Try file first
        if let data = try? Data(contentsOf: Self.avatarFileURL) {
            return UIImage(data: data)
        }
        // Migrate from UserDefaults if present
        if let legacyData = UserDefaults.standard.data(forKey: avatarKey) {
            try? legacyData.write(to: Self.avatarFileURL)
            UserDefaults.standard.removeObject(forKey: avatarKey)
            return UIImage(data: legacyData)
        }
        return nil
    }

    func setTribePrivacyMode(_ mode: PrivacyMode) {
        guard tribePrivacyMode != mode else { return }
        tribePrivacyMode = mode
        TribeStore.shared.updateMyPrivacy(mode: mode)
        print("🪶 Saved tribe privacy mode: \(mode.rawValue)")
    }
}

extension Notification.Name {
    static let userProfileDidChange = Notification.Name("aiqo.userProfileDidChange")
}
