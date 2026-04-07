import SwiftUI
import PhotosUI
import MessageUI
import UIKit

// MARK: - Profile Visibility Card

struct ProfileVisibilityCard: View {
    @Binding var isPublic: Bool
    let isSyncing: Bool
    let syncFailed: Bool
    let onToggle: (Bool) -> Void

    @Environment(\.layoutDirection) private var layoutDirection

    private var isRTL: Bool { layoutDirection == .rightToLeft }

    private var accentColor: Color {
        isPublic ? ProfilePalette.mint : ProfilePalette.mint
    }

    private var statusIcon: String {
        isPublic ? "eye.fill" : "eye.slash.fill"
    }

    private var statusText: String {
        isPublic ? "عام" : "خاص"
    }

    var body: some View {
        VStack(alignment: isRTL ? .trailing : .leading, spacing: 0) {
            ProfileSectionHeader(
                title: NSLocalizedString(
                    "screen.profile.section.visibility",
                    value: "Visibility",
                    comment: ""
                )
            )
            .padding(.bottom, 10)

            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    if isRTL { toggleSwitch }

                    VStack(alignment: isRTL ? .trailing : .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            if !isRTL { statusBadge }

                            Text("حساب عام")
                                .font(.system(size: 15.5, weight: .black, design: .rounded))
                                .foregroundStyle(ProfilePalette.textPrimary)

                            if isRTL { statusBadge }
                        }

                        Text("تظهر للقبائل والارينا")
                            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(ProfilePalette.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)

                    if !isRTL { toggleSwitch }
                }

                Rectangle()
                    .fill(ProfilePalette.stroke)
                    .frame(height: 1)
                    .padding(.horizontal, 4)

                HStack(spacing: 8) {
                    if !isRTL { privacyInfoIcon }

                    Text("إيقاف هذا الخيار سيخفي اسمك الصريح ويعرض أحرفك الأولى فقط في لوحة الصدارة")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(ProfilePalette.textTertiary)
                        .multilineTextAlignment(isRTL ? .trailing : .leading)
                        .fixedSize(horizontal: false, vertical: true)

                    if isRTL { privacyInfoIcon }
                }

                if syncFailed {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text("فشل التحديث — حاول مرة أخرى")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.red.opacity(0.8))
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(.red.opacity(0.08))
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background {
                ProfileSurface(tone: .pearl, cornerRadius: 22)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: isPublic)
        .animation(.easeInOut(duration: 0.25), value: syncFailed)
    }

    private var toggleSwitch: some View {
        ZStack {
            if isSyncing {
                ProgressView()
                    .tint(accentColor)
                    .scaleEffect(0.8)
                    .frame(width: 51, height: 31)
            } else {
                Toggle("", isOn: Binding(
                    get: { isPublic },
                    set: { onToggle($0) }
                ))
                .toggleStyle(SwitchToggleStyle(tint: Color(hex: "B7E3CA")))
                .labelsHidden()
                .frame(width: 51)
            }
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: statusIcon)
                .font(.system(size: 9, weight: .bold))
            Text(statusText)
                .font(.system(size: 9.5, weight: .heavy, design: .rounded))
        }
        .foregroundStyle(isPublic ? Color(hex: "3BA87A") : ProfilePalette.textTertiary)
        .padding(.horizontal, 7)
        .padding(.vertical, 3.5)
        .background(
            Capsule(style: .continuous)
                .fill(accentColor.opacity(0.22))
        )
    }

    private var privacyInfoIcon: some View {
        Image(systemName: "info.circle")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(ProfilePalette.textTertiary)
    }
}

struct ProfileBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    ProfilePalette.backgroundTop,
                    ProfilePalette.backgroundBottom
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            Circle()
                .fill(ProfilePalette.mint.opacity(0.21))
                .frame(width: 240, height: 240)
                .blur(radius: 52)
                .offset(x: -148, y: -238)

            Circle()
                .fill(ProfilePalette.mint.opacity(0.15))
                .frame(width: 280, height: 280)
                .blur(radius: 56)
                .offset(x: 148, y: -110)

            RoundedRectangle(cornerRadius: 120, style: .continuous)
                .fill(Color.white.opacity(0.28))
                .frame(width: 300, height: 240)
                .blur(radius: 72)
                .offset(y: 240)
        }
    }
}

struct ProfileHeroCard: View {
    @Binding var selectedPhoto: PhotosPickerItem?
    let avatarImage: UIImage?
    let displayName: String
    let displayUsername: String
    let subtitle: String
    let levelSummary: ProfileLevelSummary
    let lineScoreText: String
    let onEditName: () -> Void
    let onLevelTap: () -> Void

