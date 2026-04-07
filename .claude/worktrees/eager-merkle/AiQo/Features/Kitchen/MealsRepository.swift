// Features/Kitchen/MealsRepository.swift

import Foundation

protocol MealsRepository {
    func fetchAllMeals() async throws -> [Meal]
}
