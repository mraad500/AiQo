import SwiftUI

/// Home shortcut for «النواة» — sits in the Kitchen's former Home slot, matching
/// that icon-button style but with the `KernelIcon` asset (rendered Original, i.e.
/// colored). Tapping opens the full hub (`KernelView`) for every tier — free users
/// get one protected app + an in-hub upgrade card, paid tiers are unlimited. This
/// is the single Kernel entry point in Home.
struct KernelHomeCard: View {
    @State private var showKernel = false
    @State private var isPressed = false
    @State private var floatOffset: CGFloat = 0
    @State private var feedbackTrigger = 0

    private var isAr: Bool { AppSettingsStore.shared.appLanguage == .arabic }

    var body: some View {
        Button {
            feedbackTrigger += 1
            withAnimation(.snappy(duration: 0.30, extraBounce: 0.08)) { isPressed = true }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(150))
                withAnimation(.snappy(duration: 0.30, extraBounce: 0.08)) { isPressed = false }
            }
            showKernel = true
        } label: {
            // Animated atom (electrons orbit slowly) — Daily Aura colors/weight.
            // iOS can't animate the asset SVG/PNG, so this is drawn in SwiftUI.
            // Named so it reads as a feature, not the brand watermark — it's the
            // only tappable element in Home that would otherwise sit nameless.
            VStack(spacing: 6) {
                KernelAtomIcon(size: 112)
                Text(isAr ? "النواة" : "Kernel")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
            }
            .offset(y: floatOffset)
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.9 : 1.0)
        .sensoryFeedback(.selection, trigger: feedbackTrigger)
        // Half-height frosted sheet; drag up to expand to full.
        .sheet(isPresented: $showKernel) {
            KernelView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
                .presentationCornerRadius(28)
        }
        .accessibilityLabel(isAr ? "افتح النواة" : "Open Kernel")
        .onAppear {
            guard !AiQoAccessibility.prefersReducedMotion else { return }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                floatOffset = -4
            }
        }
    }
}
