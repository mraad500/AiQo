import SwiftData
import SwiftUI

struct InteractiveFridgeView: View {
    @EnvironmentObject private var kitchenStore: KitchenPersistenceStore

    @State private var isScannerPresented = false
    @State private var isInventoryEditorPresented = false

    private var sections: [FridgeShelfSection] {
        FridgeShelfSection.makeSections(from: kitchenStore.fridgeItems)
    }

    private var pickerEntries: [IngredientPickerEntry] {
        IngredientPickerEntry.makeEntries(fridgeItems: kitchenStore.fridgeItems)
    }

    private var totalItemCount: Int {
        kitchenStore.fridgeItems.count
    }

    private var totalUnits: Double {
        kitchenStore.fridgeItems.reduce(0) { partialResult, item in
            partialResult + item.quantity
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            InteractiveFridgeContent(
                totalItemCount: totalItemCount,
                totalUnits: totalUnits,
                sections: sections,
                onScanTap: presentScanner,
                onListTap: presentInventoryEditor,
                onIncrement: incrementItem,
                onDecrement: decrementItem,
                onRemove: removeItem
            )
        }
        .background(InteractiveFridgeScreenBackground().ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            IngredientPickerRailView(
                entries: pickerEntries,
                onSelect: addIngredient
            )
        }
        .navigationTitle("kitchen.fridge.title".localized)
        .navigationBarTitleDisplayMode(.inline)
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
        kitchenStore.addFridgeItem(name: key.localizedTitle, quantity: 1, unit: nil)
    }

    func incrementItem(_ itemID: UUID) {
        kitchenStore.incrementFridgeItem(id: itemID)
    }

    func decrementItem(_ itemID: UUID) {
        kitchenStore.decrementFridgeItem(id: itemID)
    }

    func removeItem(_ itemID: UUID) {
        kitchenStore.removeFridgeItem(id: itemID)
    }
}

private struct InteractiveFridgeContent: View {
    let totalItemCount: Int
    let totalUnits: Double
    let sections: [FridgeShelfSection]
    let onScanTap: () -> Void
    let onListTap: () -> Void
    let onIncrement: (UUID) -> Void
    let onDecrement: (UUID) -> Void
    let onRemove: (UUID) -> Void

    var body: some View {
        VStack(spacing: 18) {
            InteractiveFridgeHeroCard(
                totalItemCount: totalItemCount,
                totalUnits: totalUnits,
                onScanTap: onScanTap,
                onListTap: onListTap
            )

            InteractiveFridgeCanvasCard(
                sections: sections,
                onIncrement: onIncrement,
                onDecrement: onDecrement,
                onRemove: onRemove
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 24)
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

private struct InteractiveFridgeHeroCard: View {
    let totalItemCount: Int
    let totalUnits: Double
    let onScanTap: () -> Void
    let onListTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            FridgeHeroTextBlock()
            FridgeHeroMetricsRow(totalItemCount: totalItemCount, totalUnits: totalUnits)
            FridgeHeroActionRow(onScanTap: onScanTap, onListTap: onListTap)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.58), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 8)
    }
}

private struct FridgeHeroTextBlock: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Emoji Interactive Fridge")
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(.primary)

            Text("Use native food emoji to stock shelves instantly, then scan the real fridge whenever you want to merge live inventory.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }
}

private struct FridgeHeroMetricsRow: View {
    let totalItemCount: Int
    let totalUnits: Double

    var body: some View {
        HStack(spacing: 12) {
            FridgeMetricBadge(
                title: "Stored Items",
                value: "\(totalItemCount)"
            )

            FridgeMetricBadge(
                title: "Total Units",
                value: FridgeTextFormatter.quantity(totalUnits, unit: nil)
            )
        }
    }
}

private struct FridgeMetricBadge: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.primary)

            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.7))
        )
    }
}

private struct FridgeHeroActionRow: View {
    let onScanTap: () -> Void
    let onListTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            FridgeActionButton(
                title: "Scan Fridge",
                systemImage: "camera.viewfinder",
                fillColor: Color.kitchenMint,
                foregroundColor: .black,
                action: onScanTap
            )

