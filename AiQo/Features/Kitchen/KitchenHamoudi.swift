import SwiftUI

struct KitchenHamoudi: View {

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {

            // Background image
            Image("imageKitchenHamoudi")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            LinearGradient(
                colors: [.clear, .black.opacity(0.20)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Top bar: Back + Title
            VStack {
                ZStack {
                    // Title
                    Text("screen.kitchen.title".localized)
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule(style: .continuous)
                                .fill(.regularMaterial)
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Color.white.opacity(0.35), lineWidth: 1)
                        )

                    // Back Button
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.blue)
                                .frame(width: 42, height: 42)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(.regularMaterial)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                                )
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.top, 32)

                Spacer()
            }
        }
    }
}
