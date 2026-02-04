import Foundation

struct AppGroupKeys {
    // تأكد ان هذا الاسم يطابق اللي في الـ Signing & Capabilities
    static let appGroupID = "group.com.aiqo.kernel2"
    
    static let isEnabled = "isProtectionEnabled"
    static let savedSelection = "savedSelection"
    
    // 👇 هذا هو السطر اللي كان ناقص وسبب الخطأ الأحمر
    static let userCoins = "userCoins"
}
