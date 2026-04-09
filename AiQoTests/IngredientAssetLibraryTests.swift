import XCTest
@testable import AiQo

final class IngredientAssetLibraryTests: XCTestCase {
    func testAllMappedIngredientAssetsExistInFoodPhotosCatalog() {
        let missing = IngredientAssetLibrary.missingAssetNames()

        XCTAssertTrue(
            missing.isEmpty,
            "Missing Food_photos imagesets for ingredient mappings: \(missing.joined(separator: ", "))"
        )
    }
}
