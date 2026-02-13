import SwiftUI

// =========================
// File: Features/Gym/WinsView.swift
// SwiftUI - Wins Screen with Bottom Glass Sheet (50%)
// =========================

// MARK: - 1) Colors & Styles
struct RecapStyle {
    static let orange = Color(red: 1.00, green: 0.78, blue: 0.45)
    static let turquoise = Color(red: 0.25, green: 0.85, blue: 0.70)
    static let purple = Color(red: 0.66, green: 0.58, blue: 0.98)
    static let lime = Color(red: 0.72, green: 0.86, blue: 0.34)

    static let glassIntensity: Double = 0.35
}

struct SoftGlassCardBackground: ViewModifier {
    let tint: Color
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(tint.opacity(RecapStyle.glassIntensity))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.35), lineWidth: 0.6)
                    )
                    .shadow(color: tint.opacity(0.14), radius: 12, x: 0, y: 8)
            )
    }
}

extension View {
    func softGlassCardStyle(tint: Color) -> some View {
        modifier(SoftGlassCardBackground(tint: tint))
    }
}

// MARK: - 2) Data Model
struct WinItem: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let themeColor: Color
    let progress: Double
    let isLocked: Bool

    // Detail mock
    let detailValue: String
    let detailHint: String
    let graphData: [CGFloat]
}

// MARK: - 3) Wins View
struct WinsView: View {

    private let items: [WinItem] = [
        .init(title: L10n.t("wins.item.streak.title"), subtitle: L10n.t("wins.item.streak.subtitle"), icon: "flame.fill", themeColor: RecapStyle.orange, progress: 0.35, isLocked: true,
              detailValue: L10n.t("wins.item.streak.detail_value"), detailHint: L10n.t("wins.item.streak.detail_hint"), graphData: [0.25, 0.35, 0.22, 0.55, 0.40, 0.62, 0.80]),
        .init(title: L10n.t("wins.item.heart.title"), subtitle: L10n.t("wins.item.heart.subtitle"), icon: "heart.fill", themeColor: RecapStyle.purple, progress: 0.62, isLocked: true,
              detailValue: L10n.t("wins.item.heart.detail_value"), detailHint: L10n.t("wins.item.heart.detail_hint"), graphData: [0.30, 0.45, 0.28, 0.70, 0.52, 0.60, 0.78]),
        .init(title: L10n.t("wins.item.steps.title"), subtitle: L10n.t("wins.item.steps.subtitle"), icon: "figure.walk", themeColor: RecapStyle.turquoise, progress: 1.0, isLocked: false,
              detailValue: L10n.t("wins.item.steps.detail_value"), detailHint: L10n.t("wins.item.steps.detail_hint"), graphData: [0.18, 0.35, 0.55, 0.60, 0.90, 0.72, 0.64]),
        .init(title: L10n.t("wins.item.gratitude.title"), subtitle: L10n.t("wins.item.gratitude.subtitle"), icon: "sparkles", themeColor: RecapStyle.lime, progress: 0.20, isLocked: true,
              detailValue: L10n.t("wins.item.gratitude.detail_value"), detailHint: L10n.t("wins.item.gratitude.detail_hint"), graphData: [0.10, 0.18, 0.12, 0.22, 0.16, 0.20, 0.26])
    ]

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    @State private var selectedItem: WinItem? = nil
    @State private var showSheet = false

    var body: some View {
        ZStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection

                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(items) { item in
                            WinCardButton(item: item) {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                    selectedItem = item
                                    showSheet = true
                                }
                            }
                        }
                    }

                    divider

                    FeaturedWinCard(
                        title: L10n.t("wins.featured.title"),
                        subtitle: L10n.t("wins.featured.subtitle"),
                        icon: "gift.fill",
                        themeColor: RecapStyle.turquoise,
                        progress: 0.55
                    )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .blur(radius: showSheet ? 6 : 0)
            .animation(.easeOut(duration: 0.18), value: showSheet)

            // Dim layer
            if showSheet {
                Color.black.opacity(0.30)
                    .ignoresSafeArea()
                    .onTapGesture { closeSheet() }
                    .transition(.opacity)
            }

            // Bottom sheet (50%)
            if let item = selectedItem, showSheet {
                BottomGlassSheet(
                    item: item,
                    heightRatio: 0.50,          // <- غيرها اذا تريد 0.55 او 0.45
                    onClose: { closeSheet() }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(5)
            }
        }
        .fontDesign(.rounded) // خط دائري على كل الشاشة
    }

    private func closeSheet() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
            showSheet = false
        }
        // نخليها تتصفّر بعد الانميشن حتى ما يصير glitch
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            if !showSheet { selectedItem = nil }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.t("wins.title"))
                .font(.system(size: 34, weight: .heavy))
                .foregroundColor(.primary)

            Text(L10n.t("wins.subtitle"))
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.top, 10)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color(.systemGray5))
            .frame(height: 1)
            .padding(.vertical, 8)
    }
}

