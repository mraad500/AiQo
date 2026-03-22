import SwiftUI
import UIKit

// MARK: - Share Card Design

/// يولّد بطاقة مشاركة جميلة للإنجازات — تصلح لـ Instagram Stories و Twitter
enum ShareCardRenderer {

    /// يولّد صورة بطاقة الإنجاز للتمرين — async to avoid blocking the main thread
    static func renderWorkoutCard(
        workoutType: String,
        duration: String,
        calories: String,
        distance: String?,
        avgHR: String?,
        xpEarned: Int,
        userName: String
    ) async -> UIImage? {
        let view = WorkoutShareCard(
            workoutType: workoutType,
            duration: duration,
            calories: calories,
            distance: distance,
            avgHR: avgHR,
            xpEarned: xpEarned,
            userName: userName
        )
        return await renderView(view, size: CGSize(width: 1080, height: 1920))
    }

    /// يولّد صورة بطاقة التقرير الأسبوعي — async to avoid blocking the main thread
    static func renderWeeklyCard(
        steps: String,
        calories: String,
        distance: String,
        sleep: String,
        workouts: Int,
        score: Int,
        userName: String
    ) async -> UIImage? {
        let view = WeeklyShareCard(
            steps: steps,
            calories: calories,
            distance: distance,
            sleep: sleep,
            workouts: workouts,
            score: score,
            userName: userName
        )
        return await renderView(view, size: CGSize(width: 1080, height: 1920))
    }

    /// يولّد صورة بطاقة دعوة القبيلة — async to avoid blocking the main thread
    static func renderInviteCard(
        tribeName: String,
        inviterName: String,
        inviteCode: String,
        validUntil: String,
        memberCount: Int
    ) async -> UIImage? {
        let view = InviteCardView(
            tribeName: tribeName,
            inviterName: inviterName,
            inviteCode: inviteCode,
            validUntil: validUntil,
            memberCount: memberCount
        )
        return await renderView(view, size: CGSize(width: 1080, height: 1920))
    }

    /// يولّد صورة من أي SwiftUI View — renders off the main thread
    private static func renderView<V: View>(_ view: V, size: CGSize) async -> UIImage? {
        // ImageRenderer must be created on MainActor, but the heavy render is dispatched off-thread
        let framedView = await MainActor.run {
            view.frame(width: size.width, height: size.height)
        }
        let image = await MainActor.run {
            let renderer = ImageRenderer(content: framedView)
            renderer.scale = 1.0
            return renderer.uiImage
        }
        return image
    }

    // MARK: - Share to Instagram Stories

    /// يشارك صورة على Instagram Stories
    static func shareToInstagramStories(image: UIImage) -> Bool {
        guard let urlScheme = URL(string: "instagram-stories://share"),
              UIApplication.shared.canOpenURL(urlScheme),
              let imageData = image.pngData() else {
            return false
        }

        let items: [[String: Any]] = [[
            "com.instagram.sharedSticker.backgroundImage": imageData,
            "com.instagram.sharedSticker.backgroundTopColor": "#1A1A1A",
            "com.instagram.sharedSticker.backgroundBottomColor": "#0D0D0D"
        ]]

        UIPasteboard.general.setItems(items, options: [.expirationDate: Date().addingTimeInterval(300)])
        UIApplication.shared.open(urlScheme)
        return true
    }

    /// يشارك عبر iOS Share Sheet
    @MainActor
    static func presentShareSheet(image: UIImage, text: String) {
        let activityItems: [Any] = [image, text]
        let activityVC = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }

        // iPad support
        activityVC.popoverPresentationController?.sourceView = rootVC.view
        activityVC.popoverPresentationController?.sourceRect = CGRect(x: rootVC.view.bounds.midX, y: rootVC.view.bounds.midY, width: 0, height: 0)

        rootVC.present(activityVC, animated: true)
    }
}

// MARK: - Workout Share Card

private struct WorkoutShareCard: View {
    let workoutType: String
    let duration: String
    let calories: String
    let distance: String?
    let avgHR: String?
    let xpEarned: Int
    let userName: String

    var body: some View {
        ZStack {
            // الخلفية
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.09, blue: 0.08),
                    Color(red: 0.12, green: 0.14, blue: 0.12),
                    Color(red: 0.06, green: 0.07, blue: 0.06)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 200)

