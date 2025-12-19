import UIKit

final class ImageLoader {
    static let shared = ImageLoader()

    private let cache = NSCache<NSURL, UIImage>()

    private init() {}

    func setImage(on imageView: UIImageView, from url: URL?) {
        imageView.image = nil

        guard let url else { return }

        // إذا الصورة موجودة بالكاش
        if let cached = cache.object(forKey: url as NSURL) {
            imageView.image = cached
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self, weak imageView] data, _, _ in
            guard
                let self,
                let data,
                let image = UIImage(data: data)
            else { return }

            self.cache.setObject(image, forKey: url as NSURL)

            DispatchQueue.main.async {
                imageView?.image = image
            }
        }.resume()
    }
}
