import UIKit

/// Centralized haptic feedback — respects Reduce Motion.
enum HapticEngine {
    static func light() {
        guard shouldFireHaptics else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    static func medium() {
        guard shouldFireHaptics else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    static func heavy() {
        guard shouldFireHaptics else { return }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }
    static func success() {
        guard shouldFireHaptics else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    static func error() {
        guard shouldFireHaptics else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
    static func selection() {
        guard shouldFireHaptics else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private static var shouldFireHaptics: Bool {
        !UIAccessibility.isReduceMotionEnabled
    }
}
