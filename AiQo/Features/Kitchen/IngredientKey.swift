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
    case ing_almonds
    case ing_avocado
    case ing_banana
    case ing_beef_lean
    case ing_bell_pepper
    case ing_berries
    case ing_black_beans
    case ing_bread_whole_wheat
    case ing_broccoli
    case ing_carrot
    case ing_cauliflower
    case ing_cheese_low_fat
    case ing_chia_seeds
    case ing_chicken_breast
    case ing_chicken_thigh
    case ing_chickpeas
    case ing_corn
    case ing_cottage_cheese
    case ing_cucumber
    case ing_dates
    case ing_egg_whites
    case ing_egg_whole
    case ing_eggplant
    case ing_flax_seeds
    case ing_garlic
    case ing_ginger
    case ing_greek_yogurt
    case ing_honey
    case ing_juice_glass
    case ing_kidney_beans
    case ing_lamb_lean
    case ing_lemon
    case ing_lentils
    case ing_lettuce
    case ing_mango
    case ing_milk
    case ing_mixed_veg
    case ing_mushrooms
    case ing_nuts_mixed
    case ing_oats
    case ing_olive_oil
    case ing_onion
    case ing_orange
    case ing_pasta
    case ing_peanut_butter
    case ing_peas
    case ing_pineapple
    case ing_potato
    case ing_quinoa
    case ing_rice_brown
    case ing_rice_white
    case ing_salmon
    case ing_shrimp
    case ing_soy_sauce
    case ing_spinach
    case ing_sweet_potato
    case ing_tahini
    case ing_tofu
    case ing_tomato
    case ing_tuna_can
    case ing_turkey_breast
    case ing_walnuts
    case ing_water_bottle
    case ing_watermelon
    case ing_whey_scoop
    case ing_white_fish
    case ing_yogurt
    case ing_zucchini

    var id: String { rawValue }

    var assetName: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .ing_apple:
            return localized("Apple", "تفاح")
        case .ing_almonds:
            return localized("Almonds", "لوز")
        case .ing_avocado:
            return localized("Avocado", "أفوكادو")
        case .ing_banana:
            return localized("Banana", "موز")
        case .ing_beef_lean:
            return localized("Lean Beef", "لحم بقري")
        case .ing_bell_pepper:
            return localized("Bell Pepper", "فلفل رومي")
        case .ing_berries:
            return localized("Berries", "توت")
        case .ing_black_beans:
            return localized("Black Beans", "فاصوليا سوداء")
        case .ing_bread_whole_wheat:
            return localized("Whole Wheat Bread", "خبز أسمر")
        case .ing_broccoli:
            return localized("Broccoli", "بروكلي")
        case .ing_carrot:
            return localized("Carrot", "جزر")
        case .ing_cauliflower:
            return localized("Cauliflower", "قرنبيط")
        case .ing_cheese_low_fat:
            return localized("Low Fat Cheese", "جبن قليل الدسم")
        case .ing_chia_seeds:
            return localized("Chia Seeds", "بذور الشيا")
        case .ing_chicken_breast:
            return localized("Chicken Breast", "صدر دجاج")
        case .ing_chicken_thigh:
            return localized("Chicken Thigh", "فخذ دجاج")
        case .ing_chickpeas:
            return localized("Chickpeas", "حمص")
        case .ing_corn:
            return localized("Corn", "ذرة")
        case .ing_cottage_cheese:
            return localized("Cottage Cheese", "جبن قريش")
        case .ing_cucumber:
            return localized("Cucumber", "خيار")
        case .ing_dates:
            return localized("Dates", "تمر")
        case .ing_egg_whites:
            return localized("Egg Whites", "بياض بيض")
        case .ing_egg_whole:
            return localized("Egg", "بيض")
        case .ing_eggplant:
            return localized("Eggplant", "باذنجان")
        case .ing_flax_seeds:
            return localized("Flax Seeds", "بذور الكتان")
        case .ing_garlic:
            return localized("Garlic", "ثوم")
        case .ing_ginger:
            return localized("Ginger", "زنجبيل")
        case .ing_greek_yogurt:
            return localized("Greek Yogurt", "زبادي يوناني")
        case .ing_honey:
            return localized("Honey", "عسل")
        case .ing_juice_glass:
            return localized("Juice", "عصير")
        case .ing_kidney_beans:
            return localized("Kidney Beans", "فاصوليا حمراء")
        case .ing_lamb_lean:
            return localized("Lean Lamb", "لحم غنم")
        case .ing_lemon:
            return localized("Lemon", "ليمون")
        case .ing_lentils:
            return localized("Lentils", "عدس")
        case .ing_lettuce:
            return localized("Lettuce", "خس")
        case .ing_mango:
            return localized("Mango", "مانجو")
        case .ing_milk:
            return localized("Milk", "حليب")
        case .ing_mixed_veg:
            return localized("Mixed Vegetables", "خضار مشكلة")
        case .ing_mushrooms:
            return localized("Mushrooms", "مشروم")
        case .ing_nuts_mixed:
            return localized("Mixed Nuts", "مكسرات")
        case .ing_oats:
            return localized("Oats", "شوفان")
        case .ing_olive_oil:
            return localized("Olive Oil", "زيت زيتون")
        case .ing_onion:
            return localized("Onion", "بصل")
        case .ing_orange:
            return localized("Orange", "برتقال")
        case .ing_pasta:
            return localized("Pasta", "باستا")
        case .ing_peanut_butter:
            return localized("Peanut Butter", "زبدة الفول السوداني")
        case .ing_peas:
            return localized("Peas", "بازلاء")
        case .ing_pineapple:
            return localized("Pineapple", "أناناس")
        case .ing_potato:
            return localized("Potato", "بطاطا")
        case .ing_quinoa:
            return localized("Quinoa", "كينوا")
        case .ing_rice_brown:
            return localized("Brown Rice", "رز بني")
        case .ing_rice_white:
            return localized("White Rice", "رز")
        case .ing_salmon:
            return localized("Salmon", "سلمون")
        case .ing_shrimp:
            return localized("Shrimp", "روبيان")
        case .ing_soy_sauce:
            return localized("Soy Sauce", "صلصة الصويا")
        case .ing_spinach:
            return localized("Spinach", "سبانخ")
        case .ing_sweet_potato:
            return localized("Sweet Potato", "بطاطا حلوة")
        case .ing_tahini:
            return localized("Tahini", "طحينة")
        case .ing_tofu:
            return localized("Tofu", "توفو")
        case .ing_tomato:
            return localized("Tomato", "طماطم")
        case .ing_tuna_can:
            return localized("Tuna", "تونة")
        case .ing_turkey_breast:
            return localized("Turkey Breast", "صدر ديك رومي")
        case .ing_walnuts:
            return localized("Walnuts", "جوز")
        case .ing_water_bottle:
            return localized("Water", "ماء")
        case .ing_watermelon:
            return localized("Watermelon", "بطيخ")
        case .ing_whey_scoop:
            return localized("Whey Protein", "بروتين واي")
        case .ing_white_fish:
            return localized("White Fish", "سمك")
        case .ing_yogurt:
            return localized("Yogurt", "زبادي")
        case .ing_zucchini:
            return localized("Zucchini", "كوسا")
        }
    }

    var estimatedProteinGrams: Int {
        switch self {
        case .ing_beef_lean:
            return 24
        case .ing_black_beans, .ing_chickpeas, .ing_kidney_beans, .ing_lentils:
            return 8
        case .ing_cheese_low_fat:
            return 10
        case .ing_chicken_breast:
            return 26
        case .ing_chicken_thigh:
            return 22
        case .ing_cottage_cheese:
            return 12
        case .ing_egg_whites:
            return 11
        case .ing_egg_whole:
            return 6
        case .ing_greek_yogurt:
            return 17
        case .ing_lamb_lean:
            return 24
        case .ing_milk:
            return 8
        case .ing_nuts_mixed:
            return 6
        case .ing_oats:
            return 5
        case .ing_peanut_butter:
            return 8
        case .ing_salmon, .ing_white_fish:
            return 23
        case .ing_shrimp:
            return 20
        case .ing_tofu:
            return 12
        case .ing_tuna_can:
            return 24
        case .ing_turkey_breast:
            return 29
        case .ing_whey_scoop:
            return 24
        case .ing_yogurt:
            return 10
        case .ing_bread_whole_wheat:
            return 4
        case .ing_quinoa:
            return 4
        case .ing_rice_brown, .ing_rice_white, .ing_pasta, .ing_potato, .ing_sweet_potato:
            return 2
        case .ing_broccoli, .ing_cauliflower, .ing_spinach, .ing_mixed_veg,
             .ing_mushrooms, .ing_peas:
            return 2
        case .ing_almonds, .ing_chia_seeds, .ing_flax_seeds, .ing_tahini, .ing_walnuts:
            return 5
        default:
            return 1
        }
    }

    var category: IngredientCategory {
        switch self {
        case .ing_beef_lean, .ing_black_beans, .ing_chicken_breast, .ing_chicken_thigh,
             .ing_chickpeas, .ing_egg_whites, .ing_egg_whole, .ing_kidney_beans,
             .ing_lamb_lean, .ing_lentils, .ing_salmon, .ing_shrimp, .ing_tofu,
             .ing_tuna_can, .ing_turkey_breast, .ing_whey_scoop, .ing_white_fish:
            return .protein
        case .ing_bread_whole_wheat, .ing_corn, .ing_oats, .ing_pasta,
             .ing_potato, .ing_quinoa, .ing_rice_brown, .ing_rice_white,
             .ing_sweet_potato:
            return .carb
        case .ing_avocado, .ing_bell_pepper, .ing_broccoli, .ing_carrot,
             .ing_cauliflower, .ing_cucumber, .ing_eggplant, .ing_garlic,
             .ing_lettuce, .ing_mixed_veg, .ing_mushrooms, .ing_onion,
             .ing_peas, .ing_spinach, .ing_tomato, .ing_zucchini:
            return .veg
        case .ing_apple, .ing_banana, .ing_berries, .ing_dates,
             .ing_lemon, .ing_mango, .ing_orange, .ing_pineapple, .ing_watermelon:
            return .fruit
        case .ing_cheese_low_fat, .ing_cottage_cheese, .ing_greek_yogurt,
             .ing_milk, .ing_yogurt:
            return .dairy
        case .ing_almonds, .ing_chia_seeds, .ing_flax_seeds, .ing_nuts_mixed,
             .ing_olive_oil, .ing_peanut_butter, .ing_tahini, .ing_walnuts:
            return .fat
        case .ing_juice_glass, .ing_water_bottle:
            return .drink
        case .ing_ginger, .ing_honey, .ing_soy_sauce:
            return .other
        }
    }

    var aliases: [String] {
        switch self {
        case .ing_apple:
            return ["تفاح", "apple", "green apple", "red apple"]
        case .ing_almonds:
            return ["لوز", "almond", "almonds"]
        case .ing_avocado:
            return ["افوكادو", "أفوكادو", "avocado"]
        case .ing_banana:
            return ["موز", "banana"]
        case .ing_beef_lean:
            return ["لحم", "لحم بقري", "ستيك", "steak", "beef", "lean beef"]
        case .ing_bell_pepper:
            return ["فلفل رومي", "فلفل بارد", "bell pepper", "capsicum"]
        case .ing_berries:
            return ["توت", "berries", "berry", "blueberries", "strawberries"]
        case .ing_black_beans:
            return ["فاصوليا سوداء", "لوبيا سوداء", "black beans", "black bean"]
        case .ing_bread_whole_wheat:
            return ["خبز اسمر", "خبز قمح كامل", "توست اسمر", "whole wheat bread", "brown bread", "toast"]
        case .ing_broccoli:
            return ["بروكلي", "broccoli"]
        case .ing_carrot:
            return ["جزر", "carrot", "carrots"]
        case .ing_cauliflower:
            return ["قرنبيط", "زهرة", "cauliflower"]
        case .ing_cheese_low_fat:
            return ["جبن قليل الدسم", "جبنة قليلة الدسم", "low fat cheese", "light cheese"]
        case .ing_chia_seeds:
            return ["بذور الشيا", "chia seeds", "chia"]
        case .ing_chicken_breast:
            return ["صدر دجاج", "صدور دجاج", "chicken breast", "grilled chicken", "chicken"]
        case .ing_chicken_thigh:
            return ["فخذ دجاج", "افخاذ دجاج", "chicken thigh", "chicken thighs"]
        case .ing_chickpeas:
            return ["حمص", "chickpeas", "chickpea", "garbanzo"]
        case .ing_corn:
            return ["ذرة", "corn"]
        case .ing_cottage_cheese:
            return ["جبن قريش", "cottage cheese"]
        case .ing_cucumber:
            return ["خيار", "cucumber"]
        case .ing_dates:
            return ["تمر", "تمور", "dates", "date fruit"]
        case .ing_egg_whites:
            return ["بياض بيض", "egg white", "egg whites", "egg white omelette"]
        case .ing_egg_whole:
            return ["بيض", "بيض كامل", "egg", "eggs", "whole egg", "omelette"]
        case .ing_eggplant:
            return ["باذنجان", "eggplant", "aubergine"]
        case .ing_flax_seeds:
            return ["بذور الكتان", "flax seeds", "flaxseed", "flax"]
        case .ing_garlic:
            return ["ثوم", "garlic"]
        case .ing_ginger:
            return ["زنجبيل", "ginger"]
        case .ing_greek_yogurt:
            return ["زبادي يوناني", "لبن يوناني", "greek yogurt"]
        case .ing_honey:
            return ["عسل", "honey"]
        case .ing_juice_glass:
            return ["عصير", "juice", "fresh juice", "smoothie"]
        case .ing_kidney_beans:
            return ["فاصوليا حمراء", "kidney beans", "kidney bean", "red beans"]
        case .ing_lamb_lean:
            return ["لحم غنم", "لحم خروف", "lean lamb", "lamb"]
        case .ing_lemon:
            return ["ليمون", "lemon"]
        case .ing_lentils:
            return ["عدس", "lentils", "lentil"]
        case .ing_lettuce:
            return ["خس", "lettuce", "romaine"]
        case .ing_mango:
            return ["مانجو", "mango"]
        case .ing_milk:
            return ["حليب", "milk"]
        case .ing_mixed_veg:
            return ["خضار", "خضار مشكلة", "خضار مطبوخة", "mixed veg", "mixed vegetables", "vegetables"]
        case .ing_mushrooms:
            return ["فطر", "مشروم", "mushroom", "mushrooms"]
        case .ing_nuts_mixed:
            return ["مكسرات", "nuts", "mixed nuts"]
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
        case .ing_peanut_butter:
            return ["زبدة الفول السوداني", "peanut butter"]
        case .ing_peas:
            return ["بازلاء", "peas", "green peas"]
        case .ing_pineapple:
            return ["أناناس", "اناناس", "pineapple"]
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
        case .ing_soy_sauce:
            return ["صلصة الصويا", "soy sauce", "soya sauce"]
        case .ing_spinach:
            return ["سبانخ", "spinach"]
        case .ing_sweet_potato:
            return ["بطاطا حلوة", "بطاطة حلوة", "sweet potato", "sweet potatoes"]
        case .ing_tahini:
            return ["طحينة", "tahini"]
        case .ing_tofu:
            return ["توفو", "tofu"]
        case .ing_tomato:
            return ["طماطة", "طماطم", "بندورة", "tomato", "tomatoes"]
        case .ing_tuna_can:
            return ["تونة", "tuna", "tuna can", "canned tuna"]
        case .ing_turkey_breast:
            return ["صدر ديك رومي", "turkey breast", "turkey"]
        case .ing_walnuts:
            return ["جوز", "عين الجمل", "walnut", "walnuts"]
        case .ing_water_bottle:
            return ["ماء", "مي", "water", "water bottle"]
        case .ing_watermelon:
            return ["بطيخ", "watermelon"]
        case .ing_whey_scoop:
            return ["بروتين واي", "واي", "whey protein", "whey", "protein scoop"]
        case .ing_white_fish:
            return ["سمك", "فيليه", "fish", "white fish"]
        case .ing_yogurt:
            return ["لبن", "زبادي", "يوغرت", "yogurt"]
        case .ing_zucchini:
            return ["كوسا", "zucchini", "courgette"]
        }
    }
}

private extension IngredientKey {
    func localized(_ english: String, _ arabic: String) -> String {
        AppSettingsStore.shared.appLanguage == .english ? english : arabic
    }
}
