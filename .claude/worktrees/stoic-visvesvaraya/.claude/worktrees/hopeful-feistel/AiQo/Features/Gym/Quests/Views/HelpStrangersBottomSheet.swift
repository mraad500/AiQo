import SwiftUI
import UIKit

private enum HelpStrangersInputField: Hashable {
    case note(Int)
}

struct HelpStrangersBottomSheet: View {
    var onComplete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @AppStorage("aiqo.quests.help-strangers.share-anonymous") private var shareAnonymouslyToTribe = false
    @State private var entries: [HelpEntry] = [
        HelpEntry(id: 0),
        HelpEntry(id: 1),
        HelpEntry(id: 2)
    ]

    @FocusState private var focusedField: HelpStrangersInputField?
    @State private var showNoorMoment = false

    private let matteBackground = Color(hex: "1A1A1A")
    private let sapphireBlue = Color(hex: "2C85FF")
    private let sapphireNeon = Color(hex: "25D7FF")

    private var canSubmit: Bool {
        entries.allSatisfy(\.isValid)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [matteBackground, matteBackground.opacity(0.97), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                Capsule()
                    .fill(Color.white.opacity(0.16))
                    .frame(width: 54, height: 5)
                    .padding(.top, 8)

                headerView

                VStack(spacing: 12) {
                    ForEach(entries.indices, id: \.self) { index in
                        HelpEntryInputCard(
                            index: index + 1,
                            entry: $entries[index],
                            field: .note(index),
                            focusedField: $focusedField,
                            accent: sapphireBlue,
                            glow: sapphireNeon,
                            onSubmit: {
                                if index < entries.count - 1 {
                                    focusedField = .note(index + 1)
                                } else {
                                    completeTapped()
                                }
                            }
                        )
                    }
                }

                Spacer(minLength: 4)

                completeButton
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 22)
        }
        .sheet(isPresented: $showNoorMoment) {
            NoorMomentSheet(
                shareAnonymouslyToTribe: $shareAnonymouslyToTribe,
                onDone: {
                    showNoorMoment = false
                    onComplete()
                    dismiss()
                }
            )
            .presentationDetents([.height(292)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(22)
        }
    }

    private var headerView: some View {
        VStack(spacing: 12) {
            Image("1.1.Quests")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .shadow(color: sapphireNeon.opacity(0.58), radius: 16, x: 0, y: 0)
                .shadow(color: sapphireBlue.opacity(0.36), radius: 22, x: 0, y: 8)

            Text(L10n.t("quests.help_sheet.title"))
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(L10n.t("quests.help_sheet.subtitle"))
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            Text(L10n.t("quests.help_sheet.microcopy"))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.62))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
    }

    private var completeButton: some View {
        Button {
            completeTapped()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 17, weight: .bold))
                Text(L10n.t("quests.help_sheet.button.complete"))
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(buttonFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(canSubmit ? 0.16 : 0.08), lineWidth: 1)
            )
            .shadow(color: canSubmit ? sapphireNeon.opacity(0.45) : .clear, radius: 12, x: 0, y: 8)
        }
        .disabled(!canSubmit)
        .opacity(canSubmit ? 1 : 0.45)
        .accessibilityLabel(L10n.t("quests.help_sheet.accessibility.complete_button"))
    }

    private var buttonFill: AnyShapeStyle {
        if canSubmit {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [sapphireBlue, sapphireNeon],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }
        return AnyShapeStyle(Color.white.opacity(0.12))
    }

    private func completeTapped() {
        guard canSubmit else { return }
        focusedField = nil

        let feedback = UIImpactFeedbackGenerator(style: .light)
        feedback.prepare()
        feedback.impactOccurred()

        showNoorMoment = true
    }
}

private struct HelpEntryInputCard: View {
    let index: Int
    @Binding var entry: HelpEntry
    let field: HelpStrangersInputField
    @FocusState.Binding var focusedField: HelpStrangersInputField?
    let accent: Color
    let glow: Color
    let onSubmit: () -> Void

