import Foundation

enum IngredientCategory: String {
    case protein
    case carb
    case veg
    case fruit
    case dairy
    case fat
    case drink
    case other

    var priority: Int {
        switch self {
        case .protein:
            return 0
        case .carb:
            return 1
        case .veg:
            return 2
        case .fruit:
            return 3
        case .dairy:
            return 4
        case .fat:
            return 5
        case .drink:
            return 6
        case .other:
            return 7
        }
    }
}

enum IngredientKey: String, CaseIterable, Identifiable {
    case ing_apple
    case ing_avocado
    case ing_banana
    case ing_beef_lean
    case ing_bell_pepper
    case ing_berries
    case ing_bread_whole_wheat
    case ing_broccoli
    case ing_carrot
    case ing_chicken_breast
    case ing_chicken_thigh
    case ing_cucumber
    case ing_dates
    case ing_egg_whites
    case ing_egg_whole
    case ing_juice_glass
    case ing_lettuce
    case ing_milk
    case ing_mixed_veg
    case ing_mushrooms
    case ing_nuts_mixed
    case ing_oats
    case ing_olive_oil
    case ing_onion
    case ing_orange
    case ing_pasta
    case ing_potato
    case ing_quinoa
    case ing_rice_brown
    case ing_rice_white
    case ing_salmon
    case ing_shrimp
    case ing_spinach
    case ing_sweet_potato
    case ing_tofu
    case ing_tomato
    case ing_tuna_can
    case ing_water_bottle
    case ing_white_fish
    case ing_yogurt

    var id: String { rawValue }

