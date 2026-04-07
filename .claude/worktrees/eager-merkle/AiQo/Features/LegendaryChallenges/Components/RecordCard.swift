import SwiftUI

// MARK: - Record Card (Single card in horizontal scroll)

struct RecordCard: View {
    let record: LegendaryRecord
    let index: Int

    // DESIGN: Alternating Mint/Sand to match existing قِمَم card pattern
    private var cardBackground: Color {
        index.isMultiple(of: 2) ? GymTheme.mint : GymTheme.beige
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            // DESIGN: Top row — category pill + SF Symbol icon
            HStack {
                // SF Symbol icon in a circle
                Image(systemName: record.iconName)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.5))

                Spacer()

                // Category pill — Sand background
                Text(record.category.rawValue)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(GymTheme.beige.opacity(0.6))
                    )
            }

            Spacer()

            // DESIGN: Record number — large and bold
            Text("\(record.formattedTarget) \(record.unit)")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            // Record title
            Text(record.titleAr)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Color.primary.opacity(0.8))
                .lineLimit(1)

            // Record holder
            Text("صاحب الرقم: \(record.recordHolderAr) \(record.country)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.primary.opacity(0.45))
                .lineLimit(1)

            // DESIGN: Difficulty dots — filled circles
            HStack(spacing: 4) {
                ForEach(1...3, id: \.self) { level in
                    Circle()
                        .fill(level <= record.difficulty.rawValue
                              ? Color.primary.opacity(0.6)
                              : Color.primary.opacity(0.12))
                        .frame(width: 6, height: 6)
                }
            }
        }
        .padding(16)
        // DESIGN: 280×180 card, rounded 20pt corners, alternating background
        .frame(width: 280, height: 180)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                // CHANGED: Increased opacity from 0.3 to 0.55 for more vibrant, visible colors
                .fill(cardBackground.opacity(0.55))
        )
        .environment(\.layoutDirection, .rightToLeft)
    }
}

#Preview {
    HStack(spacing: 12) {
        RecordCard(record: LegendaryRecord.seedRecords[0], index: 0)
        RecordCard(record: LegendaryRecord.seedRecords[1], index: 1)
    }
    .padding()
    .environment(\.layoutDirection, .rightToLeft)
}