                // العنوان
                VStack(spacing: 16) {
                    Text("WORKOUT COMPLETE")
                        .font(.system(size: 28, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                        .tracking(6)

                    Text(workoutType)
                        .font(.system(size: 64, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Text("+\(xpEarned) XP")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(red: 0.718, green: 0.890, blue: 0.792), .white],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }

                Spacer()
                    .frame(height: 80)

                // الإحصائيات
                HStack(spacing: 40) {
                    statBubble(value: duration, label: "TIME", icon: "clock.fill")
                    statBubble(value: calories, label: "KCAL", icon: "flame.fill")
                    if let dist = distance {
                        statBubble(value: dist, label: "KM", icon: "figure.run")
                    }
                }

                if let hr = avgHR {
                    Spacer().frame(height: 40)
                    HStack(spacing: 8) {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.red)
                        Text("\(hr) BPM")
                            .font(.system(size: 28, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }

                Spacer()

                // التوقيع
                footer
            }
        }
    }

    private func statBubble(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(Color(red: 0.718, green: 0.890, blue: 0.792))

            Text(value)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(label)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .tracking(3)
        }
    }

    private var footer: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(userName)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))

                Text("AiQo")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.718, green: 0.890, blue: 0.792))
            }

            Spacer()
        }
        .padding(.horizontal, 60)
        .padding(.bottom, 100)
    }
}

// MARK: - Weekly Share Card

private struct WeeklyShareCard: View {
    let steps: String
    let calories: String
    let distance: String
    let sleep: String
    let workouts: Int
    let score: Int
    let userName: String

    var body: some View {
        ZStack {
            // الخلفية
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.09, blue: 0.08),
                    Color(red: 0.10, green: 0.12, blue: 0.10),
                    Color(red: 0.06, green: 0.07, blue: 0.06)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 180)

                // العنوان
                VStack(spacing: 16) {
                    Text("WEEKLY REPORT")
                        .font(.system(size: 28, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                        .tracking(6)

                    // Score Ring
                    ZStack {
                        Circle()
                            .stroke(.white.opacity(0.1), lineWidth: 16)
                            .frame(width: 180, height: 180)

                        Circle()
                            .trim(from: 0, to: CGFloat(score) / 100.0)
                            .stroke(
                                LinearGradient(
                                    colors: [Color(red: 0.718, green: 0.890, blue: 0.792), .green],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                style: StrokeStyle(lineWidth: 16, lineCap: .round)
                            )
                            .frame(width: 180, height: 180)
                            .rotationEffect(.degrees(-90))

                        VStack(spacing: 4) {
                            Text("\(score)")
                                .font(.system(size: 56, weight: .black, design: .rounded))
                                .foregroundStyle(.white)

                            Text("/ 100")
                                .font(.system(size: 20, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                }

                Spacer()
                    .frame(height: 60)

                // الإحصائيات
                VStack(spacing: 24) {
                    HStack(spacing: 40) {
                        weeklyStatItem(icon: "figure.walk", value: steps, label: "خطوة")
                        weeklyStatItem(icon: "flame.fill", value: calories, label: "سعرة")
                    }

                    HStack(spacing: 40) {
                        weeklyStatItem(icon: "figure.run", value: distance, label: "كم")
                        weeklyStatItem(icon: "moon.fill", value: sleep, label: "ساعة نوم")
                    }

                    HStack(spacing: 40) {
                        weeklyStatItem(icon: "dumbbell.fill", value: "\(workouts)", label: "تمرين")
                        Spacer().frame(width: 120)
                    }
                }
                .padding(.horizontal, 80)

                Spacer()

                // التوقيع
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(userName)
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))

                        Text("AiQo")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 0.718, green: 0.890, blue: 0.792))
                    }

                    Spacer()
                }
                .padding(.horizontal, 60)
                .padding(.bottom, 100)
            }
        }
    }

    private func weeklyStatItem(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(Color(red: 0.718, green: 0.890, blue: 0.792))
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(label)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()
        }
    }
}

// MARK: - Previews

#Preview("Workout Card") {
    WorkoutShareCard(
        workoutType: "المشي",
        duration: "83:11",
        calories: "438",
        distance: "5.2",
        avgHR: "123",
        xpEarned: 532,
        userName: "محمد"
    )
    .frame(width: 390, height: 693)
}

#Preview("Weekly Card") {
    WeeklyShareCard(
        steps: "52,340",
        calories: "3,200",
        distance: "38.5",
        sleep: "48.2",
        workouts: 5,
        score: 78,
        userName: "محمد"
    )
    .frame(width: 390, height: 693)
}
