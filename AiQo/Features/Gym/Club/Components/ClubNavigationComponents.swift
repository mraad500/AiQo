import SwiftUI

struct GlobalTopCapsuleTabsView: View {
    let tabs: [String]
    @Binding var selection: Int

    @Namespace private var topNS

    init(
        tabs: [String],
        selection: Binding<Int>
    ) {
        self.tabs = tabs
        _selection = selection
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, title in
                Button {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                        selection = index
                    }
                } label: {
                    ZStack {
                        if selection == index {
                            Capsule()
                                .fill(AiQoColors.mint.opacity(0.85))
                                .frame(height: 44)
                                .matchedGeometryEffect(id: "TopBubble", in: topNS)
                                .overlay(
                                    Capsule()
                                        .fill(Color.white.opacity(0.10))
                                )
                                .zIndex(0)
                        }

                        Text(verbatim: title)
                            .font(.system(size: 16, weight: selection == index ? .bold : .medium))
                            .foregroundStyle(selection == index ? Color.black.opacity(0.9) : Color.gray.opacity(0.55))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .allowsTightening(true)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .zIndex(1)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, minHeight: 44)
                .accessibilityLabel(Text(verbatim: title))
                .accessibilityAddTraits(selection == index ? [.isSelected] : [])
            }
        }
        .padding(6)
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 10)
    }
}
