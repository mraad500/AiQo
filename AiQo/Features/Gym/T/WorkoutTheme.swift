//
//  WorkoutTheme.swift
//  (Create New File)
//

import SwiftUI

struct WorkoutTheme {
    // الألوان المستوحاة من الصور المرفقة
    static let pastelBeige = Color(red: 1.0, green: 0.85, blue: 0.65) // لون الكروت العلوية وزر البدء
    static let pastelMint  = Color(red: 0.72, green: 0.91, blue: 0.83) // لون الكروت السفلية
    static let darkSky     = Color(red: 0.05, green: 0.05, blue: 0.08) // خلفية سوداء عميقة
    
    // خطوط مخصصة (مستديرة وعريضة)
    static func font(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        return .system(style, design: .rounded).weight(weight)
    }
}

// مكون خلفية النجوم (Starry Sky)
struct StarryBackground: View {
    var body: some View {
        ZStack {
            WorkoutTheme.darkSky.ignoresSafeArea()
            
            // نجوم عشوائية بسيطة لإعطاء عمق
            GeometryReader { proxy in
                ForEach(0..<30, id: \.self) { _ in
                    Circle()
                        .fill(Color.white.opacity(Double.random(in: 0.1...0.4)))
                        .frame(width: CGFloat.random(in: 1...3))
                        .position(
                            x: CGFloat.random(in: 0...proxy.size.width),
                            y: CGFloat.random(in: 0...proxy.size.height)
                        )
                }
            }
        }
    }
}
