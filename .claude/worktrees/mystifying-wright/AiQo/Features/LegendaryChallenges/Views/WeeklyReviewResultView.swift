import SwiftUI

/// شاشة نتيجة المراجعة الأسبوعية
struct WeeklyReviewResultView: View {
    let result: ReviewResult
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            // أيقونة الحالة
            Image(systemName: result.isOnTrack ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundStyle(result.isOnTrack ? GymTheme.mint : .orange)

            Text(result.isOnTrack ? NSLocalizedString("reviewResult.onTrack", comment: "") : NSLocalizedString("reviewResult.needsAdjustment", comment: ""))
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.primary)

            // رسالة الكابتن
            VStack(alignment: .trailing, spacing: 8) {
                Text(NSLocalizedString("assessment.captainSays", comment: ""))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary.opacity(0.5))

                Text(result.captainMessage)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.8))
                    .multilineTextAlignment(.trailing)
                    .lineSpacing(4)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(hex: "F7F7F7"))
            )

            // التعديلات
            VStack(alignment: .trailing, spacing: 8) {
                Text(NSLocalizedString("reviewResult.adjustments", comment: ""))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary.opacity(0.5))

                Text(result.adjustments ?? NSLocalizedString("reviewResult.noAdjustments", comment: ""))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.7))
                    .multilineTextAlignment(.trailing)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(hex: "F7F7F7"))
            )

            // تحذير إذا في
            if let warning = result.warningIfAny {
                HStack(spacing: 8) {
                    Spacer()
                    Text(warning)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.orange)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.orange.opacity(0.1))
                )
            }

            Spacer()

            Button {
                onDismiss()
            } label: {
                HStack {
                    Spacer()
                    Text(NSLocalizedString("reviewResult.done", comment: ""))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.primary)
                    Spacer()
                }
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(GymTheme.mint.opacity(0.5))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .background(Color.white.ignoresSafeArea())
        .environment(\.layoutDirection, .rightToLeft)
    }
}
