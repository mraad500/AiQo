import Foundation

// Gender enum — used by UserProfileStore, ProfileScreen, ProfileSetupView
public enum ActivityNotificationGender: String, Codable {
    case male
    case female
}

// Language enum — kept for HealthKitManager compatibility
public enum ActivityNotificationLanguage: String, Codable {
    case arabic = "ar"
    case english = "en"
}
