import XCTest
@testable import AiQo

final class IngredientAssetCatalogTests: XCTestCase {
    func testAllMappedIngredientAssetsExistInFoodPhotosCatalog() {
        let assetNames = IngredientAssetCatalog.mappedAssetNames

        XCTAssertEqual(assetNames.count, Set(assetNames).count, "Ingredient asset mapping should stay unique.")
        XCTAssertFalse(assetNames.contains("ing_walnuts2"), "Walnuts should resolve through the canonical ing_walnuts asset.")

        let missingImagesets = assetNames.filter { assetName in
            !FileManager.default.fileExists(
                atPath: foodPhotosCatalogURL
                    .appendingPathComponent("\(assetName).imageset", isDirectory: true)
                    .path
            )
        }

        XCTAssertTrue(
            missingImagesets.isEmpty,
            "Missing Food_photos imagesets for mapped ingredients: \(missingImagesets.joined(separator: ", "))"
        )
    }

    func testNewIngredientAliasesResolveToCanonicalKeys() {
        let expectations: [(String, IngredientKey)] = [
            ("almonds", .ing_almonds),
            ("black beans", .ing_black_beans),
            ("cauliflower", .ing_cauliflower),
            ("low fat cheese", .ing_cheese_low_fat),
            ("chia seeds", .ing_chia_seeds),
            ("chickpeas", .ing_chickpeas),
            ("corn", .ing_corn),
            ("cottage cheese", .ing_cottage_cheese),
            ("eggplant", .ing_eggplant),
            ("flax seeds", .ing_flax_seeds),
            ("garlic", .ing_garlic),
            ("ginger", .ing_ginger),
            ("greek yogurt", .ing_greek_yogurt),
            ("honey", .ing_honey),
            ("kidney beans", .ing_kidney_beans),
            ("lean lamb", .ing_lamb_lean),
            ("lemon", .ing_lemon),
            ("lentils", .ing_lentils),
            ("mango", .ing_mango),
            ("peanut butter", .ing_peanut_butter),
            ("peas", .ing_peas),
            ("pineapple", .ing_pineapple),
            ("soy sauce", .ing_soy_sauce),
            ("tahini", .ing_tahini),
            ("turkey breast", .ing_turkey_breast),
            ("walnuts", .ing_walnuts),
            ("watermelon", .ing_watermelon),
            ("whey protein", .ing_whey_scoop),
            ("zucchini", .ing_zucchini)
        ]

        for (input, expectedKey) in expectations {
            XCTAssertEqual(IngredientCatalog.match(from: input), expectedKey, "Expected \(input) to resolve to \(expectedKey.rawValue).")
        }

        XCTAssertNil(IngredientCatalog.match(from: "salt"))
        XCTAssertNil(IngredientCatalog.match(from: "pepper"))
    }

    private var foodPhotosCatalogURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("AiQo/Resources/Assets.xcassets/Food_photos", isDirectory: true)
    }
}
