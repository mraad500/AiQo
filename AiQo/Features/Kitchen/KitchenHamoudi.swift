import SwiftUI

struct KitchenHamoudi: View {

    @Environment(\.dismiss) private var dismiss

    @State private var message: String = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack {

                // Background image
                Image("imageKitchenHamoudi")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                // Tap to dismiss keyboard
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { isInputFocused = false }

                // Top bar: Back + Title
                VStack {
                    ZStack {
                        Text("Kitchen")
                            .font(.system(size: 21, weight: .heavy, design: .rounded))
                            .foregroundColor(.black)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 16))

                        HStack {
                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                                    .frame(width: 40, height: 40)
                                    .background(.ultraThinMaterial.opacity(0.7))
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.top, 32)

                    Spacer()
                }

                // ✅ ONLY INPUT BAR (no message)
                VStack { Spacer() }
                    .overlay(alignment: .topLeading) {

                        let panelWidth = max(230, min(geo.size.width * 0.38, 300))

                        chatInputBar(width: panelWidth)
                            .padding(.leading, 8)
                            .offset(y: geo.size.height * 0.48)
                    }
            }
        }
    }

    // MARK: - Input Bar Only
    private func chatInputBar(width: CGFloat) -> some View {
        HStack(spacing: 6) {

            TextField("اكتب رسالتك…", text: $message)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .focused($isInputFocused)
                .padding(.vertical, 6)
                .padding(.leading, 10)

            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Color.white.opacity(0.35)))
            }
        }
        .frame(width: width)
        .background(.ultraThinMaterial.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 4)
        .onTapGesture { isInputFocused = true }
    }

    private func sendMessage() {
        guard !message.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        message = ""
        isInputFocused = false
    }
}
