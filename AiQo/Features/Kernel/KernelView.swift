import SwiftUI
import FamilyControls

/// «النواة» (Kernel) — the feature's main HUB. Calm, premium, RTL, on the AiQo
/// DesignSystem (AiQoTheme / AiQoColors). Shows the kernel-charge ring, the apps
/// you've chosen to lock, mode, today's earned energy, and active sessions. When
/// a chosen app is locked, the challenge/unlock flow appears as a separate screen
/// (`KernelChallengeView`) — the hub holds no challenge UI.
struct KernelView: View {
    @StateObject private var model = KernelViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showConsent = false
    @State private var showChallenge = false
    @State private var showDisableConfirm = false

    private var isAr: Bool { AppSettingsStore.shared.appLanguage == .arabic }

    var body: some View {
        NavigationStack {
            ZStack {
                // Transparent so the sheet's frosted (.ultraThinMaterial) paper shows.
                Color.clear
                ScrollView(showsIndicators: false) {
                    VStack(spacing: AiQoSpacing.lg) {
                        switch model.gateState {
                        case .needsAuthorization: authorizeCard
                        case .ready: hubContent
                        case .featureDisabled, .tierLocked: gateLockedCard
                        }
                    }
                    .padding(AiQoSpacing.lg)
                }
            }
            // "Shield is down" mode — a soft, on-brand frame marks the locked state.
            .kernelLockedFrame(active: model.isLocked && model.gateState == .ready)
            .navigationTitle("النواة")
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.layoutDirection, .rightToLeft)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("تم") { dismiss() }
                }
            }
            .familyActivityPicker(
                isPresented: $model.isPresentingPicker,
                selection: Binding(get: { model.selection }, set: { model.updateSelection($0) })
            )
            .fullScreenCover(isPresented: $showChallenge) {
                KernelChallengeView(model: model)
            }
            .sheet(isPresented: $showConsent) {
                KernelConsentView(onAgree: { Task { await model.requestAuthorization() } })
            }
            .onAppear { model.onAppear() }
        }
    }

    // MARK: - Hub (authorized)

    private var hubContent: some View {
        VStack(spacing: AiQoSpacing.lg) {
            // Shield active → the big shield card leads; tapping it opens the
            // challenge. This is the reliable, always-present way in (no auto-pop).
            if model.isLocked {
                KernelUnlockShieldCard(stepTarget: model.lockedStepTarget, isArabic: isAr) {
                    showChallenge = true
                }
                .padding(.top, AiQoSpacing.sm)
            }
            heroChargeRing
            protectionControls
            editAppsButton
            energyCard
            sessionsCard
            footnote
        }
    }

    private var heroChargeRing: some View {
        VStack(spacing: AiQoSpacing.md) {
            ZStack {
                Circle().stroke(AiQoColors.mintSoft.opacity(0.22), lineWidth: 18)
                Circle()
                    .trim(from: 0, to: max(0.02, min(1, model.chargeLevel)))
                    .stroke(
                        AngularGradient(colors: [AiQoTheme.Colors.accent, AiQoColors.sandSoft], center: .center),
                        style: StrokeStyle(lineWidth: 18, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: model.chargeLevel)
                VStack(spacing: 2) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 26)).foregroundStyle(AiQoTheme.Colors.accent)
                    Text("\(Int(model.chargeLevel * 100))%")
                        .font(.system(size: 34, design: .rounded).weight(.bold))
                        .foregroundStyle(AiQoTheme.Colors.textPrimary)
                    Text("شحنة النواة")
                        .font(AiQoTheme.Typography.caption).foregroundStyle(AiQoTheme.Colors.textSecondary)
                }
            }
            .frame(width: 210, height: 210)

            HStack(spacing: AiQoSpacing.sm) {
                Circle().fill(statusColor).frame(width: 8, height: 8)
                Text(statusText).font(AiQoTheme.Typography.body).foregroundStyle(AiQoTheme.Colors.textPrimary)
                Text("· \(model.selectedCount) تطبيق محمي")
                    .font(AiQoTheme.Typography.caption).foregroundStyle(AiQoTheme.Colors.textSecondary)
            }
        }
        .padding(.top, AiQoSpacing.sm)
    }

    private var protectionControls: some View {
        VStack(alignment: .leading, spacing: AiQoSpacing.md) {
            Toggle(isOn: Binding(
                get: { model.isProtectionEnabled },
                set: { isOn in
                    // Re-enabling is frictionless; DISABLING always works but asks
                    // first — intentional friction so you don't break today's commitment
                    // by reflex. (Deleting AiQo or revoking Screen Time also releases
                    // every shield — that's an OS guarantee, nothing to enforce here.)
                    if isOn { model.setProtection(true) } else { showDisableConfirm = true }
                }
            )) {
                Text("تفعيل الحماية").font(AiQoTheme.Typography.cardTitle).foregroundStyle(AiQoTheme.Colors.textPrimary)
            }
            .tint(AiQoTheme.Colors.accent)
            .confirmationDialog("راح تكسر التزامك اليوم", isPresented: $showDisableConfirm, titleVisibility: .visible) {
                Button("أطفئ الحماية وفُكّ الدروع", role: .destructive) { model.setProtection(false) }
                Button("رجوع", role: .cancel) { }
            } message: {
                Text("الدروع كلها راح تنفك وتگدر تستخدم تطبيقاتك. متأكد؟")
            }

            Picker("الوضع", selection: Binding(get: { model.mode }, set: { model.setMode($0) })) {
                Text("ذكي").tag(KernelProtectionMode.smart)
                Text("صارم").tag(KernelProtectionMode.hard)
            }
            .pickerStyle(.segmented)

            if model.mode == .smart {
                Stepper(value: Binding(get: { model.usageThresholdMinutes }, set: { model.setThreshold($0) }), in: 1...120) {
                    Text("حد الاستخدام: \(model.usageThresholdMinutes) دقيقة")
                        .font(AiQoTheme.Typography.body).foregroundStyle(AiQoTheme.Colors.textPrimary)
                }
                Text("بالوضع الذكي: يحجب فقط لو وصلت العتبة وأنت جالس. تمشي وتستخدم — ما يحجب.")
                    .font(AiQoTheme.Typography.caption).foregroundStyle(AiQoTheme.Colors.textSecondary)
            }
        }
        .kernelCard()
    }

    private var editAppsButton: some View {
        Button {
            model.isPresentingPicker = true
        } label: {
            Label("تعديل التطبيقات المحجوبة", systemImage: "square.grid.2x2")
                .font(AiQoTheme.Typography.cta)
                .frame(maxWidth: .infinity).padding(.vertical, AiQoSpacing.md)
        }
        .background(AiQoTheme.Colors.accent, in: RoundedRectangle(cornerRadius: AiQoRadius.control, style: .continuous))
        .foregroundStyle(.white)
    }

    private var energyCard: some View {
        HStack {
            Image(systemName: "bolt.heart.fill").foregroundStyle(AiQoColors.sandSoft)
            Text("طاقة اليوم المكتسبة").font(AiQoTheme.Typography.body).foregroundStyle(AiQoTheme.Colors.textSecondary)
            Spacer()
            Text("\(model.todayEnergy)").font(AiQoTheme.Typography.sectionTitle).foregroundStyle(AiQoTheme.Colors.textPrimary)
        }
        .kernelCard()
    }

    private var sessionsCard: some View {
        HStack {
            Image(systemName: "hourglass").foregroundStyle(AiQoTheme.Colors.accent)
            if let minutes = model.activeSessionRemainingMinutes {
                Text("جلسة مفتوحة — تنتهي بعد \(minutes) دقيقة")
                    .font(AiQoTheme.Typography.body).foregroundStyle(AiQoTheme.Colors.textPrimary)
            } else {
                Text("ماكو جلسات مفتوحة")
                    .font(AiQoTheme.Typography.body).foregroundStyle(AiQoTheme.Colors.textSecondary)
            }
            Spacer()
        }
        .kernelCard()
    }

    private var footnote: some View {
        Text("الحجب والتحدّي يقودهم نشاطك الحقيقي من Health. تمشي تنفتح، أو تصرف طاقتك المكتسبة.")
            .font(AiQoTheme.Typography.caption).foregroundStyle(AiQoTheme.Colors.textSecondary)
            .multilineTextAlignment(.center)
    }

    // MARK: - Gate states

    private var authorizeCard: some View {
        VStack(spacing: AiQoSpacing.md) {
            Image(systemName: "bolt.shield").font(.system(size: 44)).foregroundStyle(AiQoTheme.Colors.accent)
            Text("النواة").font(AiQoTheme.Typography.screenTitle).foregroundStyle(AiQoTheme.Colors.textPrimary)
            Text("اختَر تطبيقاتك وافتحها بالحركة. نحتاج صلاحية Family Controls.")
                .font(AiQoTheme.Typography.body).foregroundStyle(AiQoTheme.Colors.textSecondary).multilineTextAlignment(.center)
            Button {
                showConsent = true
            } label: {
                Label("فعّل صلاحية الوصول", systemImage: "checkmark.shield")
                    .font(AiQoTheme.Typography.cta)
                    .frame(maxWidth: .infinity).padding(.vertical, AiQoSpacing.md)
            }
            .background(AiQoTheme.Colors.accent, in: RoundedRectangle(cornerRadius: AiQoRadius.control, style: .continuous))
            .foregroundStyle(.white)
        }
        .kernelCard()
    }

    private var gateLockedCard: some View {
        VStack(spacing: AiQoSpacing.md) {
            Image(systemName: "lock.fill").font(.system(size: 40)).foregroundStyle(AiQoColors.sandSoft)
            Text(model.gateState == .tierLocked ? "النواة ضمن AiQo Max" : "النواة غير مفعّلة")
                .font(AiQoTheme.Typography.sectionTitle).foregroundStyle(AiQoTheme.Colors.textPrimary)
            Text("اشترك بـ Max حتى تحجب تطبيقاتك وتفتحها بالحركة.")
                .font(AiQoTheme.Typography.body).foregroundStyle(AiQoTheme.Colors.textSecondary).multilineTextAlignment(.center)
        }
        .kernelCard()
    }

    private var statusText: String {
        if model.isLocked { return "تشحن الآن" }
        return model.isProtectionEnabled ? "محمية" : "مطفأة"
    }

    private var statusColor: Color {
        if model.isLocked { return AiQoColors.sandSoft }
        return model.isProtectionEnabled ? AiQoTheme.Colors.accent : AiQoTheme.Colors.textSecondary
    }
}

// MARK: - Local card helper (existing material + radius tokens; not a new token)

private extension View {
    func kernelCard() -> some View {
        self.padding(AiQoSpacing.lg)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AiQoRadius.card, style: .continuous))
    }
}
