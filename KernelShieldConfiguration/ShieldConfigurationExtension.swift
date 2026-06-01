import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Branded Kernel shield (Phase 4). Stays inside Apple's strict shield limits:
/// background color + icon + title + subtitle + two buttons. Replaces the default
/// English "Restricted" appearance with the AiQo brand, localized (ar/en) via the
/// language code mirrored into the App Group (the extension can't read the app's
/// UserDefaults or import the app's `AiQoColors`, so brand colors are UIColor
/// literals mirroring the design tokens).
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    // Brand palette (mirrors AiQoColors / AiQoTheme — unreachable from this bundle).
    private let brandMint = UIColor(red: 0.369, green: 0.804, blue: 0.718, alpha: 1)   // #5ECDB7
    private let brandMintSoft = UIColor(red: 0.718, green: 0.898, blue: 0.824, alpha: 1) // #B7E5D2
    private let brandDark = UIColor(red: 0.082, green: 0.125, blue: 0.114, alpha: 1)     // soft dark teal

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        // Re-shield layer (c): if an earned window just expired, keep state consistent.
        KernelShieldController.shared.reshieldIfNeeded()
        return brandedConfiguration(appName: application.localizedDisplayName)
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        KernelShieldController.shared.reshieldIfNeeded()
        return brandedConfiguration(appName: application.localizedDisplayName)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        KernelShieldController.shared.reshieldIfNeeded()
        return brandedConfiguration(appName: webDomain.domain)
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        KernelShieldController.shared.reshieldIfNeeded()
        return brandedConfiguration(appName: webDomain.domain)
    }

    // MARK: - Branded configuration

    private func brandedConfiguration(appName: String?) -> ShieldConfiguration {
        let state = KernelSharedStore.shared.load()
        let isArabic = state.languageCode != "en"
        let steps = state.activeChallenge?.stepTarget ?? 0
        let app = appName ?? (isArabic ? "هذا التطبيق" : "this app")

        let title = isArabic ? "نواتك تحتاج شحن" : "Your kernel needs a charge"
        let subtitle: String = {
            if steps > 0 {
                return isArabic ? "امشِ \(steps) خطوة لتفتح \(app)"
                                : "Walk \(steps) steps to open \(app)"
            }
            return isArabic ? "افتح AiQo لتشحن نواتك وتفتح \(app)"
                            : "Open AiQo to charge your kernel and unlock \(app)"
        }()
        let primary = isArabic ? "بديت" : "I started"
        let secondary = isArabic ? "افتح AiQo" : "Open AiQo"

        let icon = UIImage(systemName: "bolt.fill")?
            .withTintColor(brandMint, renderingMode: .alwaysOriginal)

        return ShieldConfiguration(
            backgroundBlurStyle: .systemThinMaterialDark,
            backgroundColor: brandDark,
            icon: icon,
            title: ShieldConfiguration.Label(text: title, color: .white),
            subtitle: ShieldConfiguration.Label(text: subtitle, color: brandMintSoft),
            primaryButtonLabel: ShieldConfiguration.Label(text: primary, color: brandDark),
            primaryButtonBackgroundColor: brandMint,
            secondaryButtonLabel: ShieldConfiguration.Label(text: secondary, color: brandMintSoft)
        )
    }
}
