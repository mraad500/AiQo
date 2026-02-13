import SwiftUI
import HealthKit

// MARK: - Premium Glassmorphism StartView

struct StartView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    @State private var appearAnimation = false
    
    struct WatchExercise: Identifiable {
        let id = UUID()
        let title: String
        let icon: String
        let primaryColor: Color
        let secondaryColor: Color
        let type: HKWorkoutActivityType
        let location: HKWorkoutSessionLocationType
    }
    
    let exercises: [WatchExercise] = [
        WatchExercise(
            title: "Gratitude",
            icon: "sparkles",
            primaryColor: Color(red: 0.85, green: 0.75, blue: 0.60),
            secondaryColor: Color(red: 0.95, green: 0.85, blue: 0.70),
            type: .mindAndBody,
            location: .indoor
        ),
        WatchExercise(
            title: "Walk Inside",
            icon: "figure.walk",
            primaryColor: Color(red: 0.60, green: 0.80, blue: 0.70),
            secondaryColor: Color(red: 0.70, green: 0.90, blue: 0.80),
            type: .walking,
            location: .indoor
        ),
        WatchExercise(
            title: "Walk Outside",
            icon: "figure.walk",
            primaryColor: Color(red: 0.95, green: 0.85, blue: 0.65),
            secondaryColor: Color(red: 1.0, green: 0.92, blue: 0.75),
            type: .walking,
            location: .outdoor
        ),
        WatchExercise(
            title: "Run Indoor",
            icon: "figure.run",
            primaryColor: Color(red: 0.70, green: 0.90, blue: 0.80),
            secondaryColor: Color(red: 0.80, green: 0.95, blue: 0.88),
            type: .running,
            location: .indoor
        ),
        WatchExercise(
            title: "Run Outside",
            icon: "figure.run",
            primaryColor: Color(red: 0.95, green: 0.85, blue: 0.65),
            secondaryColor: Color(red: 1.0, green: 0.92, blue: 0.75),
            type: .running,
            location: .outdoor
        )
    ]

    // MARK: - Alternating Theme Colors (Exact Hex Match)
    
    // Match iPhone Gym card colors exactly
    // iPhone beige: Color.aiqoBeige = (0.98, 0.87, 0.70)
    static let beigeTheme = (
        primary: Color(red: 0.98, green: 0.87, blue: 0.70),
        secondary: Color(red: 0.98, green: 0.87, blue: 0.70)
    )
    
    // iPhone mint: Color.aiqoMint = (0.77, 0.94, 0.86)
    static let mintTheme = (
        primary: Color(red: 0.77, green: 0.94, blue: 0.86),
        secondary: Color(red: 0.77, green: 0.94, blue: 0.86)
    )
    
    var body: some View {
        ZStack {
            // MARK: - Ambient Background
            AmbientBackground()
            
            // MARK: - Scrollable Cards
            ScrollView {
                VStack(spacing: 12) {
                    // Header - comfortably below clock, not too low
                    Text("AiQo Gym")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .padding(.top, 36) // Reduced padding - balanced position
                        .padding(.bottom, 8)
                    
                    // Exercise Cards with alternating colors
                    ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                        // Determine theme based on index (even = beige, odd = mint)
                        let isEvenIndex = index % 2 == 0
                        let themeColors = isEvenIndex ? Self.beigeTheme : Self.mintTheme
                        
                        GlassCard(
                            exercise: exercise,
                            themePrimary: themeColors.primary,
                            themeSecondary: themeColors.secondary
                        ) {
                            workoutManager.startWorkout(
                                workoutType: exercise.type,
                                locationType: exercise.location
                            )
                        }
                        .opacity(appearAnimation ? 1 : 0)
                        .offset(y: appearAnimation ? 0 : 20)
                        .animation(
                            .spring(response: 0.6, dampingFraction: 0.8)
                            .delay(Double(index) * 0.1),
                            value: appearAnimation
                        )
                    }
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 16)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            workoutManager.requestAuthorization()
            withAnimation {
                appearAnimation = true
            }
        }
    }
}

// MARK: - Ambient Background

