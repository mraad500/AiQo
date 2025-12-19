import UIKit

extension UIFont {
    /// خط AiQo مدوّر، سمين، يناسب عناوين الـ Home والكروت
    static func aiqoRounded(size: CGFloat, weight: UIFont.Weight = .bold) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        if let descriptor = base.fontDescriptor.withDesign(.rounded) {
            return UIFont(descriptor: descriptor, size: size)
        } else {
            return base
        }
    }
}
