import SwiftUI
import UIKit

enum IngredientAssetCatalog {
    static func uiImage(for ingredientKey: IngredientKey) -> UIImage? {
        uiImage(named: ingredientKey.assetName)
    }

    static func uiImage(named assetName: String) -> UIImage? {
        candidateBundles.lazy.compactMap { bundle in
            UIImage(named: assetName, in: bundle, compatibleWith: nil)
        }.first
    }

    static var mappedAssetNames: [String] {
        IngredientKey.allCases.map(\.assetName)
    }

    private static let candidateBundles: [Bundle] = {
        var seenBundlePaths: Set<String> = []
        let bundles = [Bundle.main, Bundle(for: BundleMarker.self)]

        return bundles.filter { bundle in
            seenBundlePaths.insert(bundle.bundlePath).inserted
        }
    }()
}

private final class BundleMarker: NSObject {}

struct IngredientIconView: View {
    let emoji: String
    var size: CGFloat = 28
    var cornerRadius: CGFloat = 10
    var backgroundColor: Color = Color(.secondarySystemBackground)

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(backgroundColor)

            Text(emoji)
                .font(.system(size: size * 0.62))
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
