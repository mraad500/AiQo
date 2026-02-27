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
    let ingredientKey: IngredientKey?
    var size: CGFloat = 28
    var cornerRadius: CGFloat = 10
    var fallbackSystemName: String = "fork.knife.circle.fill"
    var fallbackTint: Color = .yellow

    var body: some View {
        Group {
            if let ingredientKey, let image = IngredientAssetCatalog.uiImage(for: ingredientKey) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: fallbackSystemName)
                    .font(.system(size: size * 0.62, weight: .semibold, design: .rounded))
                    .foregroundStyle(fallbackTint)
                    .frame(width: size, height: size)
            }
        }
        .frame(width: size, height: size)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
