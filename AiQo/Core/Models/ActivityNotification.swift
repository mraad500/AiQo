import Foundation

// نوع الإشعار داخل منظومة AiQo Activity
enum ActivityNotificationType: String, Codable {
    case moveNow        // تحرّك الآن
    case almostThere    // قريب من الهدف
    case goalCompleted  // الهدف اكتمل
}

enum ActivityNotificationGender: String, Codable {
    case male
    case female
}

enum ActivityNotificationLanguage: String, Codable {
    case arabic
    case english
}

struct ActivityNotification: Identifiable, Codable, Hashable {
    let id: Int
    let text: String
    let type: ActivityNotificationType
    let gender: ActivityNotificationGender
    let language: ActivityNotificationLanguage
}
