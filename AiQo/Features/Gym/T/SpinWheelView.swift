//
//  SpinWheelView.swift
//  AiQo - Gamified Workout Experience
//
//  Phase 2: Enhanced Wheel with Video Segments
//

import SwiftUI

struct SpinWheelView: View {
    @ObservedObject var viewModel: WorkoutSessionViewModel
    
    // Animation states
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.5
    
    // Wheel size based on state
    private var wheelSize: CGFloat {
        // ✅ تصحيح: استخدام القيمة مباشرة بدون $
        switch viewModel.wheelState {
        case .idle:
            return 100
        case .expanded, .spinning:
            return 260
        case .resultShown:
            return 0
        }
    }
    
    var body: some View {
        ZStack {
            // Pulsing background glow (when expanded)
            // ✅ تصحيح: استخدام القيمة مباشرة بدون $
            if viewModel.wheelState == .expanded {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 1.0, green: 0.85, blue: 0.35).opacity(glowOpacity),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 50,
                            endRadius: 150
                        )
                    )
                    .frame(width: wheelSize + 60, height: wheelSize + 60)
                    .scaleEffect(pulseScale)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                            pulseScale = 1.1
                            glowOpacity = 0.8
                        }
                    }
            }
            
            // Main Wheel
            ZStack {
                // Wheel segments (showing workout categories)
                // ✅ تصحيح: استخدام القيمة مباشرة بدون $
                if viewModel.wheelState != .idle {
                    WheelSegmentsView(videos: viewModel.workoutVideos)
                        .frame(width: wheelSize - 20, height: wheelSize - 20)
                        .rotationEffect(.degrees(viewModel.rotationAngle))
                        .transition(.scale.combined(with: .opacity))
                }
                
                // صورة العجلة الرئيسية
                Image("wheel")
                    .resizable()
                    .scaledToFit()
                    .rotationEffect(.degrees(viewModel.rotationAngle))
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                
                // Outer ring decoration
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 0.72, green: 0.91, blue: 0.83),
                                Color(red: 1.00, green: 0.85, blue: 0.35),
                                Color(red: 1.00, green: 0.65, blue: 0.20),
                                Color(red: 0.72, green: 0.91, blue: 0.83)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        // ✅ تصحيح: استخدام القيمة مباشرة بدون $
                        lineWidth: viewModel.wheelState == .idle ? 2 : 4
                    )
                    .frame(width: wheelSize + 4, height: wheelSize + 4)
            }
            .frame(width: wheelSize, height: wheelSize)
            
            // صورة الدبوس (Pointer) - يظهر فقط عند التكبير
            // ✅ تصحيح: استخدام القيمة مباشرة بدون $
            if viewModel.wheelState != .idle {
                VStack {
                    Image("Dambus")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 50)
                        .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)
                    
                    Spacer()
                }
                .frame(height: wheelSize + 40)
                .transition(.scale.combined(with: .opacity))
            }
            
            // Center button
            centerButton
        }
        .frame(width: wheelSize + 60, height: wheelSize + 60)
        .contentShape(Circle())
        .onTapGesture {
            viewModel.handleWheelTap()
        }
        // ✅ تصحيح: الأنيميشن يراقب القيمة (بدون $)
        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: viewModel.wheelState)
    }
    
    // MARK: - Center Button
    @ViewBuilder
    private var centerButton: some View {
        // ✅ تصحيح: استخدام القيمة مباشرة بدون $ في كل الشروط
        if viewModel.wheelState == .expanded {
            // SPIN button
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white,
                            Color(red: 0.95, green: 0.95, blue: 0.95)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 60, height: 60)
                .overlay(
                    Text("SPIN")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(.black)
                )
                .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
                .transition(.scale)
        } else if viewModel.wheelState == .spinning {
            // Spinning indicator
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 60, height: 60)
                .overlay(
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                )
        } else if viewModel.wheelState == .idle {
            // Tap indicator
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.72, green: 0.91, blue: 0.83),
                            Color(red: 0.60, green: 0.85, blue: 0.75)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                )
                .shadow(color: Color(red: 0.72, green: 0.91, blue: 0.83).opacity(0.5), radius: 8, x: 0, y: 4)
        }
    }
}

// MARK: - Wheel Segments View
// هذا الجزء كان ناقص وهو اللي سبب مشكلة "Cannot find WheelSegmentsView"
struct WheelSegmentsView: View {
    let videos: [WorkoutVideo]
    
    // Segment colors
    private let segmentColors: [Color] = [
        Color(red: 1.00, green: 0.40, blue: 0.55),  // Pink
        Color(red: 1.00, green: 0.85, blue: 0.35),  // Gold
        Color(red: 0.00, green: 0.75, blue: 0.65),  // Teal
        Color(red: 0.55, green: 0.45, blue: 0.95),  // Purple
        Color(red: 1.00, green: 0.65, blue: 0.20),  // Orange
        Color(red: 0.72, green: 0.91, blue: 0.83)   // Mint
    ]
    
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: size / 2, y: size / 2)
            let radius = size / 2
            let segmentAngle = 360.0 / Double(videos.count)
            
            ZStack {
                // Draw each segment
                ForEach(Array(videos.enumerated()), id: \.element.id) { index, video in
                    WheelSegment(
                        center: center,
                        radius: radius,
                        startAngle: Double(index) * segmentAngle - 90, // Start from top
                        endAngle: Double(index + 1) * segmentAngle - 90,
                        color: segmentColors[index % segmentColors.count],
                        text: video.category,
                        icon: iconForCategory(video.category)
                    )
                }
            }
        }
    }
    
    private func iconForCategory(_ category: String) -> String {
        switch category.lowercased() {
        case "hiit": return "flame.fill"
        case "yoga": return "figure.mind.and.body"
        case "core": return "figure.core.training"
        case "stretching": return "figure.flexibility"
        case "cardio": return "heart.fill"
        case "strength": return "dumbbell.fill"
        default: return "figure.run"
        }
    }
}

// MARK: - Individual Wheel Segment
struct WheelSegment: View {
    let center: CGPoint
    let radius: CGFloat
    let startAngle: Double
    let endAngle: Double
    let color: Color
    let text: String
    let icon: String
    
    var body: some View {
        ZStack {
            // Segment shape
            Path { path in
                path.move(to: center)
                path.addArc(
                    center: center,
                    radius: radius,
                    startAngle: .degrees(startAngle),
                    endAngle: .degrees(endAngle),
                    clockwise: false
                )
                path.closeSubpath()
            }
            .fill(color.opacity(0.8))
            .overlay(
                Path { path in
                    path.move(to: center)
                    path.addArc(
                        center: center,
                        radius: radius,
                        startAngle: .degrees(startAngle),
                        endAngle: .degrees(endAngle),
                        clockwise: false
                    )
                    path.closeSubpath()
                }
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            
            // Icon positioned in segment
            let midAngle = (startAngle + endAngle) / 2
            let iconRadius = radius * 0.65
            let iconX = center.x + iconRadius * cos(midAngle * .pi / 180)
            let iconY = center.y + iconRadius * sin(midAngle * .pi / 180)
            
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .position(x: iconX, y: iconY)
                .rotationEffect(.degrees(midAngle + 90))
        }
    }
}
