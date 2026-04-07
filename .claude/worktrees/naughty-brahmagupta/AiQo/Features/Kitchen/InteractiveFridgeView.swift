import SwiftData
import SwiftUI

struct InteractiveFridgeView: View {
    @EnvironmentObject private var kitchenStore: KitchenPersistenceStore

    @State private var isScannerPresented = false
    @State private var isInventoryEditorPresented = false
    @State private var highlightedItemID: UUID?

    private var sections: [FridgeShelfSection] {
        FridgeShelfSection.makeSections(from: kitchenStore.fridgeItems)
    }

    private var pickerEntries: [IngredientPickerEntry] {
        IngredientPickerEntry.makeEntries(fridgeItems: kitchenStore.fridgeItems)
    }

    var body: some View {
        GeometryReader { proxy in
            InteractiveFridgeCanvasCard(
                sections: sections,
                pickerEntries: pickerEntries,
                highlightedItemID: highlightedItemID,
                onSelectIngredient: addIngredient,
                onIncrement: incrementItem,
                onDecrement: decrementItem,
                onRemove: removeItem
            )
            .aspectRatio(871 / 1536, contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, max(proxy.safeAreaInsets.bottom, 10))
        }
        .background(InteractiveFridgeScreenBackground().ignoresSafeArea())
        .navigationTitle("kitchen.fridge.title".localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(action: presentInventoryEditor) {
                    Image(systemName: "slider.horizontal.3")
                }
                .accessibilityLabel("Open fridge list")

                Button(action: presentScanner) {
                    Image(systemName: "camera.viewfinder")
                }
                .accessibilityLabel("Scan fridge")
            }
        }
        .fullScreenCover(isPresented: $isScannerPresented) {
            SmartFridgeScannerView()
                .environmentObject(kitchenStore)
        }
        .sheet(isPresented: $isInventoryEditorPresented) {
            NavigationStack {
                FridgeInventoryView()
                    .environmentObject(kitchenStore)
            }
        }
        .modelContainer(for: SmartFridgeScannedItemRecord.self)
    }
}

private extension InteractiveFridgeView {
    func presentScanner() {
        isScannerPresented = true
    }

    func presentInventoryEditor() {
        isInventoryEditorPresented = true
    }

    func addIngredient(_ key: IngredientKey) {
        let normalizedKey = IngredientCatalog.normalize(key.localizedTitle)
        let existingID = kitchenStore.fridgeItems.first(where: {
            IngredientCatalog.normalize($0.name) == normalizedKey
        })?.id

        withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
            kitchenStore.addFridgeItem(name: key.localizedTitle, quantity: 1, unit: nil)
        }

        let targetID = existingID ?? kitchenStore.fridgeItems.first(where: {
            IngredientCatalog.normalize($0.name) == normalizedKey
        })?.id

        pulseItem(targetID)
    }

    func incrementItem(_ itemID: UUID) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.84)) {
            kitchenStore.incrementFridgeItem(id: itemID)
        }
        pulseItem(itemID)
    }

    func decrementItem(_ itemID: UUID) {
        guard let item = kitchenStore.fridgeItems.first(where: { $0.id == itemID }) else { return }

        withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
            if item.quantity <= 1 {
                kitchenStore.removeFridgeItem(id: itemID)
            } else {
                kitchenStore.decrementFridgeItem(id: itemID)
            }
        }
    }

    func removeItem(_ itemID: UUID) {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
            kitchenStore.removeFridgeItem(id: itemID)
        }
    }

    func pulseItem(_ itemID: UUID?) {
        guard let itemID else { return }

        withAnimation(.spring(response: 0.32, dampingFraction: 0.74)) {
            highlightedItemID = itemID
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            guard highlightedItemID == itemID else { return }
            withAnimation(.easeOut(duration: 0.22)) {
                highlightedItemID = nil
            }
        }
    }
}

private struct InteractiveFridgeScreenBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.93, green: 0.97, blue: 0.99),
                Color(red: 0.97, green: 0.98, blue: 0.99),
                Color(.systemGroupedBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct InteractiveFridgeCanvasCard: View {
    let sections: [FridgeShelfSection]
    let pickerEntries: [IngredientPickerEntry]
    let highlightedItemID: UUID?
    let onSelectIngredient: (IngredientKey) -> Void
    let onIncrement: (UUID) -> Void
    let onDecrement: (UUID) -> Void
    let onRemove: (UUID) -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                InteractiveFridgeCanvas(
                    size: proxy.size,
                    sections: sections,
                    highlightedItemID: highlightedItemID,
                    onIncrement: onIncrement,
                    onDecrement: onDecrement,
                    onRemove: onRemove
                )

                VStack {
                    HStack {
                        Spacer()

                        Text("\(sections.reduce(0) { $0 + $1.items.count }) عنصر")
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.kitchenMint.opacity(0.98))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.white.opacity(0.82))
                            )
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                    Spacer()
                }

                IngredientPickerRailView(
                    entries: pickerEntries,
                    onSelect: onSelectIngredient
                )
                .frame(height: min(max(proxy.size.height * 0.18, 112), 142))
                .padding(.horizontal, 14)
                .padding(.bottom, 16)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color.white.opacity(0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(0.92), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 18, x: 0, y: 10)
    }
}

private struct InteractiveFridgeCanvas: View {
    let size: CGSize
    let sections: [FridgeShelfSection]
    let highlightedItemID: UUID?
    let onIncrement: (UUID) -> Void
    let onDecrement: (UUID) -> Void
    let onRemove: (UUID) -> Void

    var body: some View {
        ZStack {
            FridgeBackgroundImage(size: size)

            FridgeShelvesOverlay(
                size: size,
                sections: sections,
                highlightedItemID: highlightedItemID,
                onIncrement: onIncrement,
                onDecrement: onDecrement,
                onRemove: onRemove
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

private struct FridgeBackgroundImage: View {
    let size: CGSize

    var body: some View {
        Group {
            if UIImage(named: "The.refrigerator") != nil {
                Image("The.refrigerator")
                    .resizable()
                    .scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
                    .overlay(
                        Text("Missing fridge asset: The.refrigerator")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(20)
                    )
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

private struct FridgeShelvesOverlay: View {
    let size: CGSize
    let sections: [FridgeShelfSection]
    let highlightedItemID: UUID?
    let onIncrement: (UUID) -> Void
    let onDecrement: (UUID) -> Void
    let onRemove: (UUID) -> Void

    var body: some View {
        ZStack {
            ForEach(sections) { section in
                let layout = shelfLayout(for: section)

                ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                    FridgePinnedItemBadge(
                        item: item,
                        tint: section.tint,
                        isHighlighted: highlightedItemID == item.id
                    )
                    .position(layout.position(for: index, total: section.items.count, in: size))
                    .contextMenu {
                        Button("fridge.addOne".localized) {
                            onIncrement(item.id)
                        }

                        Button("fridge.useOne".localized) {
                            onDecrement(item.id)
                        }

                        Button("fridge.remove".localized, role: .destructive) {
                            onRemove(item.id)
                        }
                    }
                    .transition(
                        .asymmetric(
                            insertion: .offset(y: size.height * 0.14)
                                .combined(with: .scale(scale: 0.5))
                                .combined(with: .opacity),
                            removal: .scale(scale: 0.75).combined(with: .opacity)
                        )
                    )
                }
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private func shelfLayout(for section: FridgeShelfSection) -> FridgeShelfLayout {
        switch section.id {
        case FridgeShelfBucket.proteins.id:
            return FridgeShelfLayout(yRatio: 0.27, xRange: 0.20 ... 0.80)
        case FridgeShelfBucket.vegetables.id:
            return FridgeShelfLayout(yRatio: 0.41, xRange: 0.20 ... 0.80)
        case FridgeShelfBucket.fruits.id:
            return FridgeShelfLayout(yRatio: 0.55, xRange: 0.20 ... 0.80)
        default:
            return FridgeShelfLayout(yRatio: 0.70, xRange: 0.20 ... 0.80)
        }
    }
}

private struct FridgeShelfLayout {
    let yRatio: CGFloat
    let xRange: ClosedRange<CGFloat>
    let maxColumns: Int = 5

    func position(for index: Int, total: Int, in size: CGSize) -> CGPoint {
        let columns = min(maxColumns, max(total, 1))
        let row = index / columns
        let column = index % columns
        let itemsInRow = min(columns, total - (row * columns))

        let left = xRange.lowerBound * size.width
        let right = xRange.upperBound * size.width
        let usableWidth = max(right - left, 1)
        let spacing = itemsInRow > 1 ? usableWidth / CGFloat(itemsInRow - 1) : 0
        let x = itemsInRow > 1 ? left + (CGFloat(column) * spacing) : left + (usableWidth / 2)
        let y = (yRatio * size.height) - (CGFloat(row) * size.height * 0.062)

        return CGPoint(x: x, y: y)
    }
}

private struct FridgePinnedItemBadge: View {
    let item: FridgeDisplayItem
    let tint: Color
    let isHighlighted: Bool

    var body: some View {
        ZStack {
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.08))
                .frame(width: 34, height: 6)
                .blur(radius: 1.6)
                .offset(y: 37)

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(isHighlighted ? 0.97 : 0.88))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(tint.opacity(isHighlighted ? 0.52 : 0.18), lineWidth: isHighlighted ? 1.5 : 1)
                )

            VStack(spacing: 6) {
                Text(item.emoji)
                    .font(.system(size: 28))

                Text(item.title)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.74)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 8)

            if item.quantityValueText != "1" {
                VStack {
                    HStack {
                        Spacer()

                        Text(item.quantityValueText)
                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(tint)
                            )
                    }

                    Spacer()
                }
                .padding(6)
            }
        }
        .frame(width: 56, height: 76)
        .scaleEffect(isHighlighted ? 1.08 : 1)
        .offset(y: isHighlighted ? -8 : 0)
        .shadow(
            color: tint.opacity(isHighlighted ? 0.28 : 0.12),
            radius: isHighlighted ? 14 : 7,
            x: 0,
            y: isHighlighted ? 10 : 4
        )
    }
}

private struct IngredientPickerRailView: View {
    let entries: [IngredientPickerEntry]
    let onSelect: (IngredientKey) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("fridge.addToFridge".localized)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)

                Spacer()

                Text("fridge.tapAnyItem".localized)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            IngredientPickerRailScroll(entries: entries, onSelect: onSelect)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 6)
    }
}

private struct IngredientPickerRailScroll: View {
    let entries: [IngredientPickerEntry]
    let onSelect: (IngredientKey) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 10) {
                ForEach(entries) { entry in
                    IngredientPickerCard(
                        entry: entry,
                        onTap: { onSelect(entry.key) }
                    )
                }
            }
            .padding(.vertical, 2)
        }
    }
}

