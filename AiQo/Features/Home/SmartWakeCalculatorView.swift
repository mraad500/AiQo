import SwiftUI

struct SmartWakeCalculatorView: View {
    @ObservedObject var viewModel: SmartWakeViewModel

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            headerSection
            modePicker

            switch viewModel.mode {
            case .fromBedtime:
                bedtimeInputSection
            case .fromWakeTime:
                wakeTimeInputSection
            }

            if let featuredRecommendation = viewModel.featuredRecommendation {
                resultsSection(featuredRecommendation: featuredRecommendation)
            } else if let inlineMessage = viewModel.inlineMessage {
                inlineState(message: inlineMessage)
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: viewModel.mode)
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: viewModel.featuredRecommendation?.id)
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: viewModel.selectedRecommendationID)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Smart Wake Calculator")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(AiQoTheme.Colors.textPrimary)

            Text("حاسبة الاستيقاظ الذكي")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(AiQoTheme.Colors.textSecondary)
        }
    }

    private var modePicker: some View {
        Picker("وضع الحاسبة", selection: modeBinding) {
            ForEach(SmartWakeMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }

    private var bedtimeInputSection: some View {
        SmartWakeInputCard(title: "اختر وقت النوم") {
            DatePicker(
                "اختر وقت النوم",
                selection: bedtimeBinding,
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
            .datePickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .frame(height: 164)
            .clipped()
        }
    }

    private var wakeTimeInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SmartWakeInputCard(title: "اختر آخر وقت لازم تصحى بيه") {
                DatePicker(
                    "اختر آخر وقت لازم تصحى بيه",
                    selection: latestWakeTimeBinding,
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
                .datePickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .frame(height: 164)
                .clipped()
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("نافذة الاستيقاظ")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(AiQoTheme.Colors.textPrimary)

                Picker("نافذة الاستيقاظ", selection: wakeWindowBinding) {
                    ForEach(SmartWakeWindow.allCases) { window in
                        Text(window.title).tag(window)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(14)
            .background(subtleCardBackground)
        }
    }

    private func resultsSection(featuredRecommendation: SmartWakeRecommendation) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("أفضل وقت مقترح للاستيقاظ")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(AiQoTheme.Colors.textPrimary)

                Text(resultSubtitle(for: featuredRecommendation))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(AiQoTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            SmartWakeFeaturedRecommendationCard(
                recommendation: featuredRecommendation,
                mode: viewModel.mode,
                latestWakeTime: viewModel.latestWakeTime,
                wakeWindow: viewModel.wakeWindow,
                isSelected: viewModel.selectedRecommendationID == featuredRecommendation.id,
                onTap: {
                    viewModel.selectRecommendation(featuredRecommendation)
                }
            )

            AlarmSetupCardView(
                recommendation: viewModel.selectedRecommendation ?? featuredRecommendation,
                saveState: viewModel.alarmSaveState,
                onSave: {
                    Task {
                        await viewModel.saveSelectedAlarm()
                    }
                }
            )

            if !viewModel.alternateRecommendations.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("اقتراحات أخرى")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(AiQoTheme.Colors.textPrimary)

                    VStack(spacing: 10) {
                        ForEach(viewModel.alternateRecommendations) { recommendation in
                            SmartWakeAlternateRecommendationCard(
                                recommendation: recommendation,
                                isSelected: viewModel.selectedRecommendationID == recommendation.id,
                                onTap: {
                                    viewModel.selectRecommendation(recommendation)
                                }
                            )
                        }
                    }
                }
            }
        }
    }

    private func inlineState(message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color(hex: "6D7CFF"))

            Text(message)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(AiQoTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(subtleCardBackground)
    }

    private func resultSubtitle(for recommendation: SmartWakeRecommendation) -> String {
        switch viewModel.mode {
        case .fromBedtime:
            return "اعتمادًا على دورات النوم التقديرية"
        case .fromWakeTime:
            if recommendation.isWithinSmartWindow {
                return "ضمن نافذة الاستيقاظ الذكي"
            }
            return "اعتمادًا على دورات النوم التقديرية"
        }
    }

    private var modeBinding: Binding<SmartWakeMode> {
        Binding(
            get: { viewModel.mode },
            set: { viewModel.setMode($0) }
        )
    }

    private var bedtimeBinding: Binding<Date> {
        Binding(
            get: { viewModel.bedtime },
            set: { viewModel.setBedtime($0) }
        )
    }

    private var latestWakeTimeBinding: Binding<Date> {
        Binding(
            get: { viewModel.latestWakeTime },
            set: { viewModel.setLatestWakeTime($0) }
        )
    }

    private var wakeWindowBinding: Binding<SmartWakeWindow> {
        Binding(
            get: { viewModel.wakeWindow },
            set: { viewModel.setWakeWindow($0) }
        )
    }

    private var subtleCardBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color.white.opacity(colorScheme == .dark ? 0.06 : 0.28))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.white.opacity(colorScheme == .dark ? 0.12 : 0.42), lineWidth: 1)
            )
    }
}

