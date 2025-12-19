import Foundation
import UIKit

public struct MealItem: Codable {
    public let title: String
    public let calories: Int

    public init(title: String, calories: Int) {
        self.title = title
        self.calories = calories
    }
}

public struct MealCardData: Codable {
    public let sectionTitle: String
    public let items: [MealItem]
    public let totalCaloriesText: String
    public let imageName: String

    public init(sectionTitle: String,
                items: [MealItem],
                totalCaloriesText: String,
                imageName: String) {
        self.sectionTitle = sectionTitle
        self.items = items
        self.totalCaloriesText = totalCaloriesText
        self.imageName = imageName
    }
}
