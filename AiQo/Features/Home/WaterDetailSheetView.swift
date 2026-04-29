import SwiftUI

// MARK: - WaterDetailSheetView

/// SwiftUI replacement for `WaterDetailViewController`.
/// Displays current water intake with an animated bottle visualization
/// and allows adding water in 0.25L increments.
struct WaterDetailSheetView: View {
    
    // MARK: - Properties
    
    /// Two-way binding to the current water amount in liters.
    /// Updates automatically propagate to the parent view (HomeView).
    @Binding var currentWaterLiters: Double

    /// Daily hydration goal in liters, used by the hero ring and goal sublabel.
    /// Caller is the source of truth (typically `HydrationService.shared.settings.goalML / 1000`).
    var goalLiters: Double = 2.5

    /// Callback fired when water is added, passing the amount added (for HealthKit save)
    var onAddWater: ((Double) -> Void)?

    // MARK: - Environment

    /// Environment dismiss action for the close button
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    /// Drives the nested custom-amount sheet.
    @State private var showCustomSheet = false
    
    // MARK: - Body
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Background
            Color(.systemBackground)
                .ignoresSafeArea()

            // Main Content
            ScrollView {
                VStack(spacing: 0) {
                    // Top spacing (matches original: 40pt from safe area)
                    Spacer()
                        .frame(height: 40)

                    // Title
                    titleLabel

                    // Hero ring — replaces the photographic bottle illustration.
                    // Pure SwiftUI, on-brand mint/sand accents.
                    WaterHeroRingView(
                        consumedLiters: currentWaterLiters,
                        goalLiters: goalLiters
                    )
                    .padding(.top, 18)

                    // Percentage pill (below ring)
                    percentagePill
                        .padding(.top, 12)

                    // Quick-add chip row — replaces the single blue "+0.25 L" pill.
                    quickAddRow
                        .padding(.top, 24)

                    // Smart Hydration — free feature, flag-gated for rollout safety
                    if FeatureFlags.smartWaterTrackingEnabled {
                        SmartHydrationSection(service: HydrationService.shared)
                            .padding(.top, 24)
                            .padding(.bottom, 20)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)

            // Close Button (top-right corner) — kept on top of ScrollView
            closeButton
        }
        .sheet(isPresented: $showCustomSheet) {
            CustomWaterAmountSheet { amount in
                performAdd(amount: amount, isCustom: true)
            }
        }
    }
    
    // MARK: - Subviews
    
    /// Close button positioned in top-right corner. Material-backed circle
    /// keeps the glyph above the 3:1 WCAG AA floor against the sheet's
    /// system-background surface.
    private var closeButton: some View {
        Button(action: { dismiss() }) {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.primary.opacity(0.6))
                .frame(width: 36, height: 36)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(
                    Circle().stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
        .padding(.top, 16)
        .padding(.trailing, 20)
        .accessibilityLabel(NSLocalizedString("water.close", comment: ""))
    }
    
    /// "Water" title label — SF Rounded, bold, centered
    private var titleLabel: some View {
        Text(NSLocalizedString("metric.water.title", comment: "Water title"))
            .font(.system(size: 17, weight: .bold, design: .rounded))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
    }

    /// Compact percentage pill on `.ultraThinMaterial` — sits ~12pt under the ring.
    private var percentagePill: some View {
        let progress = goalLiters > 0 ? min(1, currentWaterLiters / goalLiters) : 0
        let percent = Int((progress * 100).rounded())
        return Text("\(percent)%")
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule(style: .continuous))
            .overlay(
                Capsule(style: .continuous)
                    .stroke(AiQoColors.mintSoft.opacity(0.35), lineWidth: 0.5)
            )
            .contentTransition(.numericText(value: Double(percent)))
            .animation(.spring(response: 0.55, dampingFraction: 0.85), value: percent)
    }

    /// Three chips: +0.25, +0.5, custom. Replaces the single blue capsule.
    private var quickAddRow: some View {
        HStack(spacing: 10) {
            quickAddChip(
                title: NSLocalizedString("water.add.quarter", comment: ""),
                amount: 0.25,
                a11yAmount: "0.25"
            )
            quickAddChip(
                title: NSLocalizedString("water.add.half", comment: ""),
                amount: 0.5,
                a11yAmount: "0.5"
            )
            customChip
        }
        .padding(.horizontal, 20)
    }

    private func quickAddChip(title: String, amount: Double, a11yAmount: String) -> some View {
        Button {
            performAdd(amount: amount, isCustom: false)
        } label: {
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(minWidth: 44, minHeight: 44)
                .background(.ultraThinMaterial, in: Capsule(style: .continuous))
                .overlay(
                    Capsule(style: .continuous)
                        .fill(AiQoColors.mintSoft.opacity(0.35))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(AiQoColors.mintSoft.opacity(0.6), lineWidth: 0.5)
                )
        }
        .buttonStyle(BounceButtonStyle())
        .accessibilityLabel(String(
            format: NSLocalizedString("water.add.a11y.format", comment: ""),
            a11yAmount
        ))
        .accessibilityHint(NSLocalizedString("water.add.a11y.hint", comment: ""))
    }

