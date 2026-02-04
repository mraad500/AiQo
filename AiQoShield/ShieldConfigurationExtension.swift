import ManagedSettings
import ManagedSettingsUI
import UIKit

final class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    // MARK: - Application Shield
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        return digitalEnergyShieldConfig()
    }

    // MARK: - Web Shield
    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        return digitalEnergyShieldConfig()
    }

    // MARK: - Helper Function (الحل الذكي)
    private func digitalEnergyShieldConfig() -> ShieldConfiguration {
        
        return ShieldConfiguration(
            // ✅ تصحيح 1: المتغير الصحيح هو backgroundBlurStyle
            backgroundBlurStyle: .systemThickMaterialDark,
            
            // ✅ تصحيح 2: بـ UIKit نستخدم withAlphaComponent للشفافية
            backgroundColor: UIColor.black.withAlphaComponent(0.9),
            
            // 💡 الحل الذكي: نلغي الأيقونة ونعتمد على الإيموجي بالعنوان
            icon: nil,
            
            title: ShieldConfiguration.Label(
                text: "🔋\nLow Energy", // الإيموجي هنا راح يصير كأنه أيقونة
                color: .systemYellow
            ),
            
            subtitle: ShieldConfiguration.Label(
                text: "Your bio-digital kernel needs recharge.\nWalk 60 steps to unlock.",
                color: .white
            ),
            
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "I'm on it",
                color: .black
            ),
            
            primaryButtonBackgroundColor: .systemCyan,
            secondaryButtonLabel: nil
        )
    }
}
