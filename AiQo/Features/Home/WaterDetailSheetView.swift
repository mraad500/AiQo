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
    
    /// Callback fired when water is added, passing the amount added (for HealthKit save)
    var onAddWater: ((Double) -> Void)?
    
    // MARK: - Environment
    
    /// Environment dismiss action for the close button
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Constants
    
    /// Water blue color matching the original UIKit implementation
    private let waterBlue = Color(red: 0.24, green: 0.67, blue: 0.93)
    
    /// Amount to add per button tap
    private let addAmount: Double = 0.25
    
    // MARK: - Body
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Background
            Color(.systemBackground)
                .ignoresSafeArea()
            
            // Close Button (top-right corner)
            closeButton
            
            // Main Content
            VStack(spacing: 0) {
                // Top spacing (matches original: 40pt from safe area)
                Spacer()
                    .frame(height: 40)
                
                // Title
                titleLabel
                
                // Amount Display
                amountLabel
                    .padding(.top, 10)
                
                // Water Bottle Visualization
                waterBottle
                    .padding(.top, 30)
                
                Spacer()
                
                // Add Water Button
                addWaterButton
                    .padding(.bottom, 40)
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - Subviews
    
    /// Close button positioned in top-right corner
    private var closeButton: some View {
        Button(action: { dismiss() }) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
                .symbolRenderingMode(.hierarchical)
        }
        .padding(.top, 16)
        .padding(.trailing, 20)
        .accessibilityLabel("Close")
    }
    
    /// "Water" title label
    private var titleLabel: some View {
        Text(NSLocalizedString("metric.water.title", comment: "Water title"))
            .font(.system(size: 24, weight: .bold, design: .rounded))
            .foregroundStyle(.primary)
    }
    
    /// Current water amount display (e.g., "2.5 L")
    private var amountLabel: some View {
        Text(String(format: "%.1f L", currentWaterLiters))
            .font(.system(size: 48, weight: .heavy, design: .rounded))
            .foregroundStyle(.primary)
            .contentTransition(.numericText())
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentWaterLiters)
    }
    
    /// Animated water bottle view
    private var waterBottle: some View {
        WaterBottleView(currentLiters: currentWaterLiters)
            .frame(width: 140, height: 300)
    }
    
    /// "+ 0.25 L" capsule button
    private var addWaterButton: some View {
        Button(action: addWater) {
            Text("+ 0.25 L")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 200, height: 55)
                .background(waterBlue)
                .clipShape(Capsule())
        }
        .buttonStyle(BounceButtonStyle())
        .accessibilityLabel("Add 0.25 liters of water")
        .accessibilityHint("Double tap to log water intake")
    }
    
    // MARK: - Actions
    
    /// Handles adding water when button is tapped
    private func addWater() {
        // Update the binding with animation
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            currentWaterLiters += addAmount
        }
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Notify parent to save to HealthKit
        onAddWater?(addAmount)
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
        onAddWater: ((Double) -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self._currentWaterLiters = .constant(initialWaterLiters)
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
        onAddWater: ((Double) -> Void)? = nil
    ) -> some View {
        self.sheet(isPresented: isPresented) {
            WaterDetailSheetView(
                currentWaterLiters: currentWaterLiters,
                onAddWater: onAddWater
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }
}