private struct IngredientPickerCard: View {
    let entry: IngredientPickerEntry
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                FridgeEmojiBadge(
                    emoji: entry.emoji,
                    tint: entry.isStored ? Color.green : Color.kitchenMint,
                    size: 40
                )

                Text(entry.title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                IngredientPickerBadge(isStored: entry.isStored)
            }
            .frame(width: 86, height: 94)
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.92))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke((entry.isStored ? Color.green : Color.kitchenMint).opacity(0.22), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct IngredientPickerBadge: View {
    let isStored: Bool

    var body: some View {
        Text(isStored ? "+1" : "fridge.add".localized)
            .font(.system(size: 10, weight: .heavy, design: .rounded))
            .foregroundStyle(isStored ? Color.green : Color.blue)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill((isStored ? Color.green : Color.blue).opacity(0.12))
            )
    }
}

private struct FridgeShelfSection: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let tint: Color
    let items: [FridgeDisplayItem]

    static func makeSections(from fridgeItems: [FridgeItem]) -> [FridgeShelfSection] {
        let sortedItems = fridgeItems.sorted { lhs, rhs in
            if lhs.updatedAt != rhs.updatedAt {
                return lhs.updatedAt > rhs.updatedAt
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }

        var buckets: [FridgeShelfBucket: [FridgeDisplayItem]] = [:]

        for item in sortedItems {
            let bucket = FridgeShelfBucket.bucket(for: item)
            let displayItem = FridgeDisplayItem(item: item)
            buckets[bucket, default: []].append(displayItem)
        }

        return FridgeShelfBucket.allCases.map { bucket in
            FridgeShelfSection(
                id: bucket.id,
                title: bucket.title,
                subtitle: bucket.subtitle,
                tint: bucket.tint,
                items: buckets[bucket] ?? []
            )
        }
    }
}

private struct FridgeDisplayItem: Identifiable {
    let id: UUID
    let title: String
    let emoji: String
    let quantityText: String
    let quantityValueText: String

