import SwiftUI

struct CountdownTimerView: View {
    let endDate: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            let remaining = max(0, endDate.timeIntervalSince(context.date))
            let days = Int(remaining) / 86400
            let hours = (Int(remaining) % 86400) / 3600
            let minutes = (Int(remaining) % 3600) / 60

            if remaining <= 0 {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 14))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(TribePalette.textTertiary)
                    Text("انتهى التحدي")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(TribePalette.textTertiary)
                }
            } else {
                VStack(spacing: 8) {
                    Text("ينتهي بعد")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(TribePalette.textTertiary)

                    HStack(spacing: 8) {
                        TimeUnitCapsule(value: days, label: "يوم")
                        Text(":")
                            .font(.system(.title3, design: .rounded))
                            .foregroundStyle(TribePalette.textTertiary)
                        TimeUnitCapsule(value: hours, label: "ساعة")
                        Text(":")
                            .font(.system(.title3, design: .rounded))
                            .foregroundStyle(TribePalette.textTertiary)
                        TimeUnitCapsule(value: minutes, label: "دقيقة")
                    }
                }
            }
        }
    }
}

private struct TimeUnitCapsule: View {
    let value: Int
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(TribePalette.textPrimary)
            Text(label)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(TribePalette.textTertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.aiqoMint.opacity(0.12))
        )
    }
}
