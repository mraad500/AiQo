import SwiftUI

struct FridgeInventoryView: View {
    @EnvironmentObject private var kitchenStore: KitchenPersistenceStore
    @State private var itemName: String = ""
    @State private var itemQuantity: String = "1"
    @State private var itemUnit: String = ""

    var body: some View {
        List {
            addItemSection
            cameraSection
            inventorySection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("kitchen.fridge.title".localized)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private extension FridgeInventoryView {
    var addItemSection: some View {
        Section("kitchen.fridge.add".localized) {
            TextField("kitchen.fridge.itemNamePlaceholder".localized, text: $itemName)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            TextField("kitchen.fridge.quantityPlaceholder".localized, text: $itemQuantity)
                .keyboardType(.decimalPad)

            TextField("kitchen.fridge.unitPlaceholder".localized, text: $itemUnit)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Button(action: addItem) {
                Label("kitchen.fridge.addButton".localized, systemImage: "plus.circle.fill")
            }
            .disabled(itemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    var cameraSection: some View {
        Section {
            Button {
                // TODO: Wire VisionKit / camera scan when camera permissions + scanner flow are ready.
                print("TODO: fridge camera scan action")
            } label: {
                Label("kitchen.fridge.camera".localized, systemImage: "camera.viewfinder")
            }
        }
    }

    var inventorySection: some View {
        Section("kitchen.fridge.inventory".localized) {
            if kitchenStore.fridgeItems.isEmpty {
                Text("kitchen.fridge.empty".localized)
                    .foregroundColor(.secondary)
            } else {
                ForEach(kitchenStore.fridgeItems) { item in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                            Text(formattedQuantity(item.quantity, unit: item.unit))
                                .font(.system(size: 14, weight: .regular, design: .rounded))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        HStack(spacing: 10) {
                            Button {
                                kitchenStore.decrementFridgeItem(id: item.id)
                            } label: {
                                Image(systemName: "minus.circle")
                                    .font(.title3)
                            }
                            .buttonStyle(.plain)

                            Text(formattedQuantity(item.quantity, unit: nil))
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .frame(minWidth: 40)

                            Button {
                                kitchenStore.incrementFridgeItem(id: item.id)
                            } label: {
                                Image(systemName: "plus.circle")
                                    .font(.title3)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            kitchenStore.removeFridgeItem(id: item.id)
                        } label: {
                            Label("kitchen.delete".localized, systemImage: "trash")
                        }
                    }
                }
                .onDelete(perform: kitchenStore.removeFridgeItems)
            }
        }
    }

    func addItem() {
        let quantity = Double(itemQuantity.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 1
        kitchenStore.addFridgeItem(name: itemName, quantity: quantity, unit: itemUnit)

        itemName = ""
        itemQuantity = "1"
        itemUnit = ""
    }

    func formattedQuantity(_ quantity: Double, unit: String?) -> String {
        let valueText: String
        if quantity.rounded() == quantity {
            valueText = "\(Int(quantity))"
        } else {
            valueText = String(format: "%.1f", quantity)
        }

        if let unit, !unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "\(valueText) \(unit)"
        }
        return valueText
    }
}