            FridgeActionButton(
                title: "Open List",
                systemImage: "slider.horizontal.3",
                fillColor: Color(.secondarySystemBackground),
                foregroundColor: .primary,
                action: onListTap
            )
        }
    }
}

private struct FridgeActionButton: View {
    let title: String
    let systemImage: String
    let fillColor: Color
    let foregroundColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 46)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(fillColor)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct InteractiveFridgeCanvasCard: View {
    let sections: [FridgeShelfSection]
    let onIncrement: (UUID) -> Void
    let onDecrement: (UUID) -> Void
    let onRemove: (UUID) -> Void

    var body: some View {
        GeometryReader { proxy in
            InteractiveFridgeCanvas(
                size: proxy.size,
                sections: sections,
                onIncrement: onIncrement,
                onDecrement: onDecrement,
                onRemove: onRemove
            )
        }
        .aspectRatio(0.74, contentMode: .fit)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.10), radius: 20, x: 0, y: 10)
    }
}

private struct InteractiveFridgeCanvas: View {
    let size: CGSize
    let sections: [FridgeShelfSection]
    let onIncrement: (UUID) -> Void
    let onDecrement: (UUID) -> Void
    let onRemove: (UUID) -> Void

    var body: some View {
        ZStack {
            FridgeBackgroundImage(size: size)
            FridgeShelvesOverlay(
                size: size,
                sections: sections,
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
            if UIImage(named: "The refrigerator.1") != nil {
                Image("The refrigerator.1")
                    .resizable()
                    .scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
                    .overlay(
                        Text("Missing fridge asset: The refrigerator.1")
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
    let onIncrement: (UUID) -> Void
    let onDecrement: (UUID) -> Void
    let onRemove: (UUID) -> Void

    private var shelfSpacing: CGFloat {
        size.height * 0.032
    }

    private var horizontalPadding: CGFloat {
        size.width * 0.18
    }

    private var topPadding: CGFloat {
        size.height * 0.115
    }

    private var bottomPadding: CGFloat {
        size.height * 0.14
    }

    var body: some View {
        VStack(spacing: shelfSpacing) {
            ForEach(sections) { section in
                FridgeShelfView(
                    section: section,
                    onIncrement: onIncrement,
                    onDecrement: onDecrement,
                    onRemove: onRemove
                )
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, topPadding)
        .padding(.bottom, bottomPadding)
        .frame(width: size.width, height: size.height, alignment: .top)
    }
}

private struct FridgeShelfView: View {
    let section: FridgeShelfSection
    let onIncrement: (UUID) -> Void
    let onDecrement: (UUID) -> Void
    let onRemove: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            FridgeShelfHeaderView(section: section)
            FridgeShelfContentView(
                section: section,
                onIncrement: onIncrement,
                onDecrement: onDecrement,
                onRemove: onRemove
            )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.78))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(section.tint.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct FridgeShelfHeaderView: View {
    let section: FridgeShelfSection

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(section.title)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(section.tint)

            Text(section.subtitle)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }
}

private struct FridgeShelfContentView: View {
    let section: FridgeShelfSection
    let onIncrement: (UUID) -> Void
    let onDecrement: (UUID) -> Void
    let onRemove: (UUID) -> Void

    var body: some View {
        Group {
            if section.items.isEmpty {
                EmptyFridgeShelfState(tint: section.tint)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(section.items) { item in
                            FridgeStoredItemCard(
                                item: item,
                                tint: section.tint,
                                onIncrement: { onIncrement(item.id) },
                                onDecrement: { onDecrement(item.id) },
                                onRemove: { onRemove(item.id) }
                            )
                        }
                    }
                }
            }
        }
    }
}

private struct EmptyFridgeShelfState: View {
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(tint)

            Text("No items here yet")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

private struct FridgeStoredItemCard: View {
    let item: FridgeDisplayItem
    let tint: Color
    let onIncrement: () -> Void
    let onDecrement: () -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            FridgeStoredItemHeader(item: item, tint: tint, onRemove: onRemove)
            FridgeStoredItemText(item: item)
            FridgeStoredItemStepper(
                onIncrement: onIncrement,
                onDecrement: onDecrement
            )
        }
        .frame(width: 138, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground))
        )
    }
}

