import SwiftUI

struct SlimRightSideRail: View {
    let items: [RailItem]
    @Binding var selection: Int

    @Namespace private var railNS

    var body: some View {
        VStack(spacing: 18) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                Button {
                    guard !item.isLocked else { return }

                    withAnimation(.spring(response: 0.38, dampingFraction: 0.88)) {
                        selection = index
                    }
                } label: {
                    ZStack {
                        if selection == index {
                            Capsule()
                                .fill((item.tint ?? AiQoColors.mint).opacity(0.65))
                                .frame(width: 46, height: 66)
                                .matchedGeometryEffect(id: "SlimRightSideRailBubble", in: railNS)
                                .zIndex(0)
                        }

                        VStack(spacing: 5) {
                            ZStack {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 34, height: 34)

                                Image(systemName: item.icon)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(selection == index ? Color.black.opacity(0.82) : Color.black.opacity(0.45))
                            }

                            Text(verbatim: item.title)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(selection == index ? Color.black.opacity(0.82) : Color.black.opacity(0.45))
                                .lineLimit(1)
                                .minimumScaleFactor(0.9)
                        }
                        .frame(maxWidth: .infinity, minHeight: 66)
                        .zIndex(1)
                    }
                    .frame(maxWidth: .infinity, minHeight: 66)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(item.isLocked)
                .frame(maxWidth: .infinity, minHeight: 66)
                .accessibilityLabel(Text(verbatim: item.title))
                .accessibilityAddTraits(selection == index ? [.isSelected] : [])
            }
        }
        .padding(6)
        .frame(width: 58)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 7)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
        .padding(.trailing, 12)
        .environment(\.layoutDirection, .leftToRight)
    }
}
