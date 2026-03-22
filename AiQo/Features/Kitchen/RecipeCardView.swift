// Features/Kitchen/RecipeCardView.swift

import SwiftUI

struct RecipeCardView: View {
    let meal: Meal

    private var illustrationSpec: MealImageSpec {
        MealImageSpecFactory.make(for: meal)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            MealIllustrationView(spec: illustrationSpec)
                .frame(width: 96, height: 96)
                .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)

            VStack(alignment: .trailing, spacing: 8) {
                Text(meal.localizedName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.black)
                    .multilineTextAlignment(.trailing)

                Text("\(meal.calories_kcal) " + "screen.kitchen.caloriesUnit".localized)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.black.opacity(0.7))
                    .multilineTextAlignment(.trailing)
            }

            Spacer()
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.kitchenMint)
        )
        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 4)
        .aiQoPressEffect()
    }
}

#if DEBUG
struct RecipeCardView_Previews: PreviewProvider {
    static var previews: some View {
        RecipeCardView(
            meal: Meal(
                id: 1,
                name_ar: "بياض بيض مع خضار",
                calories_kcal: 250,
                meal_type: .breakfast
            )
        )
        .environment(\.layoutDirection, .rightToLeft)
        .padding()
    }
}
#endif
