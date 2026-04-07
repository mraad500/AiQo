import SwiftUI
import UIKit
internal import Combine

private enum TribeHubSection: String, CaseIterable, Identifiable {
    case core
    case arena
    case feed
    case galaxy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .core:
            return "المركز"
        case .arena:
            return "الأرينا"
        case .feed:
            return "السجل"
        case .galaxy:
            return "المجرة"
        }
    }
}

struct TribeHubScreen: View {
    @AppStorage(TribePreviewController.forcePreviewKey) private var forcePreviewMode = false

    @StateObject private var tribeStore = TribeStore.shared
    @StateObject private var previewController = TribePreviewController.shared
    @StateObject private var entitlementStore = EntitlementStore.shared

    @State private var inviteCode: String = ""
    @State private var isCreateSheetPresented = false
    @State private var isPaywallPresented = false
    @State private var isPreviewModeSheetPresented = false
    @State private var toastMessage: String?
    @State private var selectedSection: TribeHubSection = .core

    private var usesPreviewMode: Bool {
        #if DEBUG
        true
        #else
        forcePreviewMode
        #endif
    }

    private var canShowPreviewControls: Bool {
        #if DEBUG
        true
        #else
        forcePreviewMode
        #endif
    }

    private var activeTribe: Tribe? {
        usesPreviewMode ? previewController.tribe : tribeStore.currentTribe
    }

    private var activeMembers: [TribeMember] {
        usesPreviewMode ? previewController.members : tribeStore.members
    }

    private var activeMissions: [TribeMission] {
        usesPreviewMode ? previewController.missions : tribeStore.missions
    }

    private var activeEvents: [TribeEvent] {
        usesPreviewMode ? previewController.events : tribeStore.events
    }

    private var energyCurrent: Int {
        if usesPreviewMode {
            return previewController.energyProgress.current
        }

        return activeMembers.reduce(0) { $0 + $1.energyContributionToday }
    }

    private var energyTarget: Int {
        if usesPreviewMode {
            return previewController.energyProgress.target
        }

        return activeMissions.first(where: { $0.id == "mission-energy" })?.targetValue ?? 500
    }

    private var canCreateTribe: Bool {
        usesPreviewMode ? previewController.canCreateTribe : entitlementStore.canCreateTribe
    }

    private var galaxyNodeCount: Int {
        min(max(activeMembers.count, 10), 15)
    }

    private var isVisitorState: Bool {
        if usesPreviewMode {
            return previewController.state == .visitor
        }

        return activeTribe == nil
    }

    private var showsOwnerBadge: Bool {
        usesPreviewMode && previewController.showsOwnerBadge
    }

    private var previewUsesTextSparkButton: Bool {
        usesPreviewMode && canShowPreviewControls
    }

    private var usesPremiumSurface: Bool {
        selectedSection != .core
    }

    private var energyStatusLine: String {
        let remaining = max(energyTarget - energyCurrent, 0)
        if remaining == 0 {
            return "تم فتح الدرع اليوم."
        }
        return "باقي \(remaining) حتى نفتح الدرع"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                header
                sectionPicker

                if !usesPreviewMode && tribeStore.loading {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, 4)
                }

                contentView

