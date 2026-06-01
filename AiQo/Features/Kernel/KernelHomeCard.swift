import SwiftUI

/// Home shortcut for «النواة» — sits in the Kitchen's former Home slot, matching
/// that icon-button style but with the `KernelIcon` asset (rendered Original, i.e.
/// colored). Tapping opens the full hub (`KernelView`) for Max+, or the paywall
/// (`PaywallSource.kernelGate`) for free users. This is the single Kernel entry
/// point in Home.
struct KernelHomeCard: View {
    @State private var showKernel = false
    @State private var showPaywall = false
    @State private var isPressed = false
    @State private var floatOffset: CGFloat = 0
    @State private var feedbackTrigger = 0

    private var hasAccess: Bool { TierGate.shared.canAccess(.kernel) }
    private var isAr: Bool { AppSettingsStore.shared.appLanguage == .arabic }

    var body: some View {
        Button {
            feedbackTrigger += 1
            withAnimation(.snappy(duration: 0.30, extraBounce: 0.08)) { isPressed = true }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(150))
                withAnimation(.snappy(duration: 0.30, extraBounce: 0.08)) { isPressed = false }
            }
            if hasAccess { showKernel = true } else { showPaywall = true }
        } label: {
            // Animated atom (electrons orbit slowly) — Daily Aura colors/weight.
            // iOS can't animate the asset SVG/PNG, so this is drawn in SwiftUI.
            KernelAtomIcon(size: 112)
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
        .sheet(isPresented: $showPaywall) { PaywallView(source: .kernelGate) }
        .accessibilityLabel(isAr ? "افتح النواة" : "Open Kernel")
        .onAppear {
            guard !AiQoAccessibility.prefersReducedMotion else { return }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                floatOffset = -4
            }
        }
    }
}
