import SwiftUI
import UIKit

struct KitchenView: View {
    @EnvironmentObject private var globalBrain: CaptainViewModel

    @State private var isCameraPresented = false
    @State private var selectedImage: UIImage?

    var body: some View {
        ZStack {
            kitchenBackground

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    heroCard
                    fridgePreviewCard
                    mealPlanSection
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }

            if globalBrain.isLoading {
                loadingOverlay
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .navigationTitle("المطبخ")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $isCameraPresented) {
            CameraView(
                onImagePicked: { image in
                    selectedImage = image
                    isCameraPresented = false
                    globalBrain.sendMessage(
                        text: "شنو تكدر تسويلي أكل من هاي الثلاجة؟",
                        image: image,
                        context: .kitchen
                    )
                },
                onCancel: {
                    isCameraPresented = false
                }
            )
            .ignoresSafeArea()
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.88), value: globalBrain.isLoading)
    }
}

private extension KitchenView {
    var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var cameraButtonLabel: String {
        if globalBrain.isLoading {
            return "جاري الفحص..."
        }
        if isCameraAvailable {
            return "فتح الكاميرا"
        }
        return "الكاميرا غير متاحة"
    }

    var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.10)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.primary)
                    .scaleEffect(1.25)

                Text("الكابتن حمودي ديفحص المكونات...")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)

                Text("دا نصغّر الصورة ونحلل الموجود حتى نرتبلك وجبات مناسبة.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.58), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.14), radius: 18, x: 0, y: 10)
            .padding(.horizontal, 28)
        }
    }
}

private extension KitchenView {
    var kitchenBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.kitchenMint.opacity(0.20),
                    Color.aiqoSand.opacity(0.18),
                    Color(.systemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.kitchenMint.opacity(0.16))
                .frame(width: 260, height: 260)
                .blur(radius: 42)
                .offset(x: -120, y: -250)

            Circle()
                .fill(Color.aiqoSand.opacity(0.28))
                .frame(width: 220, height: 220)
                .blur(radius: 38)
                .offset(x: 140, y: -150)
        }
    }

    var heroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Kitchen Vision")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.58), in: Capsule())

            Text("صوّر الثلاجة مباشرة وخلي حمّودي يرتبلك فطور وغداء وعشاء من الموجود.")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(.primary)

            Text("الكاميرا تفتح بواجهة كاملة، وبعد الالتقاط يشتغل التحليل بالخلفية بدون ما يجمّد الواجهة.")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            Button {
                isCameraPresented = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "camera.aperture")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                        .frame(width: 42, height: 42)
                        .background(Color.white.opacity(0.55), in: Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text("تصوير الثلاجة")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundStyle(.black)

                        Text(cameraButtonLabel)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.black.opacity(0.70))
                    }

                    Spacer(minLength: 12)

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(.black.opacity(0.72))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.kitchenMint)
                )
            }
            .buttonStyle(.plain)
            .disabled(globalBrain.isLoading || !isCameraAvailable)

            if !isCameraAvailable {
                Text("الكاميرا غير متاحة على هذا الجهاز حالياً.")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.58), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 18, x: 0, y: 10)
    }

    @ViewBuilder
    var fridgePreviewCard: some View {
        if let selectedImage {
            VStack(alignment: .leading, spacing: 12) {
                Text("آخر لقطة للثلاجة")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Image(uiImage: selectedImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 240)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.white.opacity(0.28), lineWidth: 1)
                    )

                Text("هاي الصورة اللي دا يعتمد عليها التحليل الحالي.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.52), lineWidth: 1)
            )
        }
    }

    var mealPlanSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("الخطة المقترحة")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(.primary)

            if let mealPlan = globalBrain.currentMealPlan, !mealPlan.meals.isEmpty {
                ForEach(mealPlan.meals) { meal in
                    mealCard(meal)
                }
            } else {
                placeholderCard(
                    title: "ماكو خطة بعد",
                    subtitle: "افتح الكاميرا وصوّر الثلاجة حتى يولد حمّودي وجبات Breakfast و Lunch و Dinner."
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func mealCard(_ meal: MealPlan.Meal) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.kitchenMint.opacity(0.78))
                    .frame(width: 48, height: 48)

                Image(systemName: iconName(for: meal.type))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(meal.type)
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)

                    Spacer(minLength: 12)

                    Text("\(meal.calories) kcal")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.46), in: Capsule())
                }

                Text(meal.description)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.55), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 14, x: 0, y: 7)
    }

    func placeholderCard(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Text(subtitle)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.52), lineWidth: 1)
        )
    }

    func iconName(for mealType: String) -> String {
        switch mealType.lowercased() {
        case let value where value.contains("breakfast"):
            return "sun.max.fill"
        case let value where value.contains("lunch"):
            return "fork.knife.circle.fill"
        case let value where value.contains("dinner"):
            return "moon.stars.fill"
        default:
            return "sparkles"
        }
    }
}