                if !usesPreviewMode, let error = tribeStore.error {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 24)
        }
        .background(screenBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if usesPreviewMode {
                previewController.apply(state: previewController.state)
            } else {
                tribeStore.fetchTribe()
                if tribeStore.currentTribe != nil {
                    tribeStore.fetchMembers()
                    tribeStore.fetchMissions()
                }
            }
        }
        .sheet(isPresented: $isCreateSheetPresented) {
            TribeHubCreateTribeSheet { name in
                if usesPreviewMode {
                    previewController.createPreviewTribe(named: name)
                } else {
                    tribeStore.createTribe(name: name)
                    if tribeStore.currentTribe != nil {
                        tribeStore.fetchMembers()
                        tribeStore.fetchMissions()
                    }
                }
            }
        }
        .sheet(isPresented: $isPaywallPresented) {
            PaywallView(dismissOnFamilyUnlock: true)
        }
        .sheet(isPresented: $isPreviewModeSheetPresented) {
            TribePreviewModeSheet(
                selectedState: usesPreviewMode ? previewController.state : .visitor,
                onSelectState: { state in
                    previewController.apply(state: state)
                    isPreviewModeSheetPresented = false
                }
            )
        }
        .overlay(alignment: .bottom) {
            if let toastMessage {
                TribeSparkToast(message: toastMessage)
                    .padding(.bottom, 28)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: toastMessage)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("القبيلة")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(usesPremiumSurface ? Color.white : Color.primary)
                .onLongPressGesture(minimumDuration: 1.2) {
                    #if !DEBUG
                    forcePreviewMode.toggle()
                    if forcePreviewMode {
                        previewController.apply(state: .member)
                        toastMessage = "تم تفعيل وضع العرض"
                    } else {
                        toastMessage = "تم إيقاف وضع العرض"
                    }
                    clearToastAfterDelay()
                    #endif
                }

            Spacer(minLength: 0)

            if canShowPreviewControls {
                Button("وضع العرض") {
                    isPreviewModeSheetPresented = true
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(usesPremiumSurface ? Color.white.opacity(0.10) : Color.white.opacity(0.54))
                .foregroundStyle(usesPremiumSurface ? Color.white : Color.primary)
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 4)
    }

    private var sectionPicker: some View {
        TribeSegmentedPill(
            options: TribeHubSection.allCases,
            selection: $selectedSection,
            title: { $0.title },
            selectedTextColor: usesPremiumSurface ? .white : Color.primary,
            unselectedTextColor: usesPremiumSurface ? Color.white.opacity(0.66) : Color.primary.opacity(0.55),
            activeFill: usesPremiumSurface ? Color.white.opacity(0.12) : Color.black.opacity(0.08),
            backgroundFill: usesPremiumSurface ? Color.white.opacity(0.05) : Color.black.opacity(0.04),
            borderColor: usesPremiumSurface ? Color.white.opacity(0.08) : Color.black.opacity(0.06)
        )
        .padding(.horizontal, 4)
    }

    private var privacyBinding: Binding<PrivacyMode> {
        Binding(
            get: {
                if usesPreviewMode {
                    return previewController.currentUserPrivacyMode
                }
                return UserProfileStore.shared.tribePrivacyMode
            },
            set: { mode in
                if usesPreviewMode {
                    previewController.updateMyPrivacy(mode: mode)
                } else {
                    UserProfileStore.shared.setTribePrivacyMode(mode)
                }
            }
        )
    }

    @ViewBuilder
    private var contentView: some View {
        switch selectedSection {
        case .core:
            coreSectionContent
        case .arena:
            arenaSectionContent
        case .feed:
            feedSectionContent
        case .galaxy:
            galaxySectionContent
        }
    }

    @ViewBuilder
    private var coreSectionContent: some View {
        if isVisitorState {
            emptyState
            if usesPreviewMode {
                previewSections
            }
        } else {
            coreHubContent
        }
    }

    private var coreHubContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            TribeEnergyCoreCard(
                progressValue: energyCurrent,
                targetValue: energyTarget,
                headline: "طاقة القبيلة اليوم",
                statusLine: energyStatusLine
            )

            tribeGalaxyEntryCard

            if let tribe = activeTribe {
                TribeHubSettingsCard(
                    tribe: tribe,
                    privacyMode: privacyBinding,
                    showsOwnerBadge: showsOwnerBadge,
                    showsCreateButton: usesPreviewMode && previewController.state == .owner,
                    onCreate: {
                        isCreateSheetPresented = true
                    },
                    onLeave: {
                        if usesPreviewMode {
                            previewController.apply(state: .visitor)
                        } else {
                            tribeStore.leaveTribe()
                        }
                    }
                )
            }

            TribeMissionsListView(missions: activeMissions)
            TribeMembersListView(
                members: activeMembers,
                allowsSpark: usesPreviewMode ? canShowPreviewControls : true,
                sparkStyle: previewUsesTextSparkButton ? .text : .icon,
                onSparkSent: handleSparkSent,
                onSpark: handleSpark
            )
        }
    }

    @ViewBuilder
    private var arenaSectionContent: some View {
        ArenaScreen()
    }

    @ViewBuilder
    private var feedSectionContent: some View {
        TribeLogScreen()
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            TribeGlassPanel(style: .soft, tint: UIColor.systemTeal) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("مركز القبيلة جاهز")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))

                    Text("أنشئ قبيلة إذا كنت على الخطة العائلية، أو انضم بكود دعوة. بعد الدخول ستظهر طاقة القبيلة والمهام والأعضاء هنا.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Text(canCreateTribe ? "يمكنك إنشاء القبيلة الآن." : "الخطة العائلية مطلوبة لإنشاء قبيلة.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button {
                        if canCreateTribe {
                            isCreateSheetPresented = true
                        } else {
                            isPaywallPresented = true
                        }
                    } label: {
                        Text(canCreateTribe ? "إنشاء قبيلة" : "الخطة العائلية مطلوبة")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.7))
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }

            TribeGlassPanel(style: .glass, tint: UIColor.systemBlue) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("انضمام بكود")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))

                    TextField("اكتب كود الدعوة", text: $inviteCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 14)
                        .frame(height: 48)
                        .background(Color.white.opacity(0.48))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    Button {
                        if usesPreviewMode {
                            previewController.joinPreviewTribe()
                            inviteCode = ""
                        } else {
                            tribeStore.joinTribe(inviteCode: inviteCode)
                            if tribeStore.currentTribe != nil {
                                tribeStore.fetchMembers()
                                tribeStore.fetchMissions()
                                inviteCode = ""
                            }
                        }
                    } label: {
                        Text("انضم الآن")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.black.opacity(0.84))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
        }
    }

    private var previewSections: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("معاينة لما سيظهر بعد دخولك القبيلة")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            TribeEnergyCoreCard(
                progressValue: energyCurrent,
                targetValue: energyTarget,
                headline: "طاقة القبيلة اليوم",
                statusLine: energyStatusLine
            )

            tribeGalaxyEntryCard
            TribeMissionsListView(missions: activeMissions)
            TribeMembersListView(members: activeMembers, allowsSpark: false, sparkStyle: .none)
        }
        .padding(.top, 6)
    }

    private func handleSparkSent() {
        toastMessage = "تم إرسال شرارة"
        clearToastAfterDelay()
    }

    private func handleContribution(_ amount: Int) {
        if usesPreviewMode {
            previewController.addContribution(amount: amount, from: previewController.actionMemberId)
        } else {
            tribeStore.addContribution(amount: amount, from: tribeStore.actionMemberId)
        }

        toastMessage = "تمت إضافة المساهمة"
        clearToastAfterDelay()
    }

    private func handleSpark(_ memberId: String) {
        if usesPreviewMode {
            previewController.sendSpark(to: memberId)
        } else {
            tribeStore.sendSpark(to: memberId)
        }
    }

    private func clearToastAfterDelay() {
        let message = toastMessage

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            if toastMessage == message {
                toastMessage = nil
            }
        }
    }

    private func visitorOnlyNotice(title: String) -> some View {
        TribeGlassPanel(style: .glass, tint: UIColor.systemGray) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))

                Text("انضم إلى قبيلة أولاً حتى يظهر هذا القسم ببياناتك الحقيقية.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var galaxySectionContent: some View {
        GalaxyScreen()
    }

    private var tribeGalaxyEntryCard: some View {
        Button {
            withAnimation(.spring(response: 0.36, dampingFraction: 0.88)) {
                selectedSection = .galaxy
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.28, green: 0.46, blue: 0.72).opacity(0.24))
                        .frame(width: 64, height: 64)
                        .blur(radius: 14)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(0.96),
                                    Color(red: 0.72, green: 0.88, blue: 0.98).opacity(0.78),
                                    Color(red: 0.34, green: 0.54, blue: 0.82).opacity(0.30)
                                ],
                                center: .center,
                                startRadius: 4,
                                endRadius: 26
                            )
                        )
                        .frame(width: 34, height: 34)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("ادخل إلى المجرة")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("خريطة الأرواح، التحديات، وشرارة سريعة داخل نفس المدار.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.64))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.70))
            }
            .padding(18)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.05, green: 0.07, blue: 0.15).opacity(0.96),
                                Color(red: 0.08, green: 0.11, blue: 0.21).opacity(0.92)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(0.16), radius: 16, x: 0, y: 12)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var screenBackground: some View {
        if usesPremiumSurface {
            TribeGalaxyBackground()
        } else {
            backgroundGradient
        }
    }

    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                Color(red: 0.93, green: 0.97, blue: 0.99),
                Color(.systemBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct TribeMissionsListView: View {
    let missions: [TribeMission]

    var body: some View {
        TribeGlassPanel(style: .glass, tint: UIColor.systemIndigo) {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(title: "مهام القبيلة", subtitle: "خطوات جماعية قصيرة وواضحة.")

                if missions.isEmpty {
                    Text("لا توجد مهام حالياً.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(missions) { mission in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(mission.title)
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))

                                Spacer()

                                Text("\(mission.progressValue)/\(mission.targetValue)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            ProgressView(
                                value: Double(min(mission.progressValue, mission.targetValue)),
                                total: Double(max(mission.targetValue, 1))
                            )
                            .tint(.white.opacity(0.9))

                            Text("تنتهي \(mission.endsAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.34))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }
        }
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

enum TribeSparkButtonStyle {
    case none
    case icon
    case text
}

struct TribeMembersListView: View {
    let members: [TribeMember]
    let allowsSpark: Bool
    let sparkStyle: TribeSparkButtonStyle
    let onSparkSent: (() -> Void)?
    let onSpark: ((String) -> Void)?

    private let sparkStore = TribeSparkThrottleStore.shared
    @State private var now = Date()

    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    init(
        members: [TribeMember],
        allowsSpark: Bool = true,
        sparkStyle: TribeSparkButtonStyle = .icon,
        onSparkSent: (() -> Void)? = nil,
        onSpark: ((String) -> Void)? = nil
    ) {
        self.members = members
        self.allowsSpark = allowsSpark
        self.sparkStyle = sparkStyle
        self.onSparkSent = onSparkSent
        self.onSpark = onSpark
    }

    var body: some View {
        TribeGlassPanel(style: .soft, tint: UIColor.systemOrange) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("أعضاء القبيلة")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                    Text("المعروض هنا: الاسم عند العام فقط، والمستوى والطاقة العامة للجميع. لا تُعرض أي بيانات صحية.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if members.isEmpty {
                    Text("لا يوجد أعضاء بعد.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(members) { member in
                        TribeHubMemberRow(
                            member: member,
                            sparkStyle: allowsSpark ? sparkStyle : .none,
                            canSendSpark: sparkStore.canSendSpark(to: member.id, now: now),
                            onSendSpark: {
                                if sparkStore.sendSpark(to: member.id) {
                                    now = Date()
                                    onSpark?(member.id)
                                    onSparkSent?()
                                }
                            }
                        )
                    }
                }
            }
        }
        .onReceive(timer) { value in
            now = value
        }
    }
}

private struct TribeHubSettingsCard: View {
    let tribe: Tribe
    @Binding var privacyMode: PrivacyMode
    let showsOwnerBadge: Bool
    let showsCreateButton: Bool
    let onCreate: () -> Void
    let onLeave: () -> Void

    var body: some View {
        TribeGlassPanel(style: .glass, tint: UIColor.systemCyan) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(tribe.name)
                            .font(.system(size: 21, weight: .semibold, design: .rounded))

                        if showsOwnerBadge {
                            Text("قائد")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.55))
                                .clipShape(Capsule())
                        }
                    }

                    Text("كود الدعوة: \(tribe.inviteCode)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("خصوصية ملفك داخل القبيلة")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))

                    Picker("خصوصية ملفك داخل القبيلة", selection: $privacyMode) {
                        ForEach(PrivacyMode.allCases, id: \.rawValue) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text("الملف الخاص يخفي اسمك وصورتك الحقيقية، ويُبقي فقط المستوى ومساهمة الطاقة العامة.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if showsCreateButton {
                    Button(action: onCreate) {
                        Text("إنشاء قبيلة")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.70))
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                Button(role: .destructive, action: onLeave) {
                    Text("مغادرة القبيلة")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.70))
                        .foregroundStyle(.red)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct TribeHubMemberRow: View {
    let member: TribeMember
    let sparkStyle: TribeSparkButtonStyle
    let canSendSpark: Bool
    let onSendSpark: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            memberAvatar

            Text(member.privacyMode == .public ? member.displayName : "عضو")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text("طاقة \(member.energyContributionToday)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Lv \(member.level)")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.5))
                .clipShape(Capsule())

            if sparkStyle != .none {
                Button {
                    onSendSpark()
                } label: {
                    if sparkStyle == .text {
                        Text("شرارة")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(canSendSpark ? Color.white.opacity(0.58) : Color.white.opacity(0.26))
                            .clipShape(Capsule())
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 30, height: 30)
                            .background(canSendSpark ? Color.white.opacity(0.58) : Color.white.opacity(0.26))
                            .clipShape(Circle())
                    }
                }
                .buttonStyle(.plain)
                .disabled(!canSendSpark)
                .accessibilityLabel("إرسال شرارة")
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var memberAvatar: some View {
        Circle()
            .fill(Color.white.opacity(0.55))
            .frame(width: 42, height: 42)
            .overlay {
                if member.privacyMode == .private {
                    Image(systemName: "person.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                } else if member.avatarURL == "local-avatar", let image = UserProfileStore.shared.loadAvatar() {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .clipShape(Circle())
                } else if let avatarURL = member.avatarURL, !avatarURL.isEmpty, !avatarURL.hasPrefix("http") {
                    Image(avatarURL)
                        .resizable()
                        .scaledToFill()
                        .clipShape(Circle())
                } else if let avatarURL = member.avatarURL, avatarURL.hasPrefix("http"), let url = URL(string: avatarURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        default:
                            Image(systemName: "person.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .clipShape(Circle())
                } else if member.privacyMode == .public {
                    Text(String(member.displayName.prefix(1)).uppercased())
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
    }
}

private struct TribeHubCreateTribeSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var tribeName: String = ""

    let onCreate: (String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("اسم القبيلة") {
                    TextField("مثال: Calm Core", text: $tribeName)
                }
            }
            .navigationTitle("إنشاء قبيلة")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("إلغاء") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("إنشاء") {
                        onCreate(tribeName)
                        dismiss()
                    }
                    .disabled(tribeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct TribePreviewModeSheet: View {
    @Environment(\.dismiss) private var dismiss

    let selectedState: TribePreviewController.PreviewState
    let onSelectState: (TribePreviewController.PreviewState) -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(TribePreviewController.PreviewState.allCases) { state in
                    Button {
                        onSelectState(state)
                        dismiss()
                    } label: {
                        HStack {
                            Text(state.title)
                            Spacer()
                            if state == selectedState {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.yellow)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("وضع العرض")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct TribeSparkToast: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.82))
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.14), radius: 10, x: 0, y: 4)
    }
}

@MainActor
private final class TribeSparkThrottleStore {
    static let shared = TribeSparkThrottleStore()

    private let defaults = UserDefaults.standard
    private let storageKey = "aiqo.tribe.spark.lastSent"
    private let eventLogKey = "aiqo.tribe.spark.eventLog"
    private let cooldown: TimeInterval = 10 * 60

    func canSendSpark(to memberId: String, now: Date = Date()) -> Bool {
        guard let lastSent = lastSentDate(for: memberId) else { return true }
        return now.timeIntervalSince(lastSent) >= cooldown
    }

    func sendSpark(to memberId: String, now: Date = Date()) -> Bool {
        guard canSendSpark(to: memberId, now: now) else { return false }

        var timestamps = storedTimestamps()
        timestamps[memberId] = now.timeIntervalSince1970
        defaults.set(timestamps, forKey: storageKey)
        recordSparkEvent(for: memberId, sentAt: now)

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        print("✨ Spark sent to tribe member \(memberId).")
        return true
    }

    private func lastSentDate(for memberId: String) -> Date? {
        guard let timestamp = storedTimestamps()[memberId] else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

    private func storedTimestamps() -> [String: TimeInterval] {
        defaults.dictionary(forKey: storageKey) as? [String: TimeInterval] ?? [:]
    }

    private func recordSparkEvent(for memberId: String, sentAt: Date) {
        var entries = defaults.stringArray(forKey: eventLogKey) ?? []
        let formatter = ISO8601DateFormatter()
        entries.insert("spark:\(memberId):\(formatter.string(from: sentAt))", at: 0)
        defaults.set(Array(entries.prefix(20)), forKey: eventLogKey)
    }
}