    var assetName: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .ing_apple:
            return AppSettingsStore.shared.appLanguage == .english ? "Apple" : "تفاح"
        case .ing_avocado:
            return AppSettingsStore.shared.appLanguage == .english ? "Avocado" : "أفوكادو"
        case .ing_banana:
            return AppSettingsStore.shared.appLanguage == .english ? "Banana" : "موز"
        case .ing_beef_lean:
            return AppSettingsStore.shared.appLanguage == .english ? "Lean Beef" : "لحم بقري"
        case .ing_bell_pepper:
            return AppSettingsStore.shared.appLanguage == .english ? "Bell Pepper" : "فلفل رومي"
        case .ing_berries:
            return AppSettingsStore.shared.appLanguage == .english ? "Berries" : "توت"
        case .ing_bread_whole_wheat:
            return AppSettingsStore.shared.appLanguage == .english ? "Whole Wheat Bread" : "خبز أسمر"
        case .ing_broccoli:
            return AppSettingsStore.shared.appLanguage == .english ? "Broccoli" : "بروكلي"
        case .ing_carrot:
            return AppSettingsStore.shared.appLanguage == .english ? "Carrot" : "جزر"
        case .ing_chicken_breast:
            return AppSettingsStore.shared.appLanguage == .english ? "Chicken Breast" : "صدر دجاج"
        case .ing_chicken_thigh:
            return AppSettingsStore.shared.appLanguage == .english ? "Chicken Thigh" : "فخذ دجاج"
        case .ing_cucumber:
            return AppSettingsStore.shared.appLanguage == .english ? "Cucumber" : "خيار"
        case .ing_dates:
            return AppSettingsStore.shared.appLanguage == .english ? "Dates" : "تمر"
        case .ing_egg_whites:
            return AppSettingsStore.shared.appLanguage == .english ? "Egg Whites" : "بياض بيض"
        case .ing_egg_whole:
            return AppSettingsStore.shared.appLanguage == .english ? "Egg" : "بيض"
        case .ing_juice_glass:
            return AppSettingsStore.shared.appLanguage == .english ? "Juice" : "عصير"
        case .ing_lettuce:
            return AppSettingsStore.shared.appLanguage == .english ? "Lettuce" : "خس"
        case .ing_milk:
            return AppSettingsStore.shared.appLanguage == .english ? "Milk" : "حليب"
        case .ing_mixed_veg:
            return AppSettingsStore.shared.appLanguage == .english ? "Mixed Vegetables" : "خضار مشكلة"
        case .ing_mushrooms:
            return AppSettingsStore.shared.appLanguage == .english ? "Mushrooms" : "مشروم"
        case .ing_nuts_mixed:
            return AppSettingsStore.shared.appLanguage == .english ? "Mixed Nuts" : "مكسرات"
        case .ing_oats:
            return AppSettingsStore.shared.appLanguage == .english ? "Oats" : "شوفان"
        case .ing_olive_oil:
            return AppSettingsStore.shared.appLanguage == .english ? "Olive Oil" : "زيت زيتون"
        case .ing_onion:
            return AppSettingsStore.shared.appLanguage == .english ? "Onion" : "بصل"
        case .ing_orange:
            return AppSettingsStore.shared.appLanguage == .english ? "Orange" : "برتقال"
        case .ing_pasta:
            return AppSettingsStore.shared.appLanguage == .english ? "Pasta" : "باستا"
        case .ing_potato:
            return AppSettingsStore.shared.appLanguage == .english ? "Potato" : "بطاطا"
        case .ing_quinoa:
            return AppSettingsStore.shared.appLanguage == .english ? "Quinoa" : "كينوا"
        case .ing_rice_brown:
            return AppSettingsStore.shared.appLanguage == .english ? "Brown Rice" : "رز بني"
        case .ing_rice_white:
            return AppSettingsStore.shared.appLanguage == .english ? "White Rice" : "رز"
        case .ing_salmon:
            return AppSettingsStore.shared.appLanguage == .english ? "Salmon" : "سلمون"
        case .ing_shrimp:
            return AppSettingsStore.shared.appLanguage == .english ? "Shrimp" : "روبيان"
        case .ing_spinach:
            return AppSettingsStore.shared.appLanguage == .english ? "Spinach" : "سبانخ"
        case .ing_sweet_potato:
            return AppSettingsStore.shared.appLanguage == .english ? "Sweet Potato" : "بطاطا حلوة"
        case .ing_tofu:
            return AppSettingsStore.shared.appLanguage == .english ? "Tofu" : "توفو"
        case .ing_tomato:
            return AppSettingsStore.shared.appLanguage == .english ? "Tomato" : "طماطم"
        case .ing_tuna_can:
            return AppSettingsStore.shared.appLanguage == .english ? "Tuna" : "تونة"
        case .ing_water_bottle:
            return AppSettingsStore.shared.appLanguage == .english ? "Water" : "ماء"
        case .ing_white_fish:
            return AppSettingsStore.shared.appLanguage == .english ? "White Fish" : "سمك"
        case .ing_yogurt:
            return AppSettingsStore.shared.appLanguage == .english ? "Yogurt" : "زبادي"
        }
    }

    var estimatedProteinGrams: Int {
        switch self {
        case .ing_beef_lean:
            return 24
        case .ing_chicken_breast:
            return 26
        case .ing_chicken_thigh:
            return 22
        case .ing_salmon, .ing_white_fish:
            return 23
        case .ing_shrimp:
            return 20
        case .ing_tuna_can:
            return 24
        case .ing_tofu:
            return 12
        case .ing_egg_whites:
            return 11
        case .ing_egg_whole:
            return 6
        case .ing_yogurt:
            return 10
        case .ing_milk:
            return 8
        case .ing_oats:
            return 5
        case .ing_bread_whole_wheat:
            return 4
        case .ing_quinoa:
            return 4
        case .ing_rice_brown, .ing_rice_white, .ing_pasta, .ing_potato, .ing_sweet_potato:
            return 2
        case .ing_broccoli, .ing_spinach, .ing_mixed_veg, .ing_mushrooms:
            return 2
        case .ing_nuts_mixed:
            return 6
        default:
            return 1
        }
    }

    var category: IngredientCategory {
        switch self {
        case .ing_beef_lean, .ing_chicken_breast, .ing_chicken_thigh, .ing_egg_whites,
             .ing_egg_whole, .ing_salmon, .ing_shrimp, .ing_tofu, .ing_tuna_can,
             .ing_white_fish:
            return .protein
        case .ing_bread_whole_wheat, .ing_oats, .ing_pasta, .ing_potato,
             .ing_quinoa, .ing_rice_brown, .ing_rice_white, .ing_sweet_potato:
            return .carb
        case .ing_avocado, .ing_bell_pepper, .ing_broccoli, .ing_carrot,
             .ing_cucumber, .ing_lettuce, .ing_mixed_veg, .ing_mushrooms,
             .ing_onion, .ing_spinach, .ing_tomato:
            return .veg
        case .ing_apple, .ing_banana, .ing_berries, .ing_dates, .ing_orange:
            return .fruit
        case .ing_milk, .ing_yogurt:
            return .dairy
        case .ing_nuts_mixed, .ing_olive_oil:
            return .fat
        case .ing_juice_glass, .ing_water_bottle:
            return .drink
        }
    }

    var aliases: [String] {
        switch self {
        case .ing_apple:
            return ["تفاح", "apple", "green apple", "red apple"]
        case .ing_avocado:
            return ["افوكادو", "أفوكادو", "avocado"]
        case .ing_banana:
            return ["موز", "banana"]
        case .ing_beef_lean:
            return ["لحم", "لحم بقري", "ستيك", "steak", "beef", "lean beef"]
        case .ing_bell_pepper:
            return ["فلفل", "فلفل رومي", "فلفل بارد", "bell pepper", "capsicum", "pepper"]
        case .ing_berries:
            return ["توت", "berries", "berry", "blueberries", "strawberries"]
        case .ing_bread_whole_wheat:
            return ["خبز اسمر", "خبز قمح كامل", "توست اسمر", "whole wheat bread", "brown bread", "toast"]
        case .ing_broccoli:
            return ["بروكلي", "broccoli"]
        case .ing_carrot:
            return ["جزر", "carrot", "carrots"]
        case .ing_chicken_breast:
            return ["صدر دجاج", "صدور دجاج", "chicken breast", "grilled chicken", "chicken"]
        case .ing_chicken_thigh:
            return ["فخذ دجاج", "افخاذ دجاج", "chicken thigh", "chicken thighs"]
        case .ing_cucumber:
            return ["خيار", "cucumber"]
        case .ing_dates:
            return ["تمر", "تمور", "dates", "date fruit"]
        case .ing_egg_whites:
            return ["بياض بيض", "egg white", "egg whites", "egg white omelette"]
        case .ing_egg_whole:
            return ["بيض", "بيض كامل", "egg", "eggs", "whole egg", "omelette"]
        case .ing_juice_glass:
            return ["عصير", "juice", "fresh juice", "smoothie"]
        case .ing_lettuce:
            return ["خس", "lettuce", "romaine"]
        case .ing_milk:
            return ["حليب", "milk"]
        case .ing_mixed_veg:
            return ["خضار", "خضار مشكلة", "خضار مطبوخة", "mixed veg", "mixed vegetables", "vegetables"]
        case .ing_mushrooms:
            return ["فطر", "مشروم", "mushroom", "mushrooms"]
        case .ing_nuts_mixed:
            return ["مكسرات", "nuts", "mixed nuts", "almonds", "walnuts"]
        case .ing_oats:
            return ["شوفان", "oats", "oatmeal"]
        case .ing_olive_oil:
            return ["زيت زيتون", "olive oil"]
        case .ing_onion:
            return ["بصل", "onion", "onions"]
        case .ing_orange:
            return ["برتقال", "orange"]
        case .ing_pasta:
            return ["باستا", "معكرونة", "pasta"]
        case .ing_potato:
            return ["بطاطا", "بطاطة", "potato", "potatoes"]
        case .ing_quinoa:
            return ["كينوا", "quinoa"]
        case .ing_rice_brown:
            return ["رز بني", "تمن بني", "brown rice"]
        case .ing_rice_white:
            return ["رز", "تمن", "rice", "white rice"]
        case .ing_salmon:
            return ["سلمون", "salmon"]
        case .ing_shrimp:
            return ["روبيان", "جمبري", "shrimp", "prawns"]
        case .ing_spinach:
            return ["سبانخ", "spinach"]
        case .ing_sweet_potato:
            return ["بطاطا حلوة", "بطاطة حلوة", "sweet potato", "sweet potatoes"]
        case .ing_tofu:
            return ["توفو", "tofu"]
        case .ing_tomato:
            return ["طماطة", "طماطم", "بندورة", "tomato", "tomatoes"]
        case .ing_tuna_can:
            return ["تونة", "tuna", "tuna can", "canned tuna"]
        case .ing_water_bottle:
            return ["ماء", "مي", "water", "water bottle"]
        case .ing_white_fish:
            return ["سمك", "فيليه", "fish", "white fish"]
        case .ing_yogurt:
            return ["لبن", "زبادي", "يوغرت", "yogurt", "greek yogurt"]
        }
    }
}
