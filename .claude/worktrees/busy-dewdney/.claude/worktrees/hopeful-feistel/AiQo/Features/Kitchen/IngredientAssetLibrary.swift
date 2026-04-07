import SwiftUI
import UIKit

enum IngredientAssetLibrary {
    static func keyWithLocalAsset(for ingredientName: String, bundle: Bundle = .main) -> IngredientKey? {
        guard let key = IngredientCatalog.match(from: ingredientName) else { return nil }
        return uiImage(for: key, bundle: bundle) == nil ? nil : key
    }

    static func uiImage(for key: IngredientKey, bundle: Bundle = .main) -> UIImage? {
        UIImage(named: key.assetName, in: bundle, compatibleWith: nil)
    }

    static func image(for key: IngredientKey, bundle: Bundle = .main) -> Image? {
        guard uiImage(for: key, bundle: bundle) != nil else { return nil }
        return Image(key.assetName, bundle: bundle)
    }

    #if DEBUG
    static func missingAssetNames(
        inDirectory directoryURL: URL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/Assets.xcassets/Food_photos")
    ) -> [String] {
        let fileManager = FileManager.default

        return IngredientKey.allCases.compactMap { key in
            let imagesetURL = directoryURL.appendingPathComponent("\(key.assetName).imageset")
            return fileManager.fileExists(atPath: imagesetURL.path) ? nil : key.assetName
        }
    }
    #endif
}

struct IngredientLocalAssetView<Placeholder: View>: View {
    let ingredientName: String
    let size: CGFloat
    let cornerRadius: CGFloat
    let bundle: Bundle
    private let placeholder: Placeholder

    init(
        ingredientName: String,
        size: CGFloat,
        cornerRadius: CGFloat = 10,
        bundle: Bundle = .main,
        @ViewBuilder placeholder: () -> Placeholder
    ) {
        self.ingredientName = ingredientName
        self.size = size
        self.cornerRadius = cornerRadius
        self.bundle = bundle
        self.placeholder = placeholder()
    }

    var body: some View {
        Group {
            if let key = IngredientAssetLibrary.keyWithLocalAsset(for: ingredientName, bundle: bundle) {
                Image(key.assetName, bundle: bundle)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
