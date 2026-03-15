import SwiftUI

struct GymTheme {
    static let mint = Color(red: 0.77, green: 0.94, blue: 0.86)
    static let beige = Color(red: 0.97, green: 0.84, blue: 0.64)
    static let gold = Color(red: 1.00, green: 0.85, blue: 0.35)
    static let glassAlpha: Double = 0.16

    static let warmOrange = Color(red: 1.00, green: 0.65, blue: 0.20)
    static let punchyPink = Color(red: 1.00, green: 0.40, blue: 0.55)
    static let intenseTeal = Color(red: 0.00, green: 0.75, blue: 0.65)
    static let electricPurple = Color(red: 0.55, green: 0.45, blue: 0.95)
    static let brandLemon = Color(red: 1.00, green: 0.93, blue: 0.72)
    static let brandLavender = Color(red: 0.96, green: 0.88, blue: 1.00)
}

struct GymView: View {
    @State private var isProfilePresented = false

    var body: some View {
        ClubRootView()
            .aiqoTopTrailingProfileButton(isPresented: $isProfilePresented)
    }
}

#Preview {
    GymView()
}
