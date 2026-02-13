import SwiftUI

// =========================
// File: Features/Gym/RewardsView.swift
// SwiftUI - Rewards Screen with Glass Cards
// =========================

// MARK: - Data Model
struct RewardItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    let progress: Double
    let isLocked: Bool
}

// MARK: - Rewards View
struct RewardsView: View {
    // Sample Data
    private let items: [RewardItem] = [
        RewardItem(
            title: "7-Day Streak",
            subtitle: "Train 7 days total",
            icon: "flame.fill",
            tint: Color(red: 1.00, green: 0.78, blue: 0.22),
            progress: 0.35,
            isLocked: true
        ),
        RewardItem(
            title: "Heart Hero",
            subtitle: "Hit target BPM 3 times",
            icon: "heart.fill",
            tint: Color(red: 1.00, green: 0.40, blue: 0.55),
            progress: 0.62,
            isLocked: true
        ),
        RewardItem(
            title: "Step Master",
            subtitle: "10k steps in one day",
            icon: "figure.walk",
            tint: Color(red: 0.35, green: 0.85, blue: 0.65),
            progress: 0.88,
            isLocked: false
        ),
        RewardItem(
            title: "Gratitude Mode",
            subtitle: "Log gratitude 5 times",
            icon: "sparkles",
            tint: Color(red: 0.70, green: 0.60, blue: 0.95),
            progress: 0.20,
            isLocked: true
        )
    ]
    
    // Grid layout
    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                headerSection
                
                // Cards Grid
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(items) { item in
                        RewardCardView(item: item)
                    }
                }
                
                // Featured Card
                FeaturedRewardCard(
                    title: "Weekly Chest",
                    subtitle: "Complete 3 workouts this week",
                    icon: "gift.fill",
                    tint: GymTheme.mint,
                    progress: 0.55
                )
                .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Rewards")
                .font(.system(size: 28, weight: .heavy))
                .foregroundColor(.primary)
            
            Text("Unlock rewards by staying consistent ✨")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding(.top, 18)
        .padding(.horizontal, 4)
    }
}

// MARK: - Reward Card View (Glass Style)
struct RewardCardView: View {
    let item: RewardItem
    @State private var isPressed = false
    
    var body: some View {
        ZStack {
            // Glass Background
            GlassCardBackground(
                tint: item.isLocked ? item.tint.opacity(0.55) : item.tint.opacity(0.80)
            )
            
            // Content
            VStack(alignment: .leading, spacing: 0) {
                // Top Row: Icon + Lock
                HStack {
                    // Icon Background
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(item.tint.opacity(0.20))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: item.icon)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(item.tint)
                    }
                    
                    Spacer()
                    
                    // Lock/Check Icon
                    Image(systemName: item.isLocked ? "lock.fill" : "checkmark.seal.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(item.isLocked ? .secondary : item.tint)
                }
                .padding(.top, 14)
                .padding(.horizontal, 14)
                
                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    Text(item.subtitle)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                .padding(.top, 10)
                .padding(.horizontal, 14)
                
                Spacer()
                
                // Progress Bar
                RewardProgressBar(progress: item.progress, tint: item.tint)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
            }
        }
        .frame(height: 148)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isPressed)
        .onTapGesture {
            withAnimation {
                isPressed = true
            }
            
            let impact = UIImpactFeedbackGenerator(style: .soft)
            impact.impactOccurred()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation {
                    isPressed = false
                }
            }
        }
    }
}

// MARK: - Featured Reward Card
struct FeaturedRewardCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    let progress: Double
    
    @State private var isPressed = false
    
    var body: some View {
        ZStack {
            // Glass Background
            GlassCardBackground(tint: tint.opacity(0.85))
            
            // Content
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(tint)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundColor(.primary)
                        
                        Text(subtitle)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                }
                .padding(.top, 16)
                .padding(.horizontal, 16)
                
                Spacer()
                
                RewardProgressBar(progress: progress, tint: tint)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
        }
        .frame(height: 130)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isPressed)
        .onTapGesture {
            withAnimation {
                isPressed = true
            }
            
            let impact = UIImpactFeedbackGenerator(style: .soft)
            impact.impactOccurred()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation {
                    isPressed = false
                }
            }
        }
    }
}

// MARK: - Glass Card Background
struct GlassCardBackground: View {
    let tint: Color
    
    var body: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(tint)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 6)
    }
}

// MARK: - Reward Progress Bar
struct RewardProgressBar: View {
    let progress: Double
    let tint: Color
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.primary.opacity(0.10))
                
                // Fill
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(tint.opacity(0.85))
                    .frame(width: geometry.size.width * min(max(progress, 0), 1))
                    .animation(.easeOut(duration: 0.25), value: progress)
            }
        }
        .frame(height: 10)
    }
}

// MARK: - Preview
#Preview {
    RewardsView()
}
