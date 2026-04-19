import SwiftUI
import UIKit

/// Internal course options sheet presented before any external link is opened.
///
/// The user sees both course paths (Arabic + English) inside AiQo first, picks one,
/// and only then — via a low-emphasis secondary action — can open the external source.
struct LearningCourseOptionsSheet: View {
    let quest: QuestDefinition
    let config: LearningChallengeConfig

    @ObservedObject var proofStore: LearningProofStore

    @Environment(\.dismiss) private var dismiss

    @State private var inAppSourceURL: IdentifiedURL?

    private var layoutDirection: LayoutDirection {
        AppSettingsStore.shared.appLanguage == .arabic ? .rightToLeft : .leftToRight
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    header

                    ForEach(config.options) { option in
                        optionCard(option)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .background(Color(uiColor: .systemGroupedBackground).opacity(0.35))
            .navigationTitle(questLocalizedText("gym.quest.learning.options.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(questLocalizedText("gym.quest.cancel")) { dismiss() }
                }
            }
            .environment(\.layoutDirection, layoutDirection)
        }
        .sheet(item: $inAppSourceURL) { wrapper in
            CourseSourceOpener(url: wrapper.url)
                .ignoresSafeArea()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: questIsArabicLanguage() ? .trailing : .leading, spacing: 6) {
            Text(questLocalizedText("gym.quest.learning.options.intro"))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(hex: "444444"))
                .multilineTextAlignment(questIsArabicLanguage() ? .trailing : .leading)
                .frame(maxWidth: .infinity, alignment: questIsArabicLanguage() ? .trailing : .leading)
        }
        .padding(.bottom, 2)
    }

    // MARK: - Option Card

    @ViewBuilder
    private func optionCard(_ option: LearningCourseOption) -> some View {
        let selectedId = proofStore.record(for: quest.id).selectedCourseOptionId
        let isSelected = selectedId == option.id
        let alignment: HorizontalAlignment = option.language == .arabic ? .trailing : .leading
        let textAlignment: TextAlignment = option.language == .arabic ? .trailing : .leading

        VStack(alignment: alignment, spacing: 10) {
            // Selected pill (only shows on currently-selected option).
            if isSelected {
                HStack {
                    if option.language == .english { Spacer() }
                    Text(questLocalizedText("gym.quest.learning.options.selected"))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color(hex: "B7E5D2")))
                        .foregroundStyle(Color(hex: "1A1A1A"))
                    if option.language == .arabic { Spacer() }
                }
            }

            Text(option.title)
                .font(.system(size: 19, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(hex: "1A1A1A"))
                .multilineTextAlignment(textAlignment)
                .frame(maxWidth: .infinity, alignment: option.language == .arabic ? .trailing : .leading)
                .environment(\.layoutDirection, option.language == .arabic ? .rightToLeft : .leftToRight)

            // Metadata rows — "Platform: X", "Language: Y", and free badge.
            VStack(alignment: alignment, spacing: 4) {
                metadataRow(
                    label: questLocalizedText("gym.quest.learning.options.platform"),
                    value: questLocalizedText(option.providerDisplayKey),
                    align: option.language == .arabic ? .trailing : .leading
                )
                metadataRow(
                    label: questLocalizedText("gym.quest.learning.options.language"),
                    value: questLocalizedText(option.language.displayKey),
                    align: option.language == .arabic ? .trailing : .leading
                )
            }

            Text(option.descriptionText)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color(hex: "444444"))
                .multilineTextAlignment(textAlignment)
                .frame(maxWidth: .infinity, alignment: option.language == .arabic ? .trailing : .leading)
                .environment(\.layoutDirection, option.language == .arabic ? .rightToLeft : .leftToRight)

            // Free badge.
            HStack {
                if option.language == .english { Spacer() }
                Text(questLocalizedText("gym.quest.learning.options.free"))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color(hex: "F5E4B4")))
                    .foregroundStyle(Color(hex: "6B5B2E"))
                if option.language == .arabic { Spacer() }
            }

            // Secondary, lower-emphasis external-source action.
            Button(action: { openSource(for: option) }) {
                HStack(spacing: 6) {
                    if option.language == .english { Spacer() }
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 13, weight: .semibold))
                    Text(questLocalizedText("gym.quest.learning.options.openSource"))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                    if option.language == .arabic { Spacer() }
                }
                .foregroundStyle(Color(hex: "1A1A1A").opacity(0.78))
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color(hex: "1A1A1A").opacity(0.14), lineWidth: 0.8)
                )
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    isSelected ? Color(hex: "B7E5D2") : Color.black.opacity(0.08),
                    lineWidth: isSelected ? 1.5 : 0.6
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            selectOption(option)
        }
    }

    @ViewBuilder
    private func metadataRow(label: String, value: String, align: HorizontalAlignment) -> some View {
        HStack(spacing: 6) {
            if align == .trailing { Spacer() }
            Text("\(label): ")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(hex: "666666"))
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(hex: "1A1A1A"))
            if align == .leading { Spacer() }
        }
    }

    // MARK: - Actions

    private func selectOption(_ option: LearningCourseOption) {
        proofStore.selectCourseOption(questId: quest.id, optionId: option.id)
    }

    private func openSource(for option: LearningCourseOption) {
        selectOption(option)
        if FeatureFlags.safariViewControllerEnabled {
            inAppSourceURL = IdentifiedURL(url: option.courseURL)
        } else {
            UIApplication.shared.open(option.courseURL)
        }
    }
}

/// Identifiable wrapper so `.sheet(item:)` can drive the SFSafariViewController.
struct IdentifiedURL: Identifiable {
    let id = UUID()
    let url: URL
}