    @Environment(\.layoutDirection) private var layoutDirection

    private var isRTL: Bool {
        layoutDirection == .rightToLeft
    }

    private var textAlignment: Alignment {
        isRTL ? .trailing : .leading
    }

    private var multilineAlignment: TextAlignment {
        isRTL ? .trailing : .leading
    }

    private var shieldSymbol: String {
        LevelSystem.getShieldIconName(for: levelSummary.level)
    }

    private var progressPercentageText: String {
        "\(Int(levelSummary.clampedProgress * 100))%"
    }

    var body: some View {
        VStack(alignment: isRTL ? .trailing : .leading, spacing: 14) {
            if isRTL {
                HStack(alignment: .center, spacing: 14) {
                    identityBlock
                    avatarPicker
                }
            } else {
                HStack(alignment: .center, spacing: 14) {
                    avatarPicker
                    identityBlock
                }
            }

            Button(action: onLevelTap) {
                VStack(alignment: isRTL ? .trailing : .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        if isRTL {
                            ProfileStatPill(
                                title: NSLocalizedString("line_score", value: "Line Score", comment: ""),
                                value: lineScoreText,
                                symbol: "chart.line.uptrend.xyaxis",
                                flipsForRTL: true
                            )

                            ProfileStatPill(
                                title: NSLocalizedString("level", value: "Level", comment: ""),
                                value: "\(levelSummary.level)",
                                symbol: shieldSymbol,
                                flipsForRTL: true
                            )
                        } else {
                            ProfileStatPill(
                                title: NSLocalizedString("level", value: "Level", comment: ""),
                                value: "\(levelSummary.level)",
                                symbol: shieldSymbol
                            )

                            ProfileStatPill(
                                title: NSLocalizedString("line_score", value: "Line Score", comment: ""),
                                value: lineScoreText,
                                symbol: "chart.line.uptrend.xyaxis"
                            )
                        }
                    }

                    VStack(alignment: isRTL ? .trailing : .leading, spacing: 6) {
                        HStack {
                            Text(
                                NSLocalizedString(
                                    "screen.profile.hero.progress",
                                    value: "Progress to next level",
                                    comment: ""
                                )
                            )
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(ProfilePalette.textSecondary)

                            Spacer(minLength: 8)

                            Text(progressPercentageText)
                                .font(.system(size: 14, weight: .black, design: .rounded))
                                .foregroundStyle(ProfilePalette.textPrimary)
                                .contentTransition(.numericText())
                        }

                        ProfileProgressBar(progress: levelSummary.clampedProgress)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background {
                    ProfileInsetSurface(fill: ProfilePalette.pearl.opacity(0.54), cornerRadius: 22)
                }
            }
            .buttonStyle(ProfileCardButtonStyle())
        }
        .padding(18)
        .background {
            ProfileSurface(tone: .sand, cornerRadius: 28)
        }
    }

    private var avatarPicker: some View {
        PhotosPicker(selection: $selectedPhoto, matching: .images) {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let avatarImage {
                        Image(uiImage: avatarImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(ProfilePalette.textPrimary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(ProfilePalette.pearl.opacity(0.48))
                    }
                }
                .frame(width: 82, height: 82)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.76), lineWidth: 1.5)
                }
                .shadow(color: ProfilePalette.sand.opacity(0.18), radius: 14, x: 0, y: 9)

                ProfileIconBadge(
                    symbol: "camera.fill",
                    size: 26,
                    background: ProfilePalette.pearl.opacity(0.84),
                    foreground: ProfilePalette.textPrimary
                )
                .offset(x: isRTL ? -4 : 4, y: 4)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            NSLocalizedString(
                "screen.profile.hero.avatar.action",
                value: "Change profile photo",
                comment: ""
            )
        )
    }

    private var identityBlock: some View {
        VStack(alignment: isRTL ? .trailing : .leading, spacing: 5) {
            Text(NSLocalizedString("screen.profile.chip", value: "Profile", comment: ""))
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(ProfilePalette.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background {
                    ProfilePillSurface(fill: ProfilePalette.pearl.opacity(0.54))
                }

            Button(action: onEditName) {
                Text(displayName)
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(ProfilePalette.textPrimary)
                    .multilineTextAlignment(multilineAlignment)
                    .frame(maxWidth: .infinity, alignment: textAlignment)
                    .lineLimit(2)
            }
            .buttonStyle(.plain)

            Text(displayUsername)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(ProfilePalette.textSecondary)

            Text(subtitle)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(ProfilePalette.textSecondary)
                .multilineTextAlignment(multilineAlignment)
                .frame(maxWidth: .infinity, alignment: textAlignment)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: textAlignment)
    }
}