    private var customChip: some View {
        Button {
            showCustomSheet = true
        } label: {
            Text(NSLocalizedString("water.add.custom", comment: ""))
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(minWidth: 44, minHeight: 44)
                .background(.ultraThinMaterial, in: Capsule(style: .continuous))
                .overlay(
                    Capsule(style: .continuous)
                        .fill(AiQoColors.sandSoft.opacity(0.35))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(AiQoColors.sandSoft.opacity(0.6), lineWidth: 0.5)
                )
        }
        .buttonStyle(BounceButtonStyle())
        .accessibilityLabel(NSLocalizedString("water.add.custom", comment: ""))
        .accessibilityHint(NSLocalizedString("water.add.a11y.hint", comment: ""))
    }

    // MARK: - Actions

    /// Single entry point for all add actions. Preserves the existing
    /// `onAddWater` callback path (HomeView wraps it in
    /// `Task { await viewModel.addWater(liters:) }`) so HealthKit, reminders,
    /// and widget updates all flow through the same pipe.
    private func performAdd(amount: Double, isCustom: Bool) {
        withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
            currentWaterLiters += amount
        }

        if isCustom {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }

        onAddWater?(amount)
    }
}

// MARK: - Custom Amount Sheet

/// Minimal sheet for the "custom dose" chip. Kept private to this file so the
/// parent sheet's state (`showCustomSheet`) stays in one place.
private struct CustomWaterAmountSheet: View {
    let onConfirm: (Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var amount: Double = 0.25

    var body: some View {
        VStack(spacing: 20) {
            Text(NSLocalizedString("water.custom.sheet.title", comment: ""))
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .padding(.top, 20)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(amount, format: .number.precision(.fractionLength(2)))
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText(value: amount))
                Text(unitLabel)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Slider(value: $amount, in: 0.05...1.0, step: 0.05)
                .tint(AiQoColors.mintSoft)
                .padding(.horizontal, 24)

            Button {
                onConfirm(amount)
                dismiss()
            } label: {
                Text(NSLocalizedString("water.custom.confirm", comment: ""))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(.ultraThinMaterial, in: Capsule(style: .continuous))
                    .overlay(
                        Capsule(style: .continuous)
                            .fill(AiQoColors.mintSoft.opacity(0.45))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(AiQoColors.mintSoft.opacity(0.7), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)

            Spacer(minLength: 0)
        }
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.visible)
        .presentationBackground(.ultraThinMaterial)
    }

    private var unitLabel: String {
        Locale.current.language.languageCode?.identifier == "ar" ? "ل" : "L"
    }
}

// MARK: - Bounce Button Style

/// Custom button style with subtle bounce animation on press
private struct BounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Alternative Initializer (Non-Binding)

extension WaterDetailSheetView {
    /// Convenience initializer when you don't need two-way binding
    /// (uses internal state instead, useful for previews or standalone usage)
    init(
        initialWaterLiters: Double,
        goalLiters: Double = 2.5,
        onAddWater: ((Double) -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self._currentWaterLiters = .constant(initialWaterLiters)
        self.goalLiters = goalLiters
        self.onAddWater = onAddWater
    }
}

// MARK: - Preview Provider

#Preview("Water Detail - Empty") {
    WaterDetailSheetView(
        currentWaterLiters: .constant(0.0)
    )
}

#Preview("Water Detail - Half Full") {
    WaterDetailSheetView(
        currentWaterLiters: .constant(1.5)
    )
}

#Preview("Water Detail - Nearly Full") {
    WaterDetailSheetView(
        currentWaterLiters: .constant(2.75)
    )
}

#Preview("Water Detail - Interactive") {
    WaterDetailInteractivePreview()
}

/// Interactive preview for testing the add functionality
private struct WaterDetailInteractivePreview: View {
    @State private var waterAmount: Double = 1.0
    
    var body: some View {
        WaterDetailSheetView(
            currentWaterLiters: $waterAmount,
            onAddWater: { added in
                print("Added \(added)L - Total: \(waterAmount)L")
            }
        )
    }
}

// MARK: - Sheet Presentation Helper

extension View {
    /// Present WaterDetailSheetView as a sheet
    func waterDetailSheet(
        isPresented: Binding<Bool>,
        currentWaterLiters: Binding<Double>,
        goalLiters: Double = 2.5,
        onAddWater: ((Double) -> Void)? = nil
    ) -> some View {
        self.sheet(isPresented: isPresented) {
            WaterDetailSheetView(
                currentWaterLiters: currentWaterLiters,
                goalLiters: goalLiters,
                onAddWater: onAddWater
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }
}
