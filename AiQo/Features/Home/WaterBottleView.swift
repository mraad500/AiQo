import SwiftUI

// MARK: - WaterBottleView

/// A visual water bottle that displays current water intake with animated fill level.
/// The liquid animates smoothly when the water level changes.
struct WaterBottleView: View {
    
    // MARK: - Properties
    
    /// Current water amount in liters
    let currentLiters: Double
    
    /// Maximum capacity for visual representation (default 3L = full bottle)
    var maxCapacity: Double = 3.0
    
    /// The color of the liquid
    var liquidColor: Color = Color(red: 0.24, green: 0.67, blue: 0.93).opacity(0.9)
    
    /// Name of the bottle image asset
    var bottleImageName: String = "WaterBottle"
    
    // MARK: - Private State
    
    /// Animated fill percentage
    @State private var animatedPercentage: Double = 0
    
    // MARK: - Computed Properties
    
    /// Calculate fill percentage (0.0 to 1.0), capped at 100%
    private var fillPercentage: Double {
        min(currentLiters / maxCapacity, 1.0)
    }
    
    // MARK: - Body
    
    var body: some View {
        GeometryReader { geometry in
            let totalHeight = geometry.size.height
            let totalWidth = geometry.size.width
            
            // Calculate liquid dimensions
            // Multiply by 0.90 so water doesn't cover the bottle cap
            let liquidHeight = totalHeight * animatedPercentage * 0.90
            let liquidWidth = totalWidth * 0.85
            
            ZStack(alignment: .bottom) {
                // Layer 1: Liquid (behind the bottle)
                LiquidShape(cornerRadius: 12)
                    .fill(liquidColor)
                    .frame(width: liquidWidth, height: liquidHeight)
                    .padding(.bottom, 5) // Offset from bottom edge
                
                // Layer 2: Bottle image (in front)
                Image(bottleImageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: totalWidth, height: totalHeight)
            }
            .frame(width: totalWidth, height: totalHeight)
        }
        .onAppear {
            // Animate to current level on appear
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0)) {
                animatedPercentage = fillPercentage
            }
        }
        .onChange(of: currentLiters) { _, _ in
            // Animate water level changes
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0)) {
                animatedPercentage = fillPercentage
            }
        }
    }
}

// MARK: - LiquidShape

/// Custom shape for the liquid with rounded bottom corners only
struct LiquidShape: Shape {
    var cornerRadius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let topLeft = CGPoint(x: rect.minX, y: rect.minY)
        let topRight = CGPoint(x: rect.maxX, y: rect.minY)
        
        // Start from top-left (no rounding)
        path.move(to: topLeft)
        
        // Top edge (straight)
        path.addLine(to: topRight)
        
        // Right edge down to bottom-right corner
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerRadius))
        
        // Bottom-right rounded corner
        path.addArc(
            center: CGPoint(x: rect.maxX - cornerRadius, y: rect.maxY - cornerRadius),
            radius: cornerRadius,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )
        
        // Bottom edge
        path.addLine(to: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY))
        
        // Bottom-left rounded corner
        path.addArc(
            center: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY - cornerRadius),
            radius: cornerRadius,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )
        
        // Left edge back to top
        path.addLine(to: topLeft)
        
        path.closeSubpath()
        return path
    }
}

// MARK: - Wave Effect (Optional Enhancement)

/// An optional wave animation overlay for a more dynamic water effect
struct WaveShape: Shape {
    var offset: Double
    var amplitude: CGFloat = 5
    var frequency: CGFloat = 2
    
    var animatableData: Double {
        get { offset }
        set { offset = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let midHeight = height * 0.5
        
        path.move(to: CGPoint(x: 0, y: midHeight))
        
        for x in stride(from: 0, through: width, by: 1) {
            let relativeX = x / width
            let sine = sin((relativeX * frequency * .pi * 2) + offset)
            let y = midHeight + amplitude * sine
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        path.addLine(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: 0, y: height))
        path.closeSubpath()
        
        return path
    }
}

/// Enhanced water bottle with wave animation
struct AnimatedWaterBottleView: View {
    let currentLiters: Double
    var maxCapacity: Double = 3.0
    var liquidColor: Color = Color(red: 0.24, green: 0.67, blue: 0.93)
    var bottleImageName: String = "WaterBottle"
    
    @State private var animatedPercentage: Double = 0
    @State private var waveOffset: Double = 0
    
    private var fillPercentage: Double {
        min(currentLiters / maxCapacity, 1.0)
    }
    
    var body: some View {
        GeometryReader { geometry in
            let totalHeight = geometry.size.height
            let totalWidth = geometry.size.width
            let liquidHeight = totalHeight * animatedPercentage * 0.90
            let liquidWidth = totalWidth * 0.85
            
            ZStack(alignment: .bottom) {
                // Liquid with wave effect
                ZStack {
                    // Base liquid
                    LiquidShape(cornerRadius: 12)
                        .fill(liquidColor.opacity(0.9))
                    
                    // Wave overlay (subtle)
                    if animatedPercentage > 0.05 {
                        WaveShape(offset: waveOffset, amplitude: 3, frequency: 1.5)
                            .fill(liquidColor.opacity(0.3))
                            .offset(y: -liquidHeight * 0.45)
                    }
                }
                .frame(width: liquidWidth, height: liquidHeight)
                .padding(.bottom, 5)
                
                // Bottle image
                Image(bottleImageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: totalWidth, height: totalHeight)
            }
            .frame(width: totalWidth, height: totalHeight)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                animatedPercentage = fillPercentage
            }
            // Start wave animation
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                waveOffset = .pi * 2
            }
        }
        .onChange(of: currentLiters) { _, _ in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                animatedPercentage = fillPercentage
            }
        }
    }
}

// MARK: - Preview

#Preview("Water Bottle - Empty") {
    WaterBottleView(currentLiters: 0)
        .frame(width: 140, height: 300)
        .padding()
}

#Preview("Water Bottle - Half Full") {
    WaterBottleView(currentLiters: 1.5)
        .frame(width: 140, height: 300)
        .padding()
}

#Preview("Water Bottle - Full") {
    WaterBottleView(currentLiters: 3.0)
        .frame(width: 140, height: 300)
        .padding()
}

#Preview("Animated Water Bottle") {
    AnimatedWaterBottleView(currentLiters: 2.0)
        .frame(width: 140, height: 300)
        .padding()
}

#Preview("Interactive Demo") {
    WaterBottleDemo()
}

/// Demo view to test water level changes
struct WaterBottleDemo: View {
    @State private var waterLevel: Double = 1.0
    
    var body: some View {
        VStack(spacing: 30) {
            Text(String(format: "%.1f L", waterLevel))
                .font(.system(size: 48, weight: .heavy, design: .rounded))
            
            WaterBottleView(currentLiters: waterLevel)
                .frame(width: 140, height: 300)
            
            HStack(spacing: 20) {
                Button("- 0.25L") {
                    waterLevel = max(0, waterLevel - 0.25)
                }
                .buttonStyle(.bordered)
                
                Button("+ 0.25L") {
                    waterLevel = min(3.0, waterLevel + 0.25)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}
