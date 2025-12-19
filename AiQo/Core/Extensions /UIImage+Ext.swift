import UIKit

extension UIImageView {
    func setRemoteImage(_ url: URL?, placeholder: UIImage? = nil) {
        // أول شي حط الـ placeholder إن وجد
        if let placeholder {
            self.image = placeholder
        }

        // استعمل الدالة الحقيقية من ImageLoader
        ImageLoader.shared.setImage(on: self, from: url)
    }
}