struct BioScanSummaryCard: View {
    let weightValue: String
    let weightUnit: String
    let subtitle: String
    let highlight: BioScanHighlight
    let action: () -> Void

    @Environment(\.layoutDirection) private var layoutDirection

    private var isRTL: Bool {
        layoutDirection == .rightToLeft
    }

    private var textAlignment: Alignment {
        isRTL ? .trailing : .leading
    }

    var body: some View {
        Button(action: action) {
            Group {
                if isRTL {
                    HStack(alignment: .center, spacing: 14) {
                        actionCluster
                        bodyCopy
                    }
                } else {
                    HStack(alignment: .center, spacing: 14) {
                        bodyCopy
                        actionCluster
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background {
                ProfileSurface(tone: .mint, cornerRadius: 24)
            }
        }
        .buttonStyle(ProfileCardButtonStyle())
    }

    private var bodyCopy: some View {
        VStack(alignment: isRTL ? .trailing : .leading, spacing: 5) {
            Text(NSLocalizedString("screen.profile.metric.weight", value: "Weight", comment: ""))
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(ProfilePalette.textSecondary)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(weightValue)
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(ProfilePalette.textPrimary)
                    .contentTransition(.numericText())

                if !weightUnit.isEmpty {
                    Text(weightUnit)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(ProfilePalette.textSecondary)
                }
            }

            Text(subtitle)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(ProfilePalette.textSecondary)
                .multilineTextAlignment(isRTL ? .trailing : .leading)
                .frame(maxWidth: .infinity, alignment: textAlignment)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: textAlignment)
    }

    private var actionCluster: some View {
        VStack(alignment: isRTL ? .leading : .trailing, spacing: 8) {
            ProfileInsightPill(
                title: highlight.title,
                value: highlight.value,
                symbol: highlight.symbol
            )

            HStack(spacing: 8) {
                ProfileIconBadge(
                    symbol: "waveform.path.ecg.rectangle.fill",
                    size: 42,
                    background: ProfilePalette.pearl.opacity(0.5),
                    foreground: ProfilePalette.textPrimary
                )

                ProfileDisclosureBadge(size: 30)
            }
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let symbol: String
    let tone: ProfileSurfaceTone
    let action: () -> Void

    @Environment(\.layoutDirection) private var layoutDirection

    var body: some View {
        Button(action: action) {
            VStack(alignment: layoutDirection == .rightToLeft ? .trailing : .leading, spacing: 12) {
                ProfileIconBadge(
                    symbol: symbol,
                    size: 38,
                    background: ProfilePalette.pearl.opacity(0.54),
                    foreground: ProfilePalette.textPrimary
                )

                VStack(alignment: layoutDirection == .rightToLeft ? .trailing : .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(ProfilePalette.textSecondary)

                    Text(value)
                        .font(.system(size: 19, weight: .black, design: .rounded))
                        .foregroundStyle(ProfilePalette.textPrimary)
                        .multilineTextAlignment(layoutDirection == .rightToLeft ? .trailing : .leading)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 102, alignment: layoutDirection == .rightToLeft ? .trailing : .leading)
            .padding(14)
            .background {
                ProfileSurface(tone: tone, cornerRadius: 22)
            }
        }
        .buttonStyle(ProfileCardButtonStyle())
    }
}

struct PreferenceSelectorCard: View {
    @Binding var selection: ActivityNotificationGender

    @Environment(\.layoutDirection) private var layoutDirection

    private var isRTL: Bool {
        layoutDirection == .rightToLeft
    }

    private var displayOptions: [ActivityNotificationGender] {
        let base: [ActivityNotificationGender] = [.male, .female]
        return isRTL ? Array(base.reversed()) : base
    }

    var body: some View {
        VStack(alignment: isRTL ? .trailing : .leading, spacing: 12) {
            if isRTL {
                HStack(spacing: 10) {
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(NSLocalizedString("gender", value: "Gender", comment: ""))
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundStyle(ProfilePalette.textPrimary)

                        Text(
                            NSLocalizedString(
                                "screen.profile.preferences.subtitle",
                                value: "Used for training and notification personalization",
                                comment: ""
                            )
                        )
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(ProfilePalette.textSecondary)
                        .multilineTextAlignment(.trailing)
                    }

                    Spacer(minLength: 8)

                    ProfileIconBadge(
                        symbol: "figure.arms.open",
                        size: 38,
                        background: ProfilePalette.pearl.opacity(0.46),
                        foreground: ProfilePalette.textPrimary
                    )
                }
            } else {
                HStack(spacing: 10) {
                    ProfileIconBadge(
                        symbol: "figure.arms.open",
                        size: 38,
                        background: ProfilePalette.pearl.opacity(0.46),
                        foreground: ProfilePalette.textPrimary
                    )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(NSLocalizedString("gender", value: "Gender", comment: ""))
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundStyle(ProfilePalette.textPrimary)

                        Text(
                            NSLocalizedString(
                                "screen.profile.preferences.subtitle",
                                value: "Used for training and notification personalization",
                                comment: ""
                            )
                        )
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(ProfilePalette.textSecondary)
                    }
                }
            }

            HStack(spacing: 8) {
                ForEach(displayOptions, id: \.self) { option in
                    let isSelected = option == selection

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                            selection = option
                        }
                    } label: {
                        Text(title(for: option))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(isSelected ? ProfilePalette.textPrimary : ProfilePalette.textSecondary)
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .background {
                                Group {
                                    if isSelected {
                                        ProfileInsetSurface(fill: ProfilePalette.pearl.opacity(0.86), cornerRadius: 18)
                                    } else {
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .fill(ProfilePalette.pearl.opacity(0.18))
                                    }
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                }
            }
            .padding(4)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(ProfilePalette.pearl.opacity(0.22))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.42), lineWidth: 1)
                    }
            }
        }
        .padding(16)
        .background {
            ProfileSurface(tone: .mint, cornerRadius: 22)
        }
    }

