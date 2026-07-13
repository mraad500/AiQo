import ManagedSettings

/// Phase-1 Shield Action handler for the Kernel.
///
/// Mirrors the system default behavior (close on the primary button, defer on
/// the secondary) and adds no Kernel-specific behavior — this target exists only
/// to complete the Family Controls extension wiring. Because nothing is shielded
/// in Phase 1, these handlers are never actually invoked yet.
///
/// The class name must match `NSExtensionPrincipalClass` in Info.plist
/// (`KernelShieldAction.ShieldActionExtension`).
final class ShieldActionExtension: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .primaryButtonPressed:
            completionHandler(.close)
        case .secondaryButtonPressed:
            completionHandler(.defer)
        case .firstSecondarySubmenuItemPressed,
             .secondSecondarySubmenuItemPressed,
             .thirdSecondarySubmenuItemPressed:
            // iOS 26.4+ secondary-button submenu items — we use no submenu, so
            // treat like the secondary button. (Explicit to satisfy exhaustiveness.)
            completionHandler(.defer)
        @unknown default:
            completionHandler(.close)
        }
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(.close)
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(.close)
    }
}
