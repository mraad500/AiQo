import SwiftUI
import UIKit

struct KitchenScreen: View {
    
    // MARK: - Properties
    @State private var selectedMeal: Meal?
    @State private var isProfileSheetPresented = false
    @State private var isRegenerating: Bool = false
    
    let viewModel: KitchenViewModel
    let onEditDietTapped: () -> Void

    // MARK: - Body
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            
            VStack(spacing: 0) {
                
                header
                    .padding(.top, -28)      // نفس أوفست Gym اللي عدّلناه
                    .padding(.bottom, 16)
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .trailing, spacing: 24) {
                        
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
            
            // أيقونة الملف الشخصي (مطابقة لـ Gym من حيث الحجم والظل)
            Button {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                openProfile()
            } label: {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white)
                    .frame(width: 44, height: 44)
                    .shadow(color: .black.opacity(0.08),
                            radius: 8,
                            x: 0,
                            y: 4)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 20, weight: .heavy, design: .rounded))
                            .foregroundColor(.black)
                    )
            }
            .buttonStyle(.plain)
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
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    selectedMeal = meal
                } label: {
                    RecipeCardView(meal: meal)
                }
                .buttonStyle(.plain)
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
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                isRegenerating = true
                
                Task {
                    // await viewModel.generatePlan()
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    isRegenerating = false
                }
                
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
            
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
        let profileVC = NewProfileViewController()
        
        guard let root = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?
            .rootViewController else { return }
        
        root.topMostViewController().present(profileVC, animated: true, completion: nil)
    }
}

// MARK: - Helper to find Top ViewController
private extension UIViewController {
    func topMostViewController() -> UIViewController {
        if let presented = presentedViewController {
            return presented.topMostViewController()
        }
        if let nav = self as? UINavigationController {
            return nav.visibleViewController?.topMostViewController() ?? nav
        }
        if let tab = self as? UITabBarController {
            return tab.selectedViewController?.topMostViewController() ?? tab
        }
        return self
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