// MARK: - 4) Win Card Button (Press squash)
struct WinCardButton: View {
    let item: WinItem
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        WinCardView(item: item)
            .scaleEffect(x: 1.0, y: isPressed ? 0.92 : 1.0, anchor: .bottom)
            .animation(.spring(response: 0.28, dampingFraction: 0.55), value: isPressed)
            .onTapGesture {
                isPressed = true
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                    isPressed = false
                    action()
                }
            }
    }
}

// MARK: - 5) Win Card Design
struct WinCardView: View {
    let item: WinItem

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 0) {

                // Icon
                ZStack {
                    Circle()
                        .fill(item.themeColor.opacity(0.20))
                        .frame(width: 44, height: 44)

                    Image(systemName: item.icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(item.themeColor)
                }
                .padding(.top, 16)
                .padding(.leading, 16)

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text(item.subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                .padding(.horizontal, 16)

                Spacer()

                ProgressBarView(progress: item.progress, tintColor: item.themeColor)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 18)
            }
            .frame(height: 160)
            .frame(maxWidth: .infinity)
            .softGlassCardStyle(tint: item.themeColor)

            Image(systemName: item.isLocked ? "lock.fill" : "checkmark.seal.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(item.isLocked ? item.themeColor.opacity(0.5) : item.themeColor)
                .padding(16)
        }
    }
}

// MARK: - 6) Bottom Glass Sheet (50% from bottom)
struct BottomGlassSheet: View {
    let item: WinItem
    let heightRatio: CGFloat
    let onClose: () -> Void

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let fullH = geo.size.height
            let sheetH = max(260, fullH * heightRatio)
            let bottomSafe = geo.safeAreaInsets.bottom

            VStack(spacing: 0) {

                // Handle + Close
                HStack(spacing: 10) {
                    Capsule()
                        .fill(Color.white.opacity(0.45))
                        .frame(width: 44, height: 5)
                        .padding(.leading, 12)

                    Spacer()

                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(10)
                            .background(Circle().fill(Color.white.opacity(0.35)))
                    }
                    .padding(.trailing, 12)
                }
                .padding(.top, 10)
                .padding(.bottom, 8)

                // Content
                SheetContent(item: item)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 14)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .frame(height: sheetH)
            .background(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 34, style: .continuous)
                            .stroke(Color.white.opacity(0.22), lineWidth: 0.8)
                    )
                    .shadow(color: .black.opacity(0.22), radius: 26, x: 0, y: -4)
            )
            .overlay(
                // subtle tint from the item color
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(item.themeColor.opacity(0.12))
                    .allowsHitTesting(false)
            )
            .padding(.horizontal, 12)
            .padding(.bottom, max(10, bottomSafe)) // يحترم Safe Area
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .offset(y: max(0, dragOffset))
            .gesture(
                DragGesture(minimumDistance: 6, coordinateSpace: .global)
                    .onChanged { value in
                        let dy = value.translation.height
                        if dy > 0 { dragOffset = dy } // بس نزول
                    }
                    .onEnded { value in
                        let dy = value.translation.height
                        let shouldClose = dy > 120 || value.velocity.height > 900
                        if shouldClose {
                            onClose()
                        } else {
                            withAnimation(.spring(response: 0.30, dampingFraction: 0.85)) {
                                dragOffset = 0
                            }
                        }
                    }
            )
            .onChange(of: item.id) {
                dragOffset = 0
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - 7) Sheet Content
struct SheetContent: View {
    let item: WinItem
    @State private var selectedTab: SheetTab = .day

