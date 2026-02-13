import HealthKit

extension HealthKitService {
    func saveWater(liters: Double) async throws {
        guard let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater) else { return }

        let quantity = HKQuantity(unit: .liter(), doubleValue: liters)
        let sample = HKQuantitySample(type: waterType, quantity: quantity, start: Date(), end: Date())

        try await store.save(sample)   // ✅ هنا
    }
}
 