    private func title(for option: ActivityNotificationGender) -> String {
        switch option {
        case .male:
            return NSLocalizedString("male", value: "Male", comment: "")
        case .female:
            return NSLocalizedString("female", value: "Female", comment: "")
        }
    }
}

struct AppActionRow: View {
    let icon: String
    let iconFill: Color
    let title: String
    let subtitle: String
    var tone: ProfileSurfaceTone = .sand
    let action: () -> Void

    @Environment(\.layoutDirection) private var layoutDirection

    private var isRTL: Bool {
        layoutDirection == .rightToLeft
    }

    var body: some View {
        Button(action: action) {
            Group {
                if isRTL {
                    HStack(spacing: 12) {
                        ProfileDisclosureBadge(size: 28)

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(title)
                                .font(.system(size: 15, weight: .black, design: .rounded))
                                .foregroundStyle(ProfilePalette.textPrimary)

                            Text(subtitle)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(ProfilePalette.textSecondary)
                                .multilineTextAlignment(.trailing)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)

                        ProfileIconBadge(
                            symbol: icon,
                            size: 38,
                            background: iconFill,
                            foreground: ProfilePalette.textPrimary
                        )
                    }
                } else {
                    HStack(spacing: 12) {
                        ProfileIconBadge(
                            symbol: icon,
                            size: 38,
                            background: iconFill,
                            foreground: ProfilePalette.textPrimary
                        )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(title)
                                .font(.system(size: 15, weight: .black, design: .rounded))
                                .foregroundStyle(ProfilePalette.textPrimary)

                            Text(subtitle)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(ProfilePalette.textSecondary)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        ProfileDisclosureBadge(size: 28)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background {
                ProfileSurface(tone: tone, cornerRadius: 20)
            }
        }
        .buttonStyle(ProfileCardButtonStyle())
    }
}

struct BioMetricsSheet: View {
    let currentWeight: String
    let metrics: [BioMetricDetail]
    let onEditWeight: () -> Void

    @Environment(\.layoutDirection) private var layoutDirection

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    private var isRTL: Bool {
        layoutDirection == .rightToLeft
    }

    var body: some View {
        ZStack {
            ProfileBackdrop()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: isRTL ? .trailing : .leading, spacing: 20) {
                    Group {
                        if isRTL {
                            HStack(alignment: .top, spacing: 12) {
                                updateButton
                                Spacer(minLength: 8)
                                headerCopy
                            }
                        } else {
                            HStack(alignment: .top, spacing: 12) {
                                headerCopy
                                Spacer(minLength: 8)
                                updateButton
                            }
                        }
                    }

                    VStack(alignment: isRTL ? .trailing : .leading, spacing: 10) {
                        Text(NSLocalizedString("screen.profile.metric.weight", value: "Weight", comment: ""))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(ProfilePalette.textSecondary)

                        Text(currentWeight)
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .foregroundStyle(ProfilePalette.textPrimary)

                        Text(
                            NSLocalizedString(
                                "screen.profile.bioSheet.caption",
                                value: "Latest body composition synced from HealthKit",
                                comment: ""
                            )
                        )
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(ProfilePalette.textSecondary)
                        .multilineTextAlignment(isRTL ? .trailing : .leading)
                    }
                    .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)
                    .padding(20)
                    .background {
                        ProfileSurface(tone: .mint, cornerRadius: 30)
                    }

                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(metrics) { metric in
                            BioMetricTile(metric: metric)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 22)
            }
        }
    }