    init(item: FridgeItem) {
        self.id = item.id
        self.title = item.name
        self.emoji = item.emoji
        self.quantityText = FridgeTextFormatter.quantity(item.quantity, unit: item.unit)
        self.quantityValueText = FridgeTextFormatter.value(item.quantity)
    }
}

private enum FridgeShelfBucket: CaseIterable {
    case proteins
    case vegetables
    case fruits
    case essentials

    var id: String {
        switch self {
        case .proteins:
            return "proteins"
        case .vegetables:
            return "vegetables"
        case .fruits:
            return "fruits"
        case .essentials:
            return "essentials"
        }
    }

    var title: String {
        switch self {
        case .proteins:
            return "Top Shelf"
        case .vegetables:
            return "Second Shelf"
        case .fruits:
            return "Third Shelf"
        case .essentials:
            return "Bottom Shelf"
        }
    }

    var subtitle: String {
        switch self {
        case .proteins:
            return "Proteins and dairy"
        case .vegetables:
            return "Vegetables and greens"
        case .fruits:
            return "Fresh fruit"
        case .essentials:
            return "Carbs, drinks and extras"
        }
    }

    var tint: Color {
        switch self {
        case .proteins:
            return Color(red: 0.87, green: 0.33, blue: 0.27)
        case .vegetables:
            return Color(red: 0.21, green: 0.58, blue: 0.34)
        case .fruits:
            return Color(red: 0.96, green: 0.62, blue: 0.28)
        case .essentials:
            return Color(red: 0.22, green: 0.42, blue: 0.78)
        }
    }

    static func bucket(for item: FridgeItem) -> FridgeShelfBucket {
        guard let key = IngredientCatalog.match(from: item.name) else {
            return .essentials
        }

        switch key.category {
        case .protein, .dairy:
            return .proteins
        case .veg:
            return .vegetables
        case .fruit:
            return .fruits
        case .carb, .fat, .drink, .other:
            return .essentials
        }
    }
}

private struct IngredientPickerEntry: Identifiable {
    let id: String
    let key: IngredientKey
    let title: String
    let emoji: String
    let isStored: Bool

    static func makeEntries(fridgeItems: [FridgeItem]) -> [IngredientPickerEntry] {
        let storedKeys = Set(fridgeItems.compactMap { IngredientCatalog.match(from: $0.name) })

        let sortedKeys = IngredientKey.allCases.sorted { lhs, rhs in
            if lhs.category.priority != rhs.category.priority {
                return lhs.category.priority < rhs.category.priority
            }
            return lhs.localizedTitle.localizedCaseInsensitiveCompare(rhs.localizedTitle) == .orderedAscending
        }

        return sortedKeys.map { key in
            IngredientPickerEntry(
                id: key.rawValue,
                key: key,
                title: key.localizedTitle,
                emoji: key.emoji,
                isStored: storedKeys.contains(key)
            )
        }
    }
}

private struct FridgeEmojiBadge: View {
    let emoji: String
    let tint: Color
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.14))

            Circle()
                .stroke(Color.white.opacity(0.82), lineWidth: 1)

            Text(emoji)
                .font(.system(size: size * 0.52))
        }
        .frame(width: size, height: size)
    }
}

private enum FridgeTextFormatter {
    static func quantity(_ quantity: Double, unit: String?) -> String {
        let valueText = value(quantity)

        guard let unit, !unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return valueText
        }

        return "\(valueText) \(unit)"
    }

    static func value(_ quantity: Double) -> String {
        if quantity.rounded() == quantity {
            return "\(Int(quantity))"
        }
        return String(format: "%.1f", quantity)
    }
}

#if DEBUG
struct InteractiveFridgeView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            InteractiveFridgeView()
                .environmentObject(previewStore)
        }
    }

    private static var previewStore: KitchenPersistenceStore {
        let store = KitchenPersistenceStore(defaults: UserDefaults(suiteName: "InteractiveFridgePreview") ?? .standard)
        store.fridgeItems = [
            FridgeItem(name: "Egg", quantity: 6),
            FridgeItem(name: "Milk", quantity: 2, unit: "bottles"),
            FridgeItem(name: "Tomato", quantity: 4),
            FridgeItem(name: "Cucumber", quantity: 3),
            FridgeItem(name: "Rice", quantity: 1, unit: "bag")
        ]
        return store
    }
}
#endif
