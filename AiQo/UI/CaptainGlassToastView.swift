import SwiftUI

/// Glassmorphism toast that observes `CaptainToastCenter.shared` and slides
/// down from the top of the app. Mounted once at the root of `AppRootView`
/// so any subsystem can call `CaptainToastCenter.shared.present(...)` and
/// the message will appear regardless of which screen is on top.
struct CaptainGlassToastView: View {
    @ObservedObject private var center = CaptainToastCenter.shared

    var body: some View {
        VStack(spacing: 0) {
            if let toast = center.current {
                content(for: toast)
                    .id(toast.id)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(center.current != nil)
    }

    @ViewBuilder
    private func content(for toast: CaptainToast) -> some View {
        HStack(alignment: .top, spacing: 12) {
            if let symbol = toast.accentSymbolName {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.18))
                    )
                    .padding(.top, 1)
            }

            Text(toast.message)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                center.dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(6)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Dismiss"))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.32),
                                    Color.white.opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.8
                        )
                )
                .shadow(color: Color.black.opacity(0.22), radius: 18, x: 0, y: 8)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .onTapGesture { center.dismiss() }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }
}