    private var headerCopy: some View {
        VStack(alignment: isRTL ? .trailing : .leading, spacing: 6) {
            Text(
                NSLocalizedString(
                    "screen.profile.bioSheet.title",
                    value: "Bio-Scan Details",
                    comment: ""
                )
            )
            .font(.system(size: 28, weight: .black, design: .rounded))
            .foregroundStyle(ProfilePalette.textPrimary)

            Text(
                NSLocalizedString(
                    "screen.profile.bioSheet.subtitle",
                    value: "A quick look at your current body composition snapshot.",
                    comment: ""
                )
            )
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundStyle(ProfilePalette.textSecondary)
            .multilineTextAlignment(isRTL ? .trailing : .leading)
        }
    }

    private var updateButton: some View {
        Button(action: onEditWeight) {
            Text(NSLocalizedString("screen.profile.editWeight.title", value: "Update Weight", comment: ""))
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(ProfilePalette.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background {
                    ProfilePillSurface(fill: ProfilePalette.pearl.opacity(0.82))
                }
        }
        .buttonStyle(ProfileCardButtonStyle())
    }
}

struct BioMetricTile: View {
    let metric: BioMetricDetail

    @Environment(\.layoutDirection) private var layoutDirection

    var body: some View {
        VStack(alignment: layoutDirection == .rightToLeft ? .trailing : .leading, spacing: 16) {
            ProfileIconBadge(
                symbol: metric.symbol,
                size: 46,
                background: ProfilePalette.pearl.opacity(0.54),
                foreground: ProfilePalette.textPrimary
            )

            VStack(alignment: layoutDirection == .rightToLeft ? .trailing : .leading, spacing: 6) {
                Text(metric.title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(ProfilePalette.textSecondary)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(metric.value)
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(ProfilePalette.textPrimary)

                    if !metric.unit.isEmpty {
                        Text(metric.unit)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(ProfilePalette.textSecondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 156, alignment: layoutDirection == .rightToLeft ? .trailing : .leading)
        .padding(18)
        .background {
            ProfileSurface(tone: metric.tone, cornerRadius: 26)
        }
    }
}

struct ProfileSectionHeader: View {
    let title: String

    @Environment(\.layoutDirection) private var layoutDirection

    var body: some View {
        Text(title)
            .font(.system(size: 18, weight: .black, design: .rounded))
            .foregroundStyle(ProfilePalette.textPrimary)
            .frame(maxWidth: .infinity, alignment: layoutDirection == .rightToLeft ? .trailing : .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

struct ProfileStatPill: View {
    let title: String
    let value: String
    let symbol: String
    var flipsForRTL = false

    @Environment(\.layoutDirection) private var layoutDirection

    private var isRTL: Bool {
        layoutDirection == .rightToLeft
    }

    var body: some View {
        HStack(spacing: 8) {
            if isRTL && flipsForRTL {
                textBlock
                icon
            } else {
                icon
                textBlock
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background {
            ProfilePillSurface(fill: ProfilePalette.pearl.opacity(0.44))
        }
    }

    private var textBlock: some View {
        VStack(alignment: isRTL && flipsForRTL ? .trailing : .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(ProfilePalette.textSecondary)

            Text(value)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(ProfilePalette.textPrimary)
                .contentTransition(.numericText())
        }
    }

    private var icon: some View {
        ProfileIconBadge(
            symbol: symbol,
            size: 30,
            background: ProfilePalette.pearl.opacity(0.48),
            foreground: ProfilePalette.textPrimary
        )
    }
}

struct ProfileInsightPill: View {
    let title: String
    let value: String
    let symbol: String

    @Environment(\.layoutDirection) private var layoutDirection

    var body: some View {
        HStack(spacing: 10) {
            ProfileIconBadge(
                symbol: symbol,
                size: 30,
                background: ProfilePalette.pearl.opacity(0.5),
                foreground: ProfilePalette.textPrimary
            )

            VStack(alignment: layoutDirection == .rightToLeft ? .trailing : .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(ProfilePalette.textSecondary)

                Text(value)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(ProfilePalette.textPrimary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background {
            ProfilePillSurface(fill: ProfilePalette.pearl.opacity(0.40))
        }
    }
}

struct ProfilePillSurface: View {
    let fill: Color

    var body: some View {
        Capsule(style: .continuous)
            .fill(fill)
            .overlay {
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                ProfilePalette.innerGlow.opacity(0.42),
                                Color.white.opacity(0.08),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .overlay {
                Capsule(style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.78),
                                Color.white.opacity(0.28)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: Color.black.opacity(0.018), radius: 6, x: 0, y: 3)
    }
}

struct ProfileIconBadge: View {
    let symbol: String
    var size: CGFloat = 40
    var background: Color = ProfilePalette.whiteSoft
    var foreground: Color = ProfilePalette.textPrimary

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.36, style: .continuous)
            .fill(background)
            .frame(width: size, height: size)
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.36, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                ProfilePalette.innerGlow.opacity(0.36),
                                Color.white.opacity(0.08),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.34, weight: .bold))
                    .foregroundStyle(foreground)
            }
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.36, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.78),
                                Color.white.opacity(0.26)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: Color.black.opacity(0.02), radius: 7, x: 0, y: 4)
    }
}

struct ProfileDisclosureBadge: View {
    @Environment(\.layoutDirection) private var layoutDirection
    var size: CGFloat = 32
    var background: Color = ProfilePalette.pearl.opacity(0.58)

    var body: some View {
        ProfileIconBadge(
            symbol: layoutDirection == .rightToLeft ? "chevron.left" : "chevron.right",
            size: size,
            background: background,
            foreground: ProfilePalette.textSecondary
        )
    }
}

struct ProfileProgressBar: View {
    let progress: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let fillWidth = width * min(max(progress, 0), 1)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.36))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.34), lineWidth: 1)
                    }

                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(ProfilePalette.mint.opacity(0.22))
                    .frame(width: fillWidth)
                    .blur(radius: 2)

                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [ProfilePalette.mint, ProfilePalette.mint.opacity(0.5)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: fillWidth)

                Circle()
                    .fill(Color.white.opacity(0.94))
                    .frame(width: 12, height: 12)
                    .overlay {
                        Circle()
                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                    }
                    .shadow(color: Color.black.opacity(0.10), radius: 6, x: 0, y: 3)
                    .offset(x: max(0, min(fillWidth - 12, width - 12)))
                    .opacity(progress > 0.02 ? 1 : 0)
            }
            .animation(.spring(response: 0.32, dampingFraction: 0.88), value: progress)
        }
        .frame(height: 10)
    }
}

