import SwiftUI

struct RightSideRailView: View {
    let items: [RailItem]
    @Binding var selection: Int

    var body: some View {
        VStack(spacing: 22) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                Button {
                    guard !item.isLocked else { return }
                    selection = index
                } label: {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(selection == index ? Color.white.opacity(0.30) : Color.white.opacity(0.16))

                            Image(systemName: item.icon)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(selection == index ? Color.black.opacity(0.86) : Color.gray.opacity(0.88))
                        }
                        .frame(width: 38, height: 38)

                        Text(item.title)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(selection == index ? Color.black.opacity(0.86) : Color.gray.opacity(0.88))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(itemBackground(isSelected: selection == index))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(item.title))
                .accessibilityAddTraits(selection == index ? [.isSelected] : [])
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .frame(width: 70)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                )
        )
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
        .padding(.trailing, 12)
        .padding(.vertical, 20)
    }

    private func itemBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(isSelected ? AiQoColors.mint : Color.clear)
    }
}
