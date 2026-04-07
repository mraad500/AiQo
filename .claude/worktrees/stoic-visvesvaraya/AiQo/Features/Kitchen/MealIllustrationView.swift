import SwiftUI

struct MealIllustrationView: View {
    let spec: MealImageSpec

    var body: some View {
        CompositePlateView(spec: spec)
    }
}