    private enum SheetTab: CaseIterable, Identifiable {
        case day, week, month, year
        var id: String { title }
        var title: String {
            switch self {
            case .day: return NSLocalizedString("time.day", value: "Day", comment: "")
            case .week: return NSLocalizedString("time.week", value: "Week", comment: "")
            case .month: return NSLocalizedString("time.month", value: "Month", comment: "")
            case .year: return NSLocalizedString("time.year", value: "Year", comment: "")
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Title row
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(item.themeColor.opacity(0.18))
                        .frame(width: 44, height: 44)

                    Image(systemName: item.icon)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(item.themeColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundColor(.primary)

                    Text(item.detailHint)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.top, 6)

            // Big value + progress
            HStack(alignment: .lastTextBaseline) {
                Text(item.detailValue)
                    .font(.system(size: 38, weight: .heavy))
                    .foregroundColor(.primary)

                Spacer()

                HStack(spacing: 8) {
                    Image(systemName: item.isLocked ? "lock.fill" : "checkmark.seal.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(item.isLocked ? item.themeColor.opacity(0.55) : item.themeColor)

                    Text("\(Int(item.progress * 100))%")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundColor(.secondary)
                }
            }

            ProgressBarView(progress: item.progress, tintColor: item.themeColor)
                .frame(height: 7)
                .padding(.top, 2)

            // Tabs
            HStack(spacing: 0) {
                ForEach(SheetTab.allCases) { tab in
                    Text(tab.title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(selectedTab == tab ? .primary : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(selectedTab == tab ? Color.white.opacity(0.55) : Color.clear)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeOut(duration: 0.18)) {
                                selectedTab = tab
                            }
                        }
                }
            }
            .padding(5)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.20))
            )

            // Graph
            HStack(alignment: .bottom, spacing: 12) {
                ForEach(Array(item.graphData.enumerated()), id: \.offset) { idx, v in
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(item.themeColor.opacity(highlightIndex(for: selectedTab) == idx ? 1.0 : 0.28))
                        .frame(width: 14, height: 120 * max(0.08, v))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 130, alignment: .bottom)
            .padding(.top, 8)

            // Reward shield
            RewardShieldView(tint: item.themeColor, isLocked: item.isLocked)
                .padding(.top, 6)

            // Small notes
            HStack {
                Text(item.isLocked ? L10n.t("wins.sheet.keep_going") : L10n.t("wins.sheet.unlocked"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)

                Spacer()

                Text(L10n.t("wins.sheet.swipe_close"))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.75))
            }
            .padding(.top, 4)
        }
    }

    private func highlightIndex(for tab: SheetTab) -> Int {
        // بس حتى يتغير “العمود المميز” حسب التبويب
        switch tab {
        case .day: return 4
        case .week: return 5
        case .month: return 3
        case .year: return 6
        }
    }
}

// MARK: - Reward Shield
struct RewardShieldView: View {
    let tint: Color
    let isLocked: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(tint.opacity(0.18))
                    .frame(width: 78, height: 78)

                Image(systemName: "shield.fill")
                    .font(.system(size: 34, weight: .heavy))
                    .foregroundColor(tint)

                if isLocked {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(0.8)
                        .blur(radius: 3)
                        .frame(width: 78, height: 78)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.t("wins.sheet.reward_title"))
                    .font(.system(size: 15, weight: .bold))
                Text(L10n.t("wins.sheet.reward_desc"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.35))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.30), lineWidth: 0.6)
        )
    }
}

// MARK: - 8) Featured Win Card
struct FeaturedWinCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let themeColor: Color
    let progress: Double

    @State private var isPressed = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(themeColor.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(themeColor)
            }
            .padding(.top, 16)
            .padding(.leading, 16)

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundColor(.primary)

                    Text(subtitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                .padding(.top, 16)

                ProgressBarView(progress: progress, tintColor: themeColor)
                    .padding(.trailing, 16)
                    .padding(.bottom, 16)
            }
        }
        .softGlassCardStyle(tint: themeColor)
        .frame(height: 110)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .onTapGesture {
            withAnimation(.easeOut(duration: 0.1)) { isPressed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation { isPressed = false }
            }
        }
    }
}

// MARK: - 9) Progress Bar View
struct ProgressBarView: View {
    let progress: Double
    let tintColor: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.primary.opacity(0.07))

                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(tintColor)
                    .frame(width: geo.size.width * min(max(progress, 0), 1))
            }
        }
        .frame(height: 6)
    }
}

// MARK: - Preview
#Preview {
    WinsView()
        .preferredColorScheme(.light)
}
