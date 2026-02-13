import SwiftUI

struct KitchenHamoudi: View {

    @Environment(\.dismiss) private var dismiss
    @State private var userMessage: String = ""
    @FocusState private var isComposerFocused: Bool

    var body: some View {
        GeometryReader { geo in
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
                        Text("Kitchen")
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

                VStack {
                    HStack(spacing: 8) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.black.opacity(0.70))

                        Text("افتح الثلاجة وكلي شتشوف")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.black)
                            .multilineTextAlignment(.leading)
                            .lineLimit(3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.regularMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.white.opacity(0.14))
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.25), lineWidth: 0.8)
                    )
                    .frame(maxWidth: geo.size.width * 0.75, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, max(geo.safeAreaInsets.top + 120, geo.size.height * 0.17))

                VStack {
                    Spacer()
                    HStack(spacing: 12) {
                        TextField("اكتب رسالة...", text: $userMessage)
                            .font(.system(size: 14))
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .foregroundStyle(.white)
                            .focused($isComposerFocused)

                        Button {
                        } label: {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 28, height: 28)
                                .background(
                                    Circle().fill(Color.blue)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.regularMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Color.black.opacity(0.34))
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.18), lineWidth: 0.8)
                    )
                    .frame(maxWidth: geo.size.width * 0.88)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, max(geo.safeAreaInsets.bottom, 14))
            }
            .onTapGesture {
                isComposerFocused = false
            }
        }
    }
}