struct ProfileSurface: View {
    let tone: ProfileSurfaceTone
    var cornerRadius: CGFloat = 24

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: tone.gradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                tone.topSheen,
                                Color.white.opacity(0.10),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                .clear,
                                tone.bottomTint
                            ],
                            startPoint: .center,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(tone.materialOpacity)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [tone.rimStart, tone.rimEnd],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: tone.shadowTint, radius: 18, x: 0, y: 10)
            .shadow(color: ProfilePalette.shadow, radius: 7, x: 0, y: 4)
    }
}

struct ProfileInsetSurface: View {
    let fill: Color
    var cornerRadius: CGFloat = 20

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(fill)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                ProfilePalette.innerGlow.opacity(0.38),
                                Color.white.opacity(0.08),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.74),
                                Color.white.opacity(0.22)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: Color.black.opacity(0.022), radius: 10, x: 0, y: 5)
    }
}

struct ProfileCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .brightness(configuration.isPressed ? -0.015 : 0)
            .animation(.spring(response: 0.24, dampingFraction: 0.88), value: configuration.isPressed)
    }
}

struct SupportMailComposer: UIViewControllerRepresentable {
    let to: String
    let subject: String

    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(dismiss: dismiss)
    }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.setToRecipients([to])
        controller.setSubject(subject)
        controller.mailComposeDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        private let dismiss: DismissAction

        init(dismiss: DismissAction) {
            self.dismiss = dismiss
        }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            dismiss()
        }
    }
}
