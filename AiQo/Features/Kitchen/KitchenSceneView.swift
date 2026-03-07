import SwiftUI

struct KitchenSceneView: View {
    @EnvironmentObject private var kitchenStore: KitchenPersistenceStore

    @State private var openFridge = false
    @State private var openMealPlan = false
    @State private var openCaptainChat = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                if UIImage(named: "imageKitchenHamoudi") != nil {
                    Image("imageKitchenHamoudi")
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        .ignoresSafeArea(edges: .bottom)

                    hotspots(in: proxy.size)
                    sceneActionBadges(in: proxy.size)
                } else {
                    // TODO: Add imageKitchenHamoudi to Assets.xcassets with this exact name.
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                        .overlay(
                            Text("kitchen.scene.missingAsset".localized)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 24)
                        )
                        .frame(width: min(proxy.size.width - 32, 420), height: min(proxy.size.height - 140, 640))
                        .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                }
            }
            .navigationDestination(isPresented: $openFridge) {
                InteractiveFridgeView()
                    .environmentObject(kitchenStore)
            }
            .navigationDestination(isPresented: $openMealPlan) {
                MealPlanView()
                    .environmentObject(kitchenStore)
            }
            .navigationDestination(isPresented: $openCaptainChat) {
                KitchenView()
            }
        }
        .navigationTitle("screen.kitchen.title".localized)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private extension KitchenSceneView {
    @ViewBuilder
    func hotspots(in size: CGSize) -> some View {
        ZStack {
            hotspot(
                size: size,
                x: 0.83,
                y: 0.43,
                width: 0.25,
                height: 0.30,
                accessibilityLabel: "kitchen.hotspot.fridge".localized,
                accessibilityHint: "kitchen.hotspot.fridge.hint".localized
            ) {
                openFridge = true
            }

            hotspot(
                size: size,
                x: 0.22,
                y: 0.61,
                width: 0.32,
                height: 0.38,
                accessibilityLabel: "kitchen.hotspot.captain".localized,
                accessibilityHint: "kitchen.hotspot.captain.hint".localized
            ) {
                openCaptainChat = true
            }

            hotspot(
                size: size,
                x: 0.52,
                y: 0.63,
                width: 0.45,
                height: 0.20,
                accessibilityLabel: "kitchen.hotspot.plan".localized,
                accessibilityHint: "kitchen.hotspot.plan.hint".localized
            ) {
                openMealPlan = true
            }
        }
    }

    func hotspot(
        size: CGSize,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        height: CGFloat,
        accessibilityLabel: String,
        accessibilityHint: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Rectangle()
                .fill(Color.black.opacity(0.001))
                .frame(width: size.width * width, height: size.height * height)
        }
        .buttonStyle(.plain)
        .position(
            x: size.width * x,
            y: size.height * y
        )
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }

    @ViewBuilder
    func sceneActionBadges(in size: CGSize) -> some View {
        ZStack {
            sceneActionBadge(
                title: "kitchen.fridge.title".localized,
                systemImage: "refrigerator.fill",
                x: 0.82,
                y: 0.33,
                in: size
            ) {
                openFridge = true
            }

            sceneActionBadge(
                title: "kitchen.captain.title".localized,
                systemImage: "person.wave.2.fill",
                x: 0.20,
                y: 0.51,
                in: size
            ) {
                openCaptainChat = true
            }

            sceneActionBadge(
                title: "kitchen.mealplan.title".localized,
                systemImage: "fork.knife.circle.fill",
                x: 0.52,
                y: 0.58,
                in: size
            ) {
                openMealPlan = true
            }
        }
    }

    func sceneActionBadge(
        title: String,
        systemImage: String,
        x: CGFloat,
        y: CGFloat,
        in size: CGSize,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.black.opacity(0.85))
                .frame(width: 42, height: 42)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.58), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .position(x: size.width * x, y: size.height * y)
        .accessibilityLabel(title)
    }
}
