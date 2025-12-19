import ManagedSettings
import ManagedSettingsUI
import UIKit

final class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundColor: .black,
            title: .init(text: "⛔️ محظور", color: .white),
            subtitle: .init(text: "دقيقة الاستخدام خلصت. ارجع ركّز.", color: .lightGray),
            primaryButtonLabel: .init(text: "تمام", color: .black),
            primaryButtonBackgroundColor: .systemYellow,
            secondaryButtonLabel: nil
        )
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundColor: .black,
            title: .init(text: "⛔️ موقع محظور", color: .white),
            subtitle: .init(text: "ارجع لمسارك.", color: .lightGray),
            primaryButtonLabel: .init(text: "تمام", color: .black),
            primaryButtonBackgroundColor: .systemYellow,
            secondaryButtonLabel: nil
        )
    }
}
