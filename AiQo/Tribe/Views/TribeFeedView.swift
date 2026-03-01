import SwiftUI
import UIKit

struct TribeFeedView: View {
    let events: [TribeEvent]

    private let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = Locale(identifier: "ar")
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if events.isEmpty {
                TribeGlassPanel(style: .glass, tint: UIColor.systemGray) {
                    Text("لا توجد أحداث بعد.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(events.sorted(by: { $0.createdAt > $1.createdAt })) { event in
                    TribeGlassPanel(style: .glass, tint: tint(for: event.type)) {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: icon(for: event.type))
                                .font(.system(size: 15, weight: .semibold))
                                .frame(width: 32, height: 32)
                                .background(Color.white.opacity(0.24))
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 6) {
                                Text(event.message)
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .fixedSize(horizontal: false, vertical: true)

                                Text(relativeFormatter.localizedString(for: event.createdAt, relativeTo: Date()))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 0)
                        }
                    }
                }
            }
        }
    }

    private func icon(for type: TribeEventType) -> String {
        switch type {
        case .contribution:
            return "bolt.fill"
        case .spark, .sparkSent:
            return "sparkles"
        case .join, .memberJoined:
            return "person.badge.plus"
        case .shieldUnlocked:
            return "shield.lefthalf.filled"
        case .missionCompleted, .challengeCompleted:
            return "checkmark.seal.fill"
        case .leadChanged:
            return "crown.fill"
        case .challengeSuggested:
            return "lightbulb.max.fill"
        }
    }

    private func tint(for type: TribeEventType) -> UIColor {
        switch type {
        case .contribution:
            return .systemBlue
        case .spark, .sparkSent:
            return .systemOrange
        case .join, .memberJoined:
            return .systemTeal
        case .shieldUnlocked:
            return .systemGreen
        case .missionCompleted, .challengeCompleted:
            return .systemPurple
        case .leadChanged:
            return .systemYellow
        case .challengeSuggested:
            return .systemIndigo
        }
    }
}