private struct FridgeStoredItemHeader: View {
    let item: FridgeDisplayItem
    let tint: Color
    let onRemove: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            FridgeEmojiBadge(
                emoji: item.emoji,
                tint: tint,
                size: 40
            )

            Spacer(minLength: 0)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct FridgeStoredItemText: View {
    let item: FridgeDisplayItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(2)

            Text(item.quantityText)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            if let alchemyNote = item.alchemyNote {
                Text(alchemyNote)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(red: 0.19, green: 0.49, blue: 0.90))
                    .lineLimit(2)
            }
        }
    }
}

private struct FridgeStoredItemStepper: View {
    let onIncrement: () -> Void
    let onDecrement: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            StepperIconButton(systemImage: "minus.circle.fill", action: onDecrement)
            StepperIconButton(systemImage: "plus.circle.fill", action: onIncrement)
        }
    }
}

private struct StepperIconButton: View {
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
        .frame(width: 32, height: 32)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

private struct IngredientPickerRailView: View {
    let entries: [IngredientPickerEntry]
    let onSelect: (IngredientKey) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            IngredientPickerRailHeader()
            IngredientPickerRailScroll(entries: entries, onSelect: onSelect)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 18)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}

private struct IngredientPickerRailHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Emoji Quick Add")
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(.primary)

            Text("Tap a chip to drop its ingredient straight onto the fridge shelves.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }
}

private struct IngredientPickerRailScroll: View {
    let entries: [IngredientPickerEntry]
    let onSelect: (IngredientKey) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
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
            HStack(spacing: 10) {
                FridgeEmojiBadge(
                    emoji: entry.emoji,
                    tint: entry.isStored ? Color.green : Color.kitchenMint,
                    size: 42
                )

                VStack(alignment: .leading, spacing: 5) {
                    Text(entry.title)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    IngredientPickerBadge(isStored: entry.isStored)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.86))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke((entry.isStored ? Color.green : Color.kitchenMint).opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct IngredientPickerBadge: View {
    let isStored: Bool

    var body: some View {
        Text(isStored ? "Stored" : "Add +1")
            .font(.system(size: 11, weight: .heavy, design: .rounded))
            .foregroundStyle(isStored ? Color.green : Color.blue)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
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
    let alchemyNote: String?

    init(item: FridgeItem) {
        self.id = item.id
        self.title = item.name
        self.emoji = item.emoji
        self.quantityText = FridgeTextFormatter.quantity(item.quantity, unit: item.unit)
        self.alchemyNote = item.localizedAlchemyNote
    }
}

private enum FridgeShelfBucket: CaseIterable {
    case proteins
    case produce
    case essentials

    var id: String {
        switch self {
        case .proteins:
            return "proteins"
        case .produce:
            return "produce"
        case .essentials:
            return "essentials"
        }
    }

    var title: String {
        switch self {
        case .proteins:
            return "Top Shelf"
        case .produce:
            return "Middle Shelf"
        case .essentials:
            return "Drawer"
        }
    }

    var subtitle: String {
        switch self {
        case .proteins:
            return "Proteins and dairy"
        case .produce:
            return "Fruit and vegetables"
        case .essentials:
            return "Carbs, drinks and extras"
        }
    }

    var tint: Color {
        switch self {
        case .proteins:
            return Color(red: 0.87, green: 0.33, blue: 0.27)
        case .produce:
            return Color(red: 0.21, green: 0.58, blue: 0.34)
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
        case .veg, .fruit:
            return .produce
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
        let valueText: String
        if quantity.rounded() == quantity {
            valueText = "\(Int(quantity))"
        } else {
            valueText = String(format: "%.1f", quantity)
        }

        guard let unit, !unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return valueText
        }

        return "\(valueText) \(unit)"
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