struct AmbientBackground: View {
    var body: some View {
        ZStack {
            // Base dark gradient
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.08, blue: 0.12),
                    Color(red: 0.04, green: 0.04, blue: 0.08),
                    Color(red: 0.02, green: 0.02, blue: 0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Subtle ambient orbs for glass effect enhancement
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.85, green: 0.75, blue: 0.60).opacity(0.15),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 80
                    )
                )
                .frame(width: 160, height: 160)
                .offset(x: -60, y: -80)
                .blur(radius: 20)
            
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.60, green: 0.80, blue: 0.70).opacity(0.12),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 70
                    )
                )
                .frame(width: 140, height: 140)
                .offset(x: 50, y: 100)
                .blur(radius: 25)
        }
    }
}

// MARK: - Glass Card Component

struct GlassCard: View {
    let exercise: StartView.WatchExercise
    let themePrimary: Color
    let themeSecondary: Color
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            // Haptic feedback
            WKInterfaceDevice.current().play(.click)
            action()
        }) {
            HStack(spacing: 12) {
                // Icon with gradient background (uses theme colors)
                GlassIcon(
                    icon: exercise.icon,
                    primaryColor: themePrimary,
                    secondaryColor: themeSecondary
                )
                
                // Title - never truncated, dark text for contrast
                Text(exercise.title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.18))
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)
                    .fixedSize(horizontal: false, vertical: true)
                
                Spacer()
                
                // Chevron indicator - dark for visibility
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.18).opacity(0.5))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(
                GlassMaterial(
                    primaryColor: themePrimary,
                    secondaryColor: themeSecondary
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                // Shine border effect
                GlassBorder()
            )
        }
        .buttonStyle(GlassButtonStyle())
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        .shadow(color: themePrimary.opacity(0.3), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Glass Material Background

struct GlassMaterial: View {
    let primaryColor: Color
    let secondaryColor: Color
    
    var body: some View {
        ZStack {
            // Dominant color base - high opacity for clear Beige/Green visibility
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            primaryColor,
                            secondaryColor
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .opacity(0.88)
            
            // Subtle glass blur overlay
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(0.15)
            
            // Top highlight for glass shine effect
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.5),
                            Color.white.opacity(0.2),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
            
            // Corner glow
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.25),
                            Color.clear
                        ],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 60
                    )
                )
        }
    }
}

// MARK: - Glass Border (Shine Effect)

struct GlassBorder: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.4),
                        Color.white.opacity(0.15),
                        Color.white.opacity(0.05),
                        Color.white.opacity(0.1),
                        Color.white.opacity(0.25)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }
}

// MARK: - Glass Icon Component

struct GlassIcon: View {
    let icon: String
    let primaryColor: Color
    let secondaryColor: Color
    
    // Darker versions of theme colors for icon background
    var darkerPrimary: Color {
        Color(
            red: primaryColor.components.red * 0.85,
            green: primaryColor.components.green * 0.85,
            blue: primaryColor.components.blue * 0.85
        )
    }
    
    var body: some View {
        ZStack {
            // Icon background - slightly darker than card
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            darkerPrimary.opacity(0.9),
                            primaryColor.opacity(0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 36, height: 36)
            
            // Subtle inner highlight
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.5),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
                .frame(width: 36, height: 36)
            
            // Icon - dark color for contrast
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.18))
        }
        .shadow(color: primaryColor.opacity(0.5), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Color Extension for Component Access

extension Color {
    var components: (red: Double, green: Double, blue: Double, opacity: Double) {
        #if canImport(UIKit)
        typealias NativeColor = UIColor
        #elseif canImport(AppKit)
        typealias NativeColor = NSColor
        #endif
        
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var o: CGFloat = 0
        
        NativeColor(self).getRed(&r, green: &g, blue: &b, alpha: &o)
        
        return (Double(r), Double(g), Double(b), Double(o))
    }
}

// MARK: - Glass Button Style (Press Animation)

struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Preview

struct StartView_Previews: PreviewProvider {
    static var previews: some View {
        StartView()
            .environmentObject(WorkoutManager.shared)
    }
}
