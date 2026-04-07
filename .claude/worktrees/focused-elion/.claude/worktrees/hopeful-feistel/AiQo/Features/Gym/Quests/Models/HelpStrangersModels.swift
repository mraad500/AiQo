import Foundation

enum HelpType: String, CaseIterable, Identifiable {
    case time
    case kindWord
    case service
    case donation

    var id: Self { self }

    var title: String {
        switch self {
        case .time:
            return L10n.t("quests.help_sheet.type.time")
        case .kindWord:
            return L10n.t("quests.help_sheet.type.kind_word")
        case .service:
            return L10n.t("quests.help_sheet.type.service")
        case .donation:
            return L10n.t("quests.help_sheet.type.donation")
        }
    }
}

enum HelpImpact: String, CaseIterable, Identifiable {
    case smile
    case relief
    case solvedProblem
    case guidance

    var id: Self { self }

    var title: String {
        switch self {
        case .smile:
            return L10n.t("quests.help_sheet.impact.smile")
        case .relief:
            return L10n.t("quests.help_sheet.impact.relief")
        case .solvedProblem:
            return L10n.t("quests.help_sheet.impact.solved_problem")
        case .guidance:
            return L10n.t("quests.help_sheet.impact.guidance")
        }
    }
}

struct HelpEntry: Identifiable, Equatable {
    let id: Int
    var text: String
    var type: HelpType
    var impact: HelpImpact

    init(
        id: Int,
        text: String = "",
        type: HelpType = .time,
        impact: HelpImpact = .smile
    ) {
        self.id = id
        self.text = text
        self.type = type
        self.impact = impact
    }

    var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isValid: Bool {
        !trimmedText.isEmpty
    }
}
