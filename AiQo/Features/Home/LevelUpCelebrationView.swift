import SwiftUI

struct LevelUpCelebrationView: View {
    let level: Int
    let onDismiss: () -> Void

    @State private var showContent = false
    @State private var showText = false

    var body: some View {
        ZStack {
            // Dim background
            Color.black.opacity(showContent ? 0.4 : 0)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 16) {
                // Level number
                Text(level.arabicFormatted)
                    .font(.system(size: 72, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "6FD7B4"), Color(hex: "4DB897")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .scaleEffect(showContent ? 1 : 0.3)
                    .opacity(showContent ? 1 : 0)

                // Arabic celebration text
                Text(String(format: NSLocalizedString("levelUp.celebration", value: "وصلت للمستوى %d 🎉", comment: "Level up celebration"), level))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .opacity(showText ? 1 : 0)
                    .offset(y: showText ? 0 : 20)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                showContent = true
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.3)) {
                showText = true
            }
            // Auto-dismiss after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation(.easeOut(duration: 0.3)) {
                    onDismiss()
                }
            }
        }
    }
}
