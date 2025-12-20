import SwiftUI

// تعريف الألوان بناءً على الصورة التي أرسلتها
extension Color {
    // اللون الفستقي (Mint)
    static let brandMint = Color(red: 0.77, green: 0.94, blue: 0.86)
    // اللون البيجي (Sand)
    static let brandSand = Color(red: 0.97, green: 0.84, blue: 0.64)
    // لون النص الداكن
    static let brandBlack = Color.black.opacity(0.9)
    // لون زر الإنهاء
    static let brandRed = Color(red: 0.95, green: 0.35, blue: 0.35)
}