private struct SmartWakeInputCard<Content: View>: View {
    let title: String
    let content: Content

    @Environment(\.colorScheme) private var colorScheme

    init(
        title: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(AiQoTheme.Colors.textPrimary)

            content
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(colorScheme == .dark ? 0.06 : 0.28))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(.white.opacity(colorScheme == .dark ? 0.12 : 0.42), lineWidth: 1)
                )
        )
    }
}

private struct SmartWakeFeaturedRecommendationCard: View {
    let recommendation: SmartWakeRecommendation
    let mode: SmartWakeMode
    let latestWakeTime: Date
    let wakeWindow: SmartWakeWindow
    let isSelected: Bool
    let onTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(SmartWakeFormatters.time(recommendation.wakeDate))
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(hex: "0F1721"))
                            .minimumScaleFactor(0.7)

                        Text(recommendation.explanation)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color(hex: "365566"))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    Text(recommendation.badge)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: "18313D"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.55), in: Capsule())
                }

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10)
                    ],
                    alignment: .leading,
                    spacing: 10
                ) {
                    SmartWakeMetricPill(title: "عدد الدورات", value: "\(recommendation.cycleCount)")
                    SmartWakeMetricPill(title: "مدة النوم المتوقعة", value: SmartWakeFormatters.duration(recommendation.estimatedSleepDuration))
                    SmartWakeMetricPill(title: "مستوى الثقة", value: recommendation.confidenceLabel)

                    if mode == .fromWakeTime {
                        SmartWakeMetricPill(title: "آخر وقت مسموح", value: SmartWakeFormatters.time(latestWakeTime))
                        SmartWakeMetricPill(title: "نافذة الاستيقاظ", value: wakeWindow.title)
                    } else {
                        SmartWakeMetricPill(title: "النتيجة", value: recommendation.isBest ? "الأقرب للتوازن" : recommendation.badge)
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
        }
        .buttonStyle(.plain)
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(hex: "E3FFF4"),
                        Color(hex: "E4F0FF"),
                        Color(hex: "F3E8FF")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(colorScheme == .dark ? 0.44 : 0.86),
                                Color(hex: "AFC8FF").opacity(0.64)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isSelected ? 1.8 : 1.2
                    )
            )
            .shadow(
                color: Color(hex: "A7C7FF").opacity(isSelected ? 0.32 : 0.18),
                radius: isSelected ? 18 : 12,
                x: 0,
                y: 8
            )
    }
}

private struct SmartWakeAlternateRecommendationCard: View {
    let recommendation: SmartWakeRecommendation
    let isSelected: Bool
    let onTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(SmartWakeFormatters.time(recommendation.wakeDate))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(AiQoTheme.Colors.textPrimary)

                        Text(recommendation.badge)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(recommendation.cycleCount < 4 ? Color(hex: "7B4E1D") : Color(hex: "204A3D"))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(
                                recommendation.cycleCount < 4
                                ? Color(hex: "FFE7D0").opacity(0.88)
                                : Color(hex: "DFF7EF").opacity(0.88),
                                in: Capsule()
                            )
                    }

                    Text(recommendation.explanation)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(AiQoTheme.Colors.textSecondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 6) {
                    Text("\(recommendation.cycleCount) دورات")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(AiQoTheme.Colors.textPrimary)

                    Text(SmartWakeFormatters.duration(recommendation.estimatedSleepDuration))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(AiQoTheme.Colors.textSecondary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
            .opacity(recommendation.cycleCount < 4 ? 0.84 : 1)
        }
        .buttonStyle(.plain)
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color.white.opacity(colorScheme == .dark ? 0.06 : 0.24))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        isSelected
                        ? LinearGradient(
                            colors: [
                                Color(hex: "A8C8FF").opacity(0.92),
                                Color(hex: "BFEFDD").opacity(0.82)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(
                            colors: [
                                .white.opacity(colorScheme == .dark ? 0.14 : 0.36),
                                .white.opacity(colorScheme == .dark ? 0.06 : 0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isSelected ? 1.6 : 1
                    )
            )
    }
}

private struct SmartWakeMetricPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: "4E6876"))

            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: "13232D"))
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.52), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private enum SmartWakeFormatters {
    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    static func duration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = duration >= 3600 ? [.hour, .minute] : [.minute]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        formatter.zeroFormattingBehavior = .dropLeading
        return formatter.string(from: duration) ?? "0m"
    }
}

#Preview("Smart Wake Calculator") {
    SmartWakeCalculatorPreviewContainer()
        .padding()
        .background(
            LinearGradient(
                colors: [
                    Color(hex: "EEF3FA"),
                    Color(hex: "DCE6F3"),
                    Color(hex: "C8D7E7")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
}

private struct SmartWakeCalculatorPreviewContainer: View {
    @StateObject private var viewModel = SmartWakeViewModel(
        initialBedtime: Calendar.current.date(bySettingHour: 22, minute: 45, second: 0, of: Date()) ?? Date(),
        initialMode: .fromWakeTime
    )

    var body: some View {
        SmartWakeCalculatorView(viewModel: viewModel)
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
    }
}