    @Environment(\.layoutDirection) private var layoutDirection

    private var isFocused: Bool {
        focusedField == field
    }

    private var alignment: Alignment {
        layoutDirection == .rightToLeft ? .trailing : .leading
    }

    var body: some View {
        VStack(alignment: alignment.horizontal, spacing: 8) {
            Text(
                String(
                    format: L10n.t("quests.help_sheet.entry_label"),
                    locale: Locale.current,
                    index
                )
            )
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(Color.white.opacity(0.78))

            HStack(spacing: 8) {
                Text(L10n.t("quests.help_sheet.prefix"))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.9))

                TextField(L10n.t("quests.help_sheet.placeholder"), text: $entry.text, axis: .vertical)
                    .lineLimit(1 ... 2)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .focused($focusedField, equals: field)
                    .multilineTextAlignment(layoutDirection == .rightToLeft ? .trailing : .leading)
                    .submitLabel(index == 3 ? .done : .next)
                    .onSubmit(onSubmit)
                    .tint(glow)
                    .accessibilityLabel(
                        String(
                            format: L10n.t("quests.help_sheet.accessibility.note_input"),
                            locale: Locale.current,
                            index
                        )
                    )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: alignment)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isFocused ? accent.opacity(0.95) : accent.opacity(0.32), lineWidth: 1.15)
            )
            .shadow(color: isFocused ? glow.opacity(0.5) : .clear, radius: 10, x: 0, y: 0)

            HStack(spacing: 10) {
                HelpMetaPicker(
                    title: L10n.t("quests.help_sheet.type.label"),
                    selection: $entry.type,
                    options: HelpType.allCases,
                    accent: accent,
                    optionTitle: { $0.title }
                )
                .accessibilityLabel(
                    String(
                        format: L10n.t("quests.help_sheet.accessibility.type_picker"),
                        locale: Locale.current,
                        index
                    )
                )

                HelpMetaPicker(
                    title: L10n.t("quests.help_sheet.impact.label"),
                    selection: $entry.impact,
                    options: HelpImpact.allCases,
                    accent: accent,
                    optionTitle: { $0.title }
                )
                .accessibilityLabel(
                    String(
                        format: L10n.t("quests.help_sheet.accessibility.impact_picker"),
                        locale: Locale.current,
                        index
                    )
                )
            }
        }
    }
}

private struct HelpMetaPicker<Value: Hashable>: View {
    let title: String
    @Binding var selection: Value
    let options: [Value]
    let accent: Color
    let optionTitle: (Value) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.65))

            Picker(title, selection: $selection) {
                ForEach(options, id: \.self) { option in
                    Text(optionTitle(option)).tag(option)
                }
            }
            .pickerStyle(.menu)
            .tint(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(accent.opacity(0.28), lineWidth: 1)
            )
        }
    }
}

private struct NoorMomentSheet: View {
    @Binding var shareAnonymouslyToTribe: Bool
    let onDone: () -> Void

    private let matteBackground = Color(hex: "1A1A1A")
    private let sapphireBlue = Color(hex: "2C85FF")

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [matteBackground, matteBackground.opacity(0.98), Color.black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                Capsule()
                    .fill(Color.white.opacity(0.16))
                    .frame(width: 54, height: 5)
                    .padding(.top, 8)

                Text(L10n.t("quests.help_sheet.noor.title"))
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                Text(L10n.t("quests.help_sheet.noor.subtitle"))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.78))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 10)

                Toggle(L10n.t("quests.help_sheet.noor.share_toggle"), isOn: $shareAnonymouslyToTribe)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .tint(sapphireBlue)
                    .padding(.horizontal, 4)

                Button(action: onDone) {
                    Text(L10n.t("quests.help_sheet.noor.done"))
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(sapphireBlue)
                        )
                }
                .accessibilityLabel(L10n.t("quests.help_sheet.accessibility.noor_done"))
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
    }
}
