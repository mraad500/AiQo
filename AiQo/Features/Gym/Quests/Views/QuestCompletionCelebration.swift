import SwiftUI
import UIKit

struct QuestCompletionCelebration: View {
    let quest: QuestDefinition
    let onDismiss: () -> Void

    @State private var badgeScale: CGFloat = 0.3
    @State private var badgeOpacity: Double = 0
    @State private var textOpacity: Double = 0

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 24) {
                Spacer()

                // Badge — bounces in
                Image(quest.rewardImageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 160, height: 160)
                    .scaleEffect(badgeScale)
                    .opacity(badgeOpacity)
                    .shadow(color: Color(hex: "EBCF97").opacity(0.5), radius: 30, y: 10)

                // Congratulations text
                VStack(spacing: 8) {
                    Text("مبروك!")
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundColor(.white)

                    Text("أكملت تحدي \(quest.title)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)

                    Text("الجائزة محفوظة في الإنجازات")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.top, 4)
                }
                .opacity(textOpacity)

                Spacer()

                // Dismiss button
                Button(action: { onDismiss() }) {
                    Text("تمام")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Color(hex: "1A1A1A"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(hex: "EBCF97"))
                        )
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
                .opacity(textOpacity)
            }
        }
        .onAppear {
            // Badge bounce animation
            withAnimation(.spring(response: 0.6, dampingFraction: 0.5, blendDuration: 0)) {
                badgeScale = 1.0
                badgeOpacity = 1.0
            }
            // Text fade in after badge
            withAnimation(.easeOut(duration: 0.5).delay(0.4)) {
                textOpacity = 1.0
            }
            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }
}

// Helper for transparent fullScreenCover
struct ClearBackground: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        DispatchQueue.main.async {
            view.superview?.superview?.backgroundColor = .clear
        }
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {}
}
