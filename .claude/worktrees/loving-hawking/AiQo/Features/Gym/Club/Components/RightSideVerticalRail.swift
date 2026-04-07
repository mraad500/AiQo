import SwiftUI
import UIKit

struct RailItem: Identifiable {
    let id: String
    let title: String
    let icon: String
    let tint: Color?
    let isLocked: Bool

    init(
        id: String = UUID().uuidString,
        title: String,
        icon: String,
        tint: Color? = nil,
        isLocked: Bool = false
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.tint = tint
        self.isLocked = isLocked
    }
}

enum ClubRailLayout {
    static let collapsedWidth: CGFloat = 56
    static let expandedWidth: CGFloat = 138
    static let horizontalInset: CGFloat = 12
    static let verticalInset: CGFloat = 18
    static let itemSize: CGFloat = 44
    static let itemCornerRadius: CGFloat = 24
    static let itemSpacing: CGFloat = 14
    static let hiddenOffset: CGFloat = 22
    static let contentClearance: CGFloat = expandedWidth + horizontalInset + 24
}

struct RightSideVerticalRail: View {
    let items: [RailItem]
    @Binding var selection: Int
    @Binding var isCollapsed: Bool
    @Binding var isHidden: Bool

    @Namespace private var selectionAnimation
    @State private var collapseTask: Task<Void, Never>?

    private var isEffectivelyHidden: Bool {
        isHidden && isCollapsed
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            if !isCollapsed {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        collapseRail()
                    }
                    .transition(.opacity)
            }

            railContainer
                .offset(x: isEffectivelyHidden ? ClubRailLayout.hiddenOffset : 0)
                .opacity(isEffectivelyHidden ? 0 : 1)
                .animation(.easeOut(duration: 0.25), value: isEffectivelyHidden)
                .animation(.spring(response: 0.36, dampingFraction: 0.84), value: isCollapsed)
                .padding(.trailing, ClubRailLayout.horizontalInset)
                .padding(.vertical, ClubRailLayout.verticalInset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
        .allowsHitTesting(!isEffectivelyHidden || !isCollapsed)
        .onDisappear {
            collapseTask?.cancel()
        }
    }

    private var railContainer: some View {
        VStack(spacing: ClubRailLayout.itemSpacing) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                Button {
                    handleSelection(of: index, item: item)
                } label: {
                    railItemLabel(item: item, index: index)
                }
                .buttonStyle(.plain)
                .disabled(item.isLocked)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0).onChanged { _ in
                        expandRail()
                    }
                )
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.2).onEnded { _ in
                        expandRail()
                    }
                )
                .accessibilityLabel(Text(item.title))
                .accessibilityAddTraits(selection == index ? [.isSelected] : [])
            }
        }
        .frame(width: isCollapsed ? ClubRailLayout.collapsedWidth : ClubRailLayout.expandedWidth)
        .onTapGesture {
            if isCollapsed {
                expandRail()
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 6).onChanged { _ in
                expandRail()
            }
        )
    }

    private func railItemLabel(item: RailItem, index: Int) -> some View {
        HStack(spacing: 10) {
            Image(systemName: resolvedIcon(for: item))
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(iconColor(for: item, index: index))
                .frame(width: ClubRailLayout.itemSize, height: ClubRailLayout.itemSize)

            if !isCollapsed {
                Text(item.title)
                    .font(.system(size: 14, weight: selection == index ? .bold : .semibold, design: .rounded))
                    .foregroundStyle(textColor(for: item, index: index))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(1)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, isCollapsed ? 0 : 12)
        .frame(maxWidth: .infinity, minHeight: ClubRailLayout.itemSize, alignment: .leading)
        .background(itemBackground(item: item, index: index))
        .overlay(itemOverlay(index: index))
        .opacity(item.isLocked && selection != index ? 0.8 : 1)
        .clipShape(Capsule(style: .continuous))
        .scaleEffect(selection == index ? 1.02 : 1)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: selection)
        .animation(.easeOut(duration: 0.18), value: isCollapsed)
    }

    @ViewBuilder
    private func itemBackground(item: RailItem, index: Int) -> some View {
        if selection == index {
            Capsule(style: .continuous)
                .fill((item.tint ?? AiQoColors.mint).opacity(0.65))
                .overlay(
                    Capsule(style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(0.10)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.18),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                )
                .matchedGeometryEffect(id: "rightSideRailSelection", in: selectionAnimation)
        } else {
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(0.35)
        }
    }

    private func itemOverlay(index: Int) -> some View {
        Capsule(style: .continuous)
            .stroke(
                selection == index ? Color.white.opacity(0.16) : Color.white.opacity(0.12),
                lineWidth: 0.8
            )
    }

    private func resolvedIcon(for item: RailItem) -> String {
        item.isLocked ? "lock.fill" : item.icon
    }

    private func iconColor(for item: RailItem, index: Int) -> Color {
        selection == index ? Color.black.opacity(0.9) : Color.black.opacity(item.isLocked ? 0.42 : 0.75)
    }

    private func textColor(for item: RailItem, index: Int) -> Color {
        selection == index ? Color.black.opacity(0.88) : Color.black.opacity(item.isLocked ? 0.42 : 0.75)
    }

    private func handleSelection(of index: Int, item: RailItem) {
        guard items.indices.contains(index), !item.isLocked else { return }

        collapseTask?.cancel()
        UISelectionFeedbackGenerator().selectionChanged()
        expandRail()

        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
            selection = index
            isHidden = false
        }

        scheduleCollapse()
    }

    private func expandRail() {
        collapseTask?.cancel()
        withAnimation(.spring(response: 0.36, dampingFraction: 0.84)) {
            isCollapsed = false
            isHidden = false
        }
        scheduleCollapse()
    }

    private func collapseRail() {
        collapseTask?.cancel()
        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
            isCollapsed = true
        }
    }

    private func scheduleCollapse() {
        collapseTask?.cancel()
        collapseTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                isCollapsed = true
            }
        }
    }
}

extension View {
    func clubPhysicalRightContentInset(
        layoutDirection: LayoutDirection,
        extra: CGFloat = 0
    ) -> some View {
        padding(layoutDirection == .rightToLeft ? .leading : .trailing, ClubRailLayout.contentClearance + extra)
    }

    func clubRightRailOverlay<Rail: View>(
        @ViewBuilder rail: @escaping () -> Rail
    ) -> some View {
        overlay {
            rail()
        }
    }
}
