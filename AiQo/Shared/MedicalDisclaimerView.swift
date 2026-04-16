import SwiftUI

/// Reusable medical disclaimer banner for health-related screens.
/// Apple Guideline 1.4.1: health/medical recommendations must include
/// citations and disclaimers.
struct MedicalDisclaimerView: View {
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "cross.case.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.orange.opacity(0.8))

            Text(NSLocalizedString(
                "health.disclaimer.general",
                value: "AiQo يقدم إرشادات عامة للعافية وليس تشخيصاً أو علاجاً طبياً. استشر أخصائي رعاية صحية مؤهل قبل اتخاذ قرارات طبية.",
                comment: "General medical disclaimer"
            ))
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(.secondary)
            .lineSpacing(2)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.orange.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.orange.opacity(0.15), lineWidth: 1)
                )
        )
    }
}

/// Inline health source attribution label.
struct HealthSourceLabel: View {
    let source: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "text.book.closed.fill")
                .font(.system(size: 9, weight: .semibold))
            Text(source)
                .font(.system(size: 10, weight: .medium, design: .rounded))
        }
        .foregroundStyle(.secondary.opacity(0.7))
    }
}
