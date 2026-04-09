import SwiftUI

struct AlarmSetupCardView: View {
    let recommendation: SmartWakeRecommendation
    let saveState: AlarmSaveState
    let onSave: () -> Void
    let onOpenSettings: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("alarm.setWake", comment: ""))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(AiQoTheme.Colors.textPrimary)

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(iconBackground)
                            .frame(width: 46, height: 46)

                        Image(systemName: saveState.isSaved ? "alarm.fill" : "alarm")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(iconForeground)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("alarm.scheduledTime", comment: ""))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(helperForeground)

                        Text(CaptainPersonalizationTimeFormatter.localizedString(recommendation.wakeDate))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(primaryForeground)
                            .contentTransition(.numericText())
                            .minimumScaleFactor(0.72)
                    }

                    Spacer(minLength: 0)

                    if let badgeTitle {
                        Text(badgeTitle)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(badgeForeground)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(badgeBackground, in: Capsule())
                    }
                }

                Text(helperText)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(helperForeground)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: primaryAction) {
                    HStack(spacing: 8) {
                        if saveState.isBusy {
                            ProgressView()
                                .tint(buttonForeground)
                        } else {
                            Image(systemName: buttonIconName)
                                .font(.system(size: 13, weight: .bold))
                        }

                        Text(buttonTitle)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(buttonForeground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(buttonBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(saveState.isBusy || saveState.isSaved)
                .accessibilityLabel(buttonAccessibilityLabel)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: recommendation.id)
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: saveState)
    }

    private var helperText: String {
        switch saveState {
        case .idle:
            return NSLocalizedString("alarm.helper.ready", comment: "")
        case .requestingPermission:
            return NSLocalizedString("alarm.helper.requesting", comment: "")
        case .saving:
            return NSLocalizedString("alarm.helper.saving", comment: "")
        case .saved:
            return NSLocalizedString("alarm.helper.saved", comment: "")
        case .denied(let message):
            return message
        case .failed(let message):
            return message
        }
    }

    private var buttonTitle: String {
        switch saveState {
        case .idle:
            return NSLocalizedString("alarm.button.save", comment: "")
        case .requestingPermission:
            return NSLocalizedString("alarm.button.requesting", comment: "")
        case .saving:
            return NSLocalizedString("alarm.button.saving", comment: "")
        case .saved:
            return NSLocalizedString("alarm.button.saved", comment: "")
        case .denied:
            return NSLocalizedString("alarm.button.settings", comment: "")
        case .failed:
            return NSLocalizedString("alarm.button.retry", comment: "")
        }
    }

    private var buttonIconName: String {
        switch saveState {
        case .denied:
            return "gearshape.fill"
        case .saved:
            return "checkmark.circle.fill"
        default:
            return "bell.badge.fill"
        }
    }

    private var buttonAccessibilityLabel: String {
        buttonTitle
    }

    private var badgeTitle: String? {
        switch saveState {
        case .saved:
            return NSLocalizedString("alarm.badge.set", comment: "")
        case .requestingPermission:
            return NSLocalizedString("alarm.badge.request", comment: "")
        case .saving:
            return NSLocalizedString("alarm.badge.saving", comment: "")
        case .denied:
            return NSLocalizedString("alarm.badge.required", comment: "")
        case .failed:
            return NSLocalizedString("alarm.badge.failed", comment: "")
        case .idle:
            return nil
        }
    }

    private var primaryAction: () -> Void {
        switch saveState {
        case .denied:
            return {
                if let onOpenSettings {
                    onOpenSettings()
                } else {
                    onSave()
                }
            }
        default:
            return onSave
        }
    }

    private var primaryForeground: Color {
        saveState.isSaved ? Color(hex: "15372D") : AiQoTheme.Colors.textPrimary
    }

    private var helperForeground: Color {
        if saveState.isSaved {
            return Color(hex: "2C5A4B")
        }

        if saveState.isDenied {
            return Color(hex: "7A5A22")
        }

        if saveState.isFailed {
            return Color(hex: "8C5530")
        }

        return AiQoTheme.Colors.textSecondary
    }

    private var iconForeground: Color {
        if saveState.isSaved {
            return Color(hex: "2F8C70")
        }

        if saveState.isDenied {
            return Color(hex: "B47A1E")
        }

        if saveState.isFailed {
            return Color(hex: "C27A43")
        }

        return Color(hex: "6D7CFF")
    }

    private var iconBackground: Color {
        if saveState.isSaved {
            return Color(hex: "E7FFF4")
        }

        if saveState.isDenied {
            return Color(hex: "FFF5DE")
        }

        if saveState.isFailed {
            return Color(hex: "FFF1E2")
        }

        return Color(hex: "EEF3FF")
    }

    private var badgeForeground: Color {
        if saveState.isSaved {
            return Color(hex: "235945")
        }

        if saveState.isDenied {
            return Color(hex: "74561A")
        }

        if saveState.isFailed {
            return Color(hex: "8A5629")
        }

        return Color(hex: "315062")
    }

    private var badgeBackground: Color {
        if saveState.isSaved {
            return Color.white.opacity(0.62)
        }

        if saveState.isDenied {
            return Color(hex: "FFF0CC").opacity(0.96)
        }

        if saveState.isFailed {
            return Color(hex: "FFF0E2").opacity(0.92)
        }

        return Color.white.opacity(0.54)
    }

    private var buttonForeground: Color {
        if saveState.isSaved {
            return Color(hex: "245341")
        }

        if saveState.isDenied {
            return Color(hex: "6A4C12")
        }

        return Color(hex: "123042")
    }

    private var buttonBackground: LinearGradient {
        if saveState.isSaved {
            return LinearGradient(
                colors: [
                    Color(hex: "DFF7EF"),
                    Color(hex: "CFF4E5")
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }

        if saveState.isDenied {
            return LinearGradient(
                colors: [
                    Color(hex: "FFF0C8"),
                    Color(hex: "FFF7E5")
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }

        if saveState.isFailed {
            return LinearGradient(
                colors: [
                    Color(hex: "FFEAD9"),
                    Color(hex: "FFF2E7")
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }

        return LinearGradient(
            colors: [
                Color(hex: "D9F8EC"),
                Color(hex: "E4F0FF")
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(backgroundFill)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(borderGradient, lineWidth: saveState.isSaved ? 1.4 : 1)
            )
            .shadow(
                color: shadowColor,
                radius: saveState.isSaved ? 18 : 12,
                x: 0,
                y: 8
            )
    }

    private var backgroundFill: LinearGradient {
        if saveState.isSaved {
            return LinearGradient(
                colors: [
                    Color(hex: "E8FFF5"),
                    Color(hex: "DDF8EC"),
                    Color(hex: "F3FFFA")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        if saveState.isDenied {
            return LinearGradient(
                colors: [
                    Color(hex: "FFF8E8"),
                    Color(hex: "FFF4DB"),
                    Color(hex: "FFFCF4")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        if saveState.isFailed {
            return LinearGradient(
                colors: [
                    Color(hex: "FFF5EB"),
                    Color(hex: "FFF9F3")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        return LinearGradient(
            colors: [
                Color.white.opacity(colorScheme == .dark ? 0.08 : 0.24),
                Color(hex: "EEF3FF").opacity(colorScheme == .dark ? 0.10 : 0.34)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var borderGradient: LinearGradient {
        if saveState.isSaved {
            return LinearGradient(
                colors: [
                    Color.white.opacity(0.80),
                    Color(hex: "A7E8CC").opacity(0.96)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        if saveState.isDenied {
            return LinearGradient(
                colors: [
                    Color.white.opacity(0.78),
                    Color(hex: "F4D28F").opacity(0.94)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        if saveState.isFailed {
            return LinearGradient(
                colors: [
                    Color.white.opacity(0.74),
                    Color(hex: "FFD8B5").opacity(0.92)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        return LinearGradient(
            colors: [
                Color.white.opacity(colorScheme == .dark ? 0.14 : 0.46),
                Color(hex: "BFD4FF").opacity(colorScheme == .dark ? 0.16 : 0.36)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var shadowColor: Color {
        if saveState.isSaved {
            return Color(hex: "9FDCC2").opacity(0.26)
        }

        if saveState.isDenied {
            return Color(hex: "F2D084").opacity(0.22)
        }

        if saveState.isFailed {
            return Color(hex: "FFDFC3").opacity(0.24)
        }

        return Color.black.opacity(colorScheme == .dark ? 0.10 : 0.05)
    }
}

#Preview("Alarm Setup - Default") {
    AlarmSetupCardView(
        recommendation: .previewBest,
        saveState: .idle,
        onSave: {},
        onOpenSettings: nil
    )
    .padding()
    .background(
        LinearGradient(
            colors: [
                Color(hex: "EEF3FA"),
                Color(hex: "DCE6F3")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
}

#Preview("Alarm Setup - Saving") {
    AlarmSetupCardView(
        recommendation: .previewBest,
        saveState: .saving,
        onSave: {},
        onOpenSettings: nil
    )
    .padding()
    .background(
        LinearGradient(
            colors: [
                Color(hex: "EEF3FA"),
                Color(hex: "DCE6F3")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
}

#Preview("Alarm Setup - Saved") {
    AlarmSetupCardView(
        recommendation: .previewBest,
        saveState: .saved,
        onSave: {},
        onOpenSettings: nil
    )
    .padding()
    .background(
        LinearGradient(
            colors: [
                Color(hex: "EEF3FA"),
                Color(hex: "DCE6F3")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
}

#Preview("Alarm Setup - Denied") {
    AlarmSetupCardView(
        recommendation: .previewBest,
        saveState: .denied(message: "تحتاج تسمح للتطبيق بإنشاء منبه. فعّل إذن المنبه حتى ينحفظ الوقت."),
        onSave: {},
        onOpenSettings: {}
    )
    .padding()
    .background(
        LinearGradient(
            colors: [
                Color(hex: "EEF3FA"),
                Color(hex: "DCE6F3")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
}

#Preview("Alarm Setup - Failed") {
    AlarmSetupCardView(
        recommendation: .previewAlternate,
        saveState: .failed(message: "صار خطأ أثناء حفظ المنبه. حاول مرة ثانية."),
        onSave: {},
        onOpenSettings: nil
    )
    .padding()
    .background(
        LinearGradient(
            colors: [
                Color(hex: "EEF3FA"),
                Color(hex: "DCE6F3")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
}

private extension SmartWakeRecommendation {
    static let previewBest = SmartWakeRecommendation(
        id: "preview-best",
        wakeDate: Calendar.current.date(bySettingHour: 6, minute: 20, second: 0, of: Date()) ?? Date(),
        cycleCount: 5,
        estimatedSleepDuration: 5 * 90 * 60,
        confidenceScore: 0.87,
        badge: "الأفضل",
        isBest: true,
        explanation: "ضمن نافذة الاستيقاظ الذكي واعتمادًا على دورات النوم التقديرية.",
        isWithinSmartWindow: true
    )

    static let previewAlternate = SmartWakeRecommendation(
        id: "preview-alt",
        wakeDate: Calendar.current.date(bySettingHour: 4, minute: 50, second: 0, of: Date()) ?? Date(),
        cycleCount: 4,
        estimatedSleepDuration: 4 * 90 * 60,
        confidenceScore: 0.72,
        badge: "متوازن",
        isBest: false,
        explanation: "خيار مقبول إذا كنت تحتاج الاستيقاظ أبكر من المعتاد.",
        isWithinSmartWindow: false
    )
}
