// Features/Kitchen/Meal.swift

import Foundation

struct Meal: Codable, Identifiable, Equatable {
    let id: Int
    let name_ar: String
    let calories_kcal: Int
    let meal_type: MealType

    var mealType: MealType { meal_type }

    // اسم الوجبة حسب لغة الجهاز
    var localizedName: String {
        // عربي → دايركت من JSON
        if AppSettingsStore.shared.appLanguage == .arabic {
            return name_ar
        }

        // إنكليزي → من Localizable حسب الـ id
        switch id {
        // بياض بيض مع خضار (نسختين)
        case 1, 4:
            return NSLocalizedString("meal.eggVeggies", comment: "")

        // ستيك لحم مشوي (نسخ مختلفة)
        case 2, 5, 36, 63:
            return NSLocalizedString("meal.steak", comment: "")

        // تونة / دجاج مع سلطة إلخ (نستخدم نفس النص الإنكليزي)
        case 3, 69, 100, 1009:
            return NSLocalizedString("meal.tunaSalad", comment: "")

        default:
            // أي وجبة جديدة ما ضفناها بعد
            return name_ar
        }
    }
}

enum MealType: String, Codable {
    case breakfast
    case lunch
    case dinner
}

// MARK: - Image mapping by ID

extension Meal {

    var imageName: String {
        switch id {

        // الفطور
        case 1, 4:
            // بياض بيض مع خضار
            return "breakfast"

        case 2:
            // شوفان مع حليب وموز (إذا بعدك مستخدمه كفطور)
            return "breakfast.2"

        // الغداء
        case 63, 5, 36:
            // ستيك / سمك إلخ
            return "lunch"

        // العشاء
        case 69, 3, 100, 1009:
            return "dinner"

        default:
            switch mealType {
            case .breakfast: return "breakfast"
            case .lunch:     return "lunch"
            case .dinner:    return "dinner"
            }
        }
    }
}
