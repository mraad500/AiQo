import SwiftUI

struct KitchenScreen: View {
    
    // MARK: - Properties
    @State private var selectedMeal: Meal?
    @State private var isProfileSheetPresented = false
    @State private var isRegenerating: Bool = false
    @State private var regenerateFeedbackTrigger = 0
    @State private var analyzeFeedbackTrigger = 0
    
    // NEW: فتح شاشة KitchenHamoudi
    @State private var isKitchenHamoudiPresented: Bool = false
    
    let viewModel: KitchenViewModel
    let onEditDietTapped: () -> Void

    // MARK: - Body
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            
            VStack(spacing: 0) {
                
                header
                    .padding(.top, -28)
                    .padding(.bottom, 16)
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .trailing, spacing: 24) {
                        
                        // تم التعديل هنا لاستخدام الكروت المتحركة 👇
                        mealSection(titleKey: "screen.kitchen.breakfast", type: .breakfast)
                        mealSection(titleKey: "screen.kitchen.lunch", type: .lunch)
                        mealSection(titleKey: "screen.kitchen.dinner", type: .dinner)
                        
                        buttonsSection
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
            .padding(.top, 0)
        }
        .task {
            await viewModel.loadMeals()
        }

        .sheet(isPresented: $isProfileSheetPresented) {
            NavigationStack {
                ProfileScreen()
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        
        // Meal details sheet
        .sheet(item: $selectedMeal) { meal in
            if #available(iOS 17.0, *) {
                MealDetailSheet(meal: meal)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(.ultraThinMaterial)
            } else {
                MealDetailSheet(meal: meal)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        
        // NEW: KitchenHamoudi sheet
        .sheet(isPresented: $isKitchenHamoudiPresented) {
            KitchenHamoudi()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.thinMaterial)
        }
    }
}

// MARK: - Header & Components
private extension KitchenScreen {
    
    var header: some View {
        HStack(alignment: .center) {
            
            VStack(alignment: .leading, spacing: 6) {
                Text("screen.kitchen.title".localized)
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundColor(.primary)
                
                HStack(spacing: 6) {
                    Text(formattedDate())
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                    
                    Image(systemName: "calendar")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            FloatingProfileButton(size: 48) {
                openProfile()
            }
        }
        .frame(height: 60)
        .padding(.horizontal, 24)
    }
    
    func mealSection(titleKey: String, type: MealType) -> some View {
        VStack(alignment: .trailing, spacing: 12) {
            Text(titleKey.localized)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            if let meal = viewModel.displayedMeal(for: type) {
                // 🔥 هنا السحر: استبدلنا الزر العادي بالزر المتحرك الجديد
                AnimatedMealButton(meal: meal) {
                    selectedMeal = meal
                }
            } else {
                Text("screen.kitchen.noMeals".localized)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }
    
    var buttonsSection: some View {
        VStack(spacing: 16) {
            
            // Regenerate with AI -> opens KitchenHamoudi
            Button {
                regenerateFeedbackTrigger += 1
                isKitchenHamoudiPresented = true
            } label: {
                Text("screen.kitchen.regenerate".localized)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color(.systemGray6))
                    )
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.selection, trigger: regenerateFeedbackTrigger)
            
            Button {
                analyzeFeedbackTrigger += 1
                onEditDietTapped()
            } label: {
                Text("screen.kitchen.analyze".localized)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color(red: 0.99, green: 0.90, blue: 0.60))
                    )
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.selection, trigger: analyzeFeedbackTrigger)
        }
        .padding(.top, 8)
    }
    
    func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = "d/M"
        return formatter.string(from: Date())
    }
    
    func openProfile() {
        isProfileSheetPresented = true
    }
}

// MARK: - Meal Detail Sheet
struct MealDetailSheet: View {
    let meal: Meal
    
    private var mealImageName: String {
        switch meal.meal_type {
        case .breakfast: return "breakfast"
        case .lunch:     return "lunch"
        case .dinner:    return "dinner"
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 40, height: 4)
                .padding(.top, 8)
            
            Image(mealImageName)
                .resizable()
                .scaledToFit()
                .frame(width: 140, height: 140)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.12), radius: 14, x: 0, y: 6)
            
            Text(meal.name_ar)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
            
            Text("\(meal.calories_kcal) " + "screen.kitchen.caloriesUnit".localized)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.gray)
            
            Spacer(minLength: 12)
            
            Text("screen.kitchen.mealDetailsPlaceholder".localized)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }
}

// MARK: - 🔥 Animated Meal Button (سحر الحركة)
struct AnimatedMealButton: View {
    let meal: Meal
    let action: () -> Void
    
    // حالات الحركة الخاصة بكل كارت
    @State private var floatOffsetY: CGFloat = 0.0
    @State private var isPressed: Bool = false
    @State private var tapRotation: Double = 0.0
    
    var body: some View {
        RecipeCardView(meal: meal)
            // 1. حركة الطفو (Clouds) ☁️
            .offset(y: floatOffsetY)
            
            // 2. حركة التموج عند الضغط (Water Wave) 💧
            .scaleEffect(isPressed ? 0.92 : 1.0)
            .rotation3DEffect(.degrees(tapRotation), axis: (x: 1, y: 0, z: 0))
            
            .onAppear {
                // تأخير عشوائي عشان ما يتحركون سوا مثل الروبوتات
                let randomDelay = Double.random(in: 0...2.0)
                withAnimation(
                    Animation
                        .easeInOut(duration: 5.0) // بطيء وهادئ
                        .repeatForever(autoreverses: true)
                        .delay(randomDelay)
                ) {
                    floatOffsetY = -6.0
                }
            }
            .onTapGesture {
                triggerWaveAnimation()
                action()
            }
    }
    
    private func triggerWaveAnimation() {
        // Haptic Feedback
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        
        // المرحلة الأولى: انكماش وإمالة
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0)) {
            isPressed = true
            tapRotation = 8.0
        }
        
        // المرحلة الثانية: ارتداد ناعم
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.4, blendDuration: 0)) {
                isPressed = false
                tapRotation = 0.0
            }
        }
    }
}
