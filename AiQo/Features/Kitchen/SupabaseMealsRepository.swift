import Foundation
import Supabase
import UIKit

final class SupabaseMealsRepository: MealsRepository {

    static let shared = SupabaseMealsRepository()

    private let client: SupabaseClient

    private init() {
        self.client = SupabaseService.shared.client
    }

    func fetchAllMeals() async throws -> [Meal] {
        let response = try await client
            .from("meals")
            .select()
            .execute()

        let data = response.data
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        return try decoder.decode([Meal].self, from: data)
    }
}
