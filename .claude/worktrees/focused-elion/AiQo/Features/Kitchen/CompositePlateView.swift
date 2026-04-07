import SwiftUI

struct CompositePlateView: View {
    let spec: MealImageSpec
    var maxIngredients: Int = 6

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let plateSize = side * 0.92
            let emojiScale = min(1, max(0.56, plateSize / 172))

            ZStack {
                plateShadow(size: plateSize)
                plateSurface(size: plateSize)

                if spec.ingredients.isEmpty {
                    Text("🍽️")
                        .font(.system(size: 40))
                        .scaleEffect(emojiScale)
                        .offset(y: -2)
                } else {
                    ForEach(Array(spec.ingredients.prefix(maxIngredients).enumerated()), id: \.element.id) { index, ingredient in
                        Text(ingredient.emoji)
                            .font(.system(size: 40))
                            .scaleEffect(emojiScale)
                            .rotationEffect(.degrees(rotation(for: ingredient, index: index)))
                            .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
                            .offset(offset(for: ingredient, index: index, plateSize: plateSize))
                            .accessibilityLabel(ingredient.name)
                    }
                }
            }
            .frame(width: plateSize, height: plateSize)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Meal illustration")
    }
}

private extension CompositePlateView {
    func plateShadow(size: CGFloat) -> some View {
        Ellipse()
            .fill(Color.black.opacity(0.10))
            .frame(width: size * 0.68, height: size * 0.18)
            .blur(radius: size * 0.05)
            .offset(y: size * 0.36)
    }

    func plateSurface(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.90),
                            spec.template.plateTint.opacity(0.14),
                            Color.white.opacity(0.78)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .stroke(Color.white.opacity(0.88), lineWidth: size * 0.036)

            Circle()
                .stroke(spec.template.plateTint.opacity(0.28), lineWidth: size * 0.018)
                .padding(size * 0.07)

            Circle()
                .fill(Color.white.opacity(0.42))
                .padding(size * 0.18)

            Circle()
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.82), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: size * 0.014
                )
                .padding(size * 0.12)
        }
    }

    func offset(for ingredient: PlateIngredient, index: Int, plateSize: CGFloat) -> CGSize {
        let placement = spec.template.placements[index % spec.template.placements.count]
        let centeredX = (placement.x - 0.5) * plateSize * 0.9
        let centeredY = (placement.y - 0.5) * plateSize * 0.9
        let jitter = deterministicJitter(for: ingredient.id, index: index, amplitude: plateSize * 0.045)

        return CGSize(
            width: centeredX + jitter.width,
            height: centeredY + jitter.height
        )
    }

    func rotation(for ingredient: PlateIngredient, index: Int) -> Double {
        let base = stableSeed(for: ingredient.id, index: index)
        return Double((base % 18) - 9)
    }

    func deterministicJitter(for identifier: String, index: Int, amplitude: CGFloat) -> CGSize {
        let base = stableSeed(for: identifier, index: index)
        let xValue = CGFloat(base % 1000) / 1000
        let yValue = CGFloat((base / 17) % 1000) / 1000

        return CGSize(
            width: (xValue - 0.5) * amplitude * 2,
            height: (yValue - 0.5) * amplitude * 2
        )
    }

    func stableSeed(for identifier: String, index: Int) -> Int {
        identifier.unicodeScalars.reduce((index + 1) * 97) { partialResult, scalar in
            (partialResult &* 31 &+ Int(scalar.value)) & 0x7fffffff
        }
    }
}

private extension PlateTemplate {
    var plateTint: Color {
        switch self {
        case .breakfastBowl:
            return Color(red: 0.98, green: 0.77, blue: 0.37)
        case .lunchPlate:
            return Color(red: 0.49, green: 0.74, blue: 0.46)
        case .dinnerPlate:
            return Color(red: 0.42, green: 0.62, blue: 0.88)
        case .saladBowl:
            return Color(red: 0.36, green: 0.72, blue: 0.48)
        case .snackBowl:
            return Color(red: 0.93, green: 0.62, blue: 0.37)
        case .drinkCup:
            return Color(red: 0.48, green: 0.76, blue: 0.92)
        }
    }
}
