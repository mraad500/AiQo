import SwiftUI
import UIKit

struct MealIllustrationView: View {
    let spec: MealImageSpec

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let placements = spec.template.placements

            ZStack {
                spec.template.backgroundView
                    .frame(width: size.width, height: size.height)

                if spec.ingredients.isEmpty {
                    Image(systemName: "questionmark")
                        .font(.system(size: min(size.width, size.height) * 0.28, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.primary.opacity(0.42))
                } else {
                    ForEach(Array(spec.ingredients.prefix(placements.count).enumerated()), id: \.offset) { index, ingredient in
                        ingredientSticker(
                            ingredient,
                            placement: placements[index],
                            size: size
                        )
                    }
                }
            }
            .frame(width: size.width, height: size.height)
        }
    }
}

private extension MealIllustrationView {
    @ViewBuilder
    func ingredientSticker(_ ingredient: IngredientKey, placement: PlatePlacement, size: CGSize) -> some View {
        let dimension = min(size.width, size.height) * placement.scale * 1.5

        if let image = IngredientAssetCatalog.uiImage(for: ingredient) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: dimension, height: dimension)
                .rotationEffect(.degrees(placement.rotation))
                .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
                .position(x: size.width * placement.x, y: size.height * placement.y)
        } else {
            ZStack {
                Circle()
                    .fill(Color(.systemBackground).opacity(0.88))
                Image(systemName: "questionmark")
                    .font(.system(size: dimension * 0.36, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .frame(width: dimension * 0.78, height: dimension * 0.78)
            .rotationEffect(.degrees(placement.rotation))
            .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 2)
            .position(x: size.width * placement.x, y: size.height * placement.y)
        }
    }
}
