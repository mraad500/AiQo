import SwiftUI

// MARK: - Legendary Challenges Section (embedded in قِمَم tab)

struct LegendaryChallengesSection: View {
    @ObservedObject var viewModel: LegendaryChallengesViewModel

    var body: some View {
        VStack(alignment: .trailing, spacing: 14) {
            // DESIGN: Section header — bold Arabic + sparkle icon, matching existing قِمَم headers
            HStack(spacing: 6) {
                Text("✦")
                    .font(.system(size: 14))
                    .foregroundStyle(GymTheme.beige)

                Text("التحدّيات الأسطورية")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.primary)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.horizontal, 4)

            // DESIGN: Horizontal ScrollView of record cards
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(viewModel.records.enumerated()), id: \.element.id) { index, record in
                        NavigationLink(value: record) {
                            RecordCard(record: record, index: index)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
}

#Preview {
    NavigationStack {
        LegendaryChallengesSection(viewModel: LegendaryChallengesViewModel())
            .padding()
    }
    .environment(\.layoutDirection, .rightToLeft)
}
