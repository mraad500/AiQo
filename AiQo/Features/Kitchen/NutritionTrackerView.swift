import SwiftUI

// MARK: - Palette

private enum NutritionPalette {
    static let backgroundTop = Color(red: 0.996, green: 0.988, blue: 0.973)
    static let backgroundBottom = Color(red: 0.953, green: 0.925, blue: 0.882)
    static let mint = Color(red: 0.718, green: 0.890, blue: 0.792)
    static let sand = Color(red: 0.922, green: 0.780, blue: 0.576)
    static let pearl = Color(red: 1.0, green: 0.973, blue: 0.937)
    static let textPrimary = Color.black.opacity(0.84)
    static let textSecondary = Color.black.opacity(0.58)
    static let glassCard = Color.white.opacity(0.72)
    static let glassBorder = Color.white.opacity(0.66)

    // ألوان الـ Macros
    static let proteinColor = Color(red: 0.35, green: 0.72, blue: 0.55)   // أخضر
    static let carbColor = Color(red: 0.92, green: 0.78, blue: 0.45)      // ذهبي
    static let fatColor = Color(red: 0.85, green: 0.55, blue: 0.45)       // برتقالي
    static let fiberColor = Color(red: 0.60, green: 0.75, blue: 0.88)     // أزرق فاتح
}

// MARK: - Daily Nutrition Summary

/// ملخص التغذية اليومي — يعرض macros مع progress rings
struct NutritionSummaryCard: View {
    let meals: [KitchenPlannedMeal]

    /// أهداف يومية افتراضية (يمكن تخصيصها لاحقاً)
    var calorieGoal: Int = 2200
    var proteinGoal: Double = 150
    var carbGoal: Double = 250
    var fatGoal: Double = 70
    var fiberGoal: Double = 30

    private var totalCalories: Int {
        meals.compactMap(\.calories).reduce(0, +)
    }

    private var totalProtein: Double {
        meals.compactMap(\.protein).reduce(0, +)
    }

    private var totalCarbs: Double {
        meals.compactMap(\.carbs).reduce(0, +)
    }

    private var totalFat: Double {
        meals.compactMap(\.fat).reduce(0, +)
    }

    private var totalFiber: Double {
        meals.compactMap(\.fiber).reduce(0, +)
    }

    var body: some View {
        VStack(spacing: 18) {
            // العنوان
            HStack {
                Label(NSLocalizedString("nutrition.daily", value: "التغذية اليومية", comment: "Daily nutrition"), systemImage: "chart.pie.fill")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(NutritionPalette.textPrimary)

                Spacer()

                Text(String(format: NSLocalizedString("nutrition.calories.progress", value: "%d / %d سعرة", comment: "Calories progress"), totalCalories, calorieGoal))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(NutritionPalette.textSecondary)
            }

            // شريط السعرات الكلي
            calorieProgressBar

            // الـ Macros الأربعة
            HStack(spacing: 14) {
                macroRing(
                    label: NSLocalizedString("nutrition.protein", value: "بروتين", comment: "Protein"),
                    value: totalProtein,
                    goal: proteinGoal,
                    unit: NSLocalizedString("nutrition.gram", value: "غ", comment: "Gram unit"),
                    color: NutritionPalette.proteinColor
                )

                macroRing(
                    label: NSLocalizedString("nutrition.carbs", value: "كارب", comment: "Carbs"),
                    value: totalCarbs,
                    goal: carbGoal,
                    unit: NSLocalizedString("nutrition.gram", value: "غ", comment: "Gram unit"),
                    color: NutritionPalette.carbColor
                )

                macroRing(
                    label: NSLocalizedString("nutrition.fat", value: "دهون", comment: "Fat"),
                    value: totalFat,
                    goal: fatGoal,
                    unit: NSLocalizedString("nutrition.gram", value: "غ", comment: "Gram unit"),
                    color: NutritionPalette.fatColor
                )

                macroRing(
                    label: NSLocalizedString("nutrition.fiber", value: "ألياف", comment: "Fiber"),
                    value: totalFiber,
                    goal: fiberGoal,
                    unit: NSLocalizedString("nutrition.gram", value: "غ", comment: "Gram unit"),
                    color: NutritionPalette.fiberColor
                )
            }

            // تفصيل الوجبات
            if !meals.isEmpty {
                mealBreakdown
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(NutritionPalette.glassCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(NutritionPalette.glassBorder, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(nutritionAccessibilityLabel)
    }

    private var nutritionAccessibilityLabel: String {
        var parts = ["\(totalCalories) من \(calorieGoal) سعرة"]
        parts.append("بروتين \(String(format: "%.0f", totalProtein)) غرام")
        parts.append("كارب \(String(format: "%.0f", totalCarbs)) غرام")
        parts.append("دهون \(String(format: "%.0f", totalFat)) غرام")
        parts.append("ألياف \(String(format: "%.0f", totalFiber)) غرام")
        return "ملخص التغذية اليومية، " + parts.joined(separator: "، ")
    }

    // MARK: - Calorie Progress Bar

    private var calorieProgressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.gray.opacity(0.1))

                let progress = min(CGFloat(totalCalories) / CGFloat(max(calorieGoal, 1)), 1.0)
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [NutritionPalette.mint, NutritionPalette.sand],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * progress)
                    .animation(.spring(response: 0.8), value: totalCalories)
            }
        }
        .frame(height: 10)
    }

    // MARK: - Macro Ring

    private func macroRing(label: String, value: Double, goal: Double, unit: String, color: Color) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.15), lineWidth: 5)
                    .frame(width: 52, height: 52)

                let progress = min(value / max(goal, 1), 1.0)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 52, height: 52)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.8), value: value)

                Text(String(format: "%.0f", value))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(NutritionPalette.textPrimary)
            }

            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(NutritionPalette.textSecondary)

            Text("\(String(format: "%.0f", goal))\(unit)")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(color.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Meal Breakdown

    private var mealBreakdown: some View {
        VStack(spacing: 8) {
            Divider()
                .padding(.vertical, 4)

            ForEach(meals) { meal in
                HStack(spacing: 10) {
                    Image(systemName: meal.type.defaultSymbolName)
                        .font(.system(size: 14))
                        .foregroundStyle(NutritionPalette.sand)
                        .frame(width: 22)

                    Text(meal.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(NutritionPalette.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    // Macros مختصرة
                    HStack(spacing: 8) {
                        if let cal = meal.calories {
                            macroTag(value: "\(cal)", label: "cal", color: NutritionPalette.sand)
                        }
                        if let p = meal.protein {
                            macroTag(value: String(format: "%.0f", p), label: "P", color: NutritionPalette.proteinColor)
                        }
                        if let c = meal.carbs {
                            macroTag(value: String(format: "%.0f", c), label: "C", color: NutritionPalette.carbColor)
                        }
                        if let f = meal.fat {
                            macroTag(value: String(format: "%.0f", f), label: "F", color: NutritionPalette.fatColor)
                        }
                    }
                }
            }
        }
    }

    private func macroTag(value: String, label: String, color: Color) -> some View {
        HStack(spacing: 2) {
            Text(value)
                .font(.system(size: 10, weight: .bold, design: .rounded))
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(color.opacity(0.7))
        }
        .foregroundStyle(color)
    }
}

// MARK: - Nutrition Goals Settings

/// شاشة تعديل أهداف التغذية
struct NutritionGoalsEditor: View {
    @AppStorage("aiqo.nutrition.calorieGoal") private var calorieGoal = 2200
    @AppStorage("aiqo.nutrition.proteinGoal") private var proteinGoal = 150.0
    @AppStorage("aiqo.nutrition.carbGoal") private var carbGoal = 250.0
    @AppStorage("aiqo.nutrition.fatGoal") private var fatGoal = 70.0
    @AppStorage("aiqo.nutrition.fiberGoal") private var fiberGoal = 30.0

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(NSLocalizedString("nutrition.goals.calories", value: "السعرات الحرارية", comment: "Calories section")) {
                    Stepper(
                        String(format: NSLocalizedString("nutrition.goals.calorieValue", value: "%d سعرة", comment: ""), calorieGoal),
                        value: $calorieGoal,
                        in: 1200...5000,
                        step: 100
                    )
                }

                Section(NSLocalizedString("nutrition.goals.protein", value: "البروتين (غرام)", comment: "Protein section")) {
                    Stepper(
                        String(format: "%.0f غ", proteinGoal),
                        value: $proteinGoal,
                        in: 50...400,
                        step: 10
                    )
                }

                Section(NSLocalizedString("nutrition.goals.carbs", value: "الكربوهيدرات (غرام)", comment: "Carbs section")) {
                    Stepper(
                        String(format: "%.0f غ", carbGoal),
                        value: $carbGoal,
                        in: 50...500,
                        step: 10
                    )
                }

                Section(NSLocalizedString("nutrition.goals.fat", value: "الدهون (غرام)", comment: "Fat section")) {
                    Stepper(
                        String(format: "%.0f غ", fatGoal),
                        value: $fatGoal,
                        in: 20...200,
                        step: 5
                    )
                }

                Section(NSLocalizedString("nutrition.goals.fiber", value: "الألياف (غرام)", comment: "Fiber section")) {
                    Stepper(
                        String(format: "%.0f غ", fiberGoal),
                        value: $fiberGoal,
                        in: 10...80,
                        step: 5
                    )
                }

                Section {
                    Button(NSLocalizedString("nutrition.goals.reset", value: "استعادة القيم الافتراضية", comment: "Reset defaults")) {
                        calorieGoal = 2200
                        proteinGoal = 150
                        carbGoal = 250
                        fatGoal = 70
                        fiberGoal = 30
                    }
                    .foregroundStyle(.red.opacity(0.7))
                }
            }
            .navigationTitle(NSLocalizedString("nutrition.goals.title", value: "أهداف التغذية", comment: "Nutrition goals title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(NSLocalizedString("nutrition.goals.save", value: "حفظ", comment: "Save")) {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(NutritionPalette.mint)
                }
            }
        }
    }
}

// MARK: - Quick Add Meal Sheet

/// إدخال وجبة سريع مع macros + favorites + recents
struct QuickAddMealView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var kitchenStore: KitchenPersistenceStore
    var onSave: (KitchenPlannedMeal, Double) -> Void

    @State private var mealName: String = ""
    @State private var mealType: KitchenMealType = .breakfast
    @State private var calories: String = ""
    @State private var protein: String = ""
    @State private var carbs: String = ""
    @State private var fat: String = ""
    @State private var fiber: String = ""
    @State private var servings: Double = 1.0
    @State private var saveAsFavorite: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    quickPickSection

                    // نوع الوجبة
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("nutrition.mealType", value: "نوع الوجبة", comment: "Meal type"))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(NutritionPalette.textSecondary)

                        Picker(NSLocalizedString("nutrition.mealType", value: "نوع الوجبة", comment: ""), selection: $mealType) {
                            ForEach(KitchenMealType.allCases) { type in
                                Text(type.localizedTitle).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // اسم الوجبة
                    inputField(
                        icon: "fork.knife",
                        placeholder: NSLocalizedString("nutrition.mealName", value: "اسم الوجبة", comment: "Meal name placeholder"),
                        text: $mealName,
                        keyboard: .default,
                        tint: NutritionPalette.sand
                    )

                    // السعرات
                    inputField(
                        icon: "flame.fill",
                        placeholder: NSLocalizedString("nutrition.caloriesPlaceholder", value: "السعرات", comment: "Calories placeholder"),
                        text: $calories,
                        keyboard: .numberPad,
                        tint: NutritionPalette.sand,
                        suffix: "kcal"
                    )

                    // Macros Grid
                    HStack(spacing: 12) {
                        macroInput(
                            label: NSLocalizedString("nutrition.protein", value: "بروتين", comment: ""),
                            text: $protein,
                            color: NutritionPalette.proteinColor
                        )
                        macroInput(
                            label: NSLocalizedString("nutrition.carbs", value: "كارب", comment: ""),
                            text: $carbs,
                            color: NutritionPalette.carbColor
                        )
                    }

                    HStack(spacing: 12) {
                        macroInput(
                            label: NSLocalizedString("nutrition.fat", value: "دهون", comment: ""),
                            text: $fat,
                            color: NutritionPalette.fatColor
                        )
                        macroInput(
                            label: NSLocalizedString("nutrition.fiber", value: "ألياف", comment: ""),
                            text: $fiber,
                            color: NutritionPalette.fiberColor
                        )
                    }

                    servingsStepper

                    Toggle(isOn: $saveAsFavorite) {
                        Label(
                            NSLocalizedString(
                                "nutrition.saveAsFavorite",
                                value: "احفظها كمفضّلة",
                                comment: "Save as favorite"
                            ),
                            systemImage: saveAsFavorite ? "star.fill" : "star"
                        )
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(NutritionPalette.textPrimary)
                    }
                    .tint(NutritionPalette.proteinColor)

                    Spacer()
                        .frame(height: 8)

                    // زر الحفظ
                    Button {
                        saveMeal()
                    } label: {
                        Text(NSLocalizedString("nutrition.addMeal.button", value: "أضف الوجبة ✨", comment: "Add meal button"))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [NutritionPalette.mint, Color(red: 0.55, green: 0.82, blue: 0.68)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                    }
                    .disabled(mealName.isEmpty)
                    .opacity(mealName.isEmpty ? 0.5 : 1)
                }
                .padding(20)
            }
            .background(
                LinearGradient(
                    colors: [NutritionPalette.backgroundTop, NutritionPalette.backgroundBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle(NSLocalizedString("nutrition.addMeal.title", value: "أضف وجبة", comment: "Add meal title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(NSLocalizedString("nutrition.cancel", value: "إلغاء", comment: "Cancel")) { dismiss() }
                        .foregroundStyle(NutritionPalette.textSecondary)
                }
            }
        }
    }

    // MARK: - Components

    private func inputField(
        icon: String,
        placeholder: String,
        text: Binding<String>,
        keyboard: UIKeyboardType,
        tint: Color,
        suffix: String? = nil
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .frame(width: 24)

            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .textFieldStyle(.plain)

            if let suffix {
                Text(suffix)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(NutritionPalette.textSecondary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(NutritionPalette.pearl)
        )
    }

    private func macroInput(label: String, text: Binding<String>, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)

            HStack(spacing: 8) {
                TextField("0", text: text)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.plain)
                    .font(.system(size: 18, weight: .bold, design: .rounded))

                Text("غ")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(NutritionPalette.textSecondary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(color.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(color.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - Quick pick section (favorites + recents)

    @ViewBuilder
    private var quickPickSection: some View {
        let favorites = kitchenStore.recentlyUsedFavorites(limit: 8)
        let recents = kitchenStore.recentlyLoggedMeals(limit: 6)

        if !favorites.isEmpty || !recents.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                if !favorites.isEmpty {
                    quickRow(
                        title: NSLocalizedString("nutrition.favorites", value: "المفضّلة", comment: "Favorites"),
                        icon: "star.fill",
                        items: favorites.map { fav in
                            QuickPickItem(
                                id: fav.id.uuidString,
                                title: fav.meal.title,
                                subtitle: caloriesSubtitle(fav.meal.calories),
                                emphasized: true,
                                onTap: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    onSave(fav.meal, 1.0)
                                    kitchenStore.touchFavorite(id: fav.id)
                                    dismiss()
                                }
                            )
                        }
                    )
                }

                if !recents.isEmpty {
                    quickRow(
                        title: NSLocalizedString("nutrition.recents", value: "الأخيرة", comment: "Recently logged"),
                        icon: "clock.arrow.circlepath",
                        items: recents.map { meal in
                            QuickPickItem(
                                id: meal.id.uuidString,
                                title: meal.title,
                                subtitle: caloriesSubtitle(meal.calories),
                                emphasized: false,
                                onTap: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    onSave(meal, 1.0)
                                    dismiss()
                                }
                            )
                        }
                    )
                }
            }
        }
    }

    private func caloriesSubtitle(_ calories: Int?) -> String? {
        guard let calories else { return nil }
        return "\(calories) " + "screen.kitchen.caloriesUnit".localized
    }

    private func quickRow(
        title: String,
        icon: String,
        items: [QuickPickItem]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(NutritionPalette.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(items) { item in
                        QuickPickChip(item: item)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    // MARK: - Servings stepper

    private var servingsStepper: some View {
        HStack(spacing: 12) {
            Label(
                NSLocalizedString("nutrition.servings", value: "الحصص", comment: "Servings"),
                systemImage: "fork.knife.circle"
            )
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(NutritionPalette.textPrimary)

            Spacer(minLength: 8)

            HStack(spacing: 0) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    servings = max(0.25, servings - 0.25)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(NutritionPalette.textPrimary)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .disabled(servings <= 0.25)
                .opacity(servings <= 0.25 ? 0.4 : 1)

                Text(servingsText(servings))
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .frame(minWidth: 44)
                    .foregroundStyle(NutritionPalette.textPrimary)

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    servings = min(5.0, servings + 0.25)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(NutritionPalette.textPrimary)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .disabled(servings >= 5.0)
                .opacity(servings >= 5.0 ? 0.4 : 1)
            }
            .background(
                Capsule(style: .continuous)
                    .fill(NutritionPalette.pearl)
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(NutritionPalette.glassBorder, lineWidth: 1)
                    )
            )
        }
    }

    private func servingsText(_ value: Double) -> String {
        if value == value.rounded() {
            return String(format: "×%d", Int(value))
        }
        return String(format: "×%.2f", value)
    }

    // MARK: - Save

    private func saveMeal() {
        let meal = KitchenPlannedMeal(
            dayIndex: 1,
            type: mealType,
            title: mealName,
            calories: Int(calories),
            protein: Double(protein),
            carbs: Double(carbs),
            fat: Double(fat),
            fiber: Double(fiber),
            ingredients: []
        )
        if saveAsFavorite {
            kitchenStore.toggleFavorite(meal)
        }
        onSave(meal, servings)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismiss()
    }
}

private struct QuickPickItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    let emphasized: Bool
    let onTap: () -> Void
}

private struct QuickPickChip: View {
    let item: QuickPickItem

    var body: some View {
        Button(action: item.onTap) {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(minWidth: 96, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(item.emphasized ? Color.kitchenMint.opacity(0.22) : Color(.tertiarySystemFill))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(
                                item.emphasized ? Color.kitchenMint.opacity(0.4) : Color.clear,
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Daily Food Log

/// سجل الأكل اليومي — يعرض كل الوجبات المسجلة مع macros + التزام + ماء
struct DailyFoodLogView: View {
    @ObservedObject var kitchenStore: KitchenPersistenceStore
    @State private var showAddMeal = false
    @State private var showGoalsEditor = false

    @AppStorage("aiqo.nutrition.calorieGoal") private var calorieGoal = 2200
    @AppStorage("aiqo.nutrition.proteinGoal") private var proteinGoal = 150.0
    @AppStorage("aiqo.nutrition.carbGoal") private var carbGoal = 250.0
    @AppStorage("aiqo.nutrition.fatGoal") private var fatGoal = 70.0
    @AppStorage("aiqo.nutrition.fiberGoal") private var fiberGoal = 30.0
    @AppStorage("aiqo.nutrition.waterGoal") private var waterGoal = 8

    private var plannedTodayMeals: [KitchenPlannedMeal] {
        guard let plan = kitchenStore.pinnedPlan else { return [] }
        let dayIndex = dayIndexForToday(plan: plan)
        return plan.meals
            .filter { $0.dayIndex == dayIndex }
            .sorted { mealTypeOrder($0.type) < mealTypeOrder($1.type) }
    }

    private var loggedToday: [LoggedMeal] {
        kitchenStore.loggedMealsToday()
    }

    private var mealsCountedTowardTotals: [KitchenPlannedMeal] {
        kitchenStore.adheredPlannedMealsToday() + loggedToday.map(\.scaledMeal)
    }

    var body: some View {
        VStack(spacing: 16) {
            // بطاقة الـ Macros — تجمع المخطط (المؤكّد) + المسجّل يدوياً
            NutritionSummaryCard(
                meals: mealsCountedTowardTotals,
                calorieGoal: calorieGoal,
                proteinGoal: proteinGoal,
                carbGoal: carbGoal,
                fatGoal: fatGoal,
                fiberGoal: fiberGoal
            )

            WaterTrackerCard(
                cupsToday: kitchenStore.waterCupsToday(),
                goal: waterGoal,
                onAdd: { kitchenStore.addWaterCup() },
                onRemove: { kitchenStore.removeLastWaterCupToday() }
            )

            if !plannedTodayMeals.isEmpty {
                plannedTodaySection
            }

            if !loggedToday.isEmpty {
                loggedTodaySection
            }

            actionButtons
        }
        .sheet(isPresented: $showAddMeal) {
            QuickAddMealView(kitchenStore: kitchenStore) { meal, servings in
                kitchenStore.logManualMeal(meal, servings: servings)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showGoalsEditor) {
            NutritionGoalsEditor()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    private var plannedTodaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(NSLocalizedString("nutrition.plannedToday", value: "خطة اليوم", comment: "Today's plan"))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(NutritionPalette.textPrimary)
                Spacer()
                Text(adherenceSummaryText)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(NutritionPalette.textSecondary)
            }

            ForEach(plannedTodayMeals) { meal in
                PlannedMealAdherenceRow(
                    meal: meal,
                    state: kitchenStore.adherenceState(for: meal.id),
                    onSelect: { state in
                        kitchenStore.setAdherence(state, for: meal.id)
                    }
                )
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(NutritionPalette.glassCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(NutritionPalette.glassBorder, lineWidth: 1)
                )
        )
    }

    private var loggedTodaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(NSLocalizedString("nutrition.loggedToday", value: "وجبات مضافة يدوياً", comment: "Manually logged"))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(NutritionPalette.textPrimary)

            ForEach(loggedToday) { entry in
                LoggedMealRow(
                    entry: entry,
                    onRemove: {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            kitchenStore.removeLoggedMeal(id: entry.id)
                        }
                    },
                    onServingsChange: { servings in
                        kitchenStore.updateLoggedMealServings(id: entry.id, servings: servings)
                    }
                )
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(NutritionPalette.glassCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(NutritionPalette.glassBorder, lineWidth: 1)
                )
        )
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                showAddMeal = true
            } label: {
                Label(
                    NSLocalizedString("nutrition.addMeal", value: "أضف وجبة", comment: "Add meal"),
                    systemImage: "plus.circle.fill"
                )
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(NutritionPalette.mint)
                )
            }

            Button {
                showGoalsEditor = true
            } label: {
                Label(
                    NSLocalizedString("nutrition.goals", value: "الأهداف", comment: "Goals"),
                    systemImage: "target"
                )
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(NutritionPalette.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(NutritionPalette.pearl)
                        .overlay(
                            Capsule().stroke(NutritionPalette.glassBorder, lineWidth: 1)
                        )
                )
            }
        }
    }

    private var adherenceSummaryText: String {
        let counted = plannedTodayMeals.filter { kitchenStore.adherenceState(for: $0.id).countsTowardTotals }.count
        let total = plannedTodayMeals.count
        let template = NSLocalizedString(
            "nutrition.adherence.progress",
            value: "%d / %d",
            comment: "Eaten/total"
        )
        return String(format: template, counted, total)
    }

    private func dayIndexForToday(plan: KitchenMealPlan) -> Int {
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: plan.startDate)
        let today = calendar.startOfDay(for: Date())
        let diff = calendar.dateComponents([.day], from: startDay, to: today).day ?? 0
        return min(max(diff + 1, 1), plan.days)
    }

    private func mealTypeOrder(_ type: KitchenMealType) -> Int {
        switch type {
        case .breakfast:
            return 0
        case .lunch:
            return 1
        case .dinner:
            return 2
        case .snack:
            return 3
        }
    }
}

// MARK: - Planned meal adherence row

private struct PlannedMealAdherenceRow: View {
    let meal: KitchenPlannedMeal
    let state: MealAdherenceState
    let onSelect: (MealAdherenceState) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: meal.type.defaultSymbolName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(NutritionPalette.sand)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(meal.title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(NutritionPalette.textPrimary)
                    .lineLimit(1)

                if let calories = meal.calories {
                    Text("\(calories) " + "screen.kitchen.caloriesUnit".localized)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(NutritionPalette.textSecondary)
                }
            }

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                adherenceButton(target: .ate, icon: "checkmark", tint: NutritionPalette.proteinColor)
                adherenceButton(target: .swapped, icon: "arrow.triangle.2.circlepath", tint: NutritionPalette.carbColor)
                adherenceButton(target: .skipped, icon: "xmark", tint: NutritionPalette.fatColor)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }

    private func adherenceButton(target: MealAdherenceState, icon: String, tint: Color) -> some View {
        let isSelected = state == target
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onSelect(isSelected ? .pending : target)
        } label: {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(isSelected ? .white : tint)
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(isSelected ? tint : tint.opacity(0.14))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(target.localizedTitle)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Logged meal row

private struct LoggedMealRow: View {
    let entry: LoggedMeal
    let onRemove: () -> Void
    let onServingsChange: (Double) -> Void

    private var scaledCalories: Int? {
        entry.scaledMeal.calories
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: entry.meal.type.defaultSymbolName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(NutritionPalette.sand)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.meal.title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(NutritionPalette.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(entry.meal.type.localizedTitle)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(NutritionPalette.textSecondary)
                    if let calories = scaledCalories {
                        Text("· \(calories) " + "screen.kitchen.caloriesUnit".localized)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(NutritionPalette.textSecondary)
                    }
                }
                .lineLimit(1)
            }

            Spacer(minLength: 8)

            servingsCompactStepper

            Button(role: .destructive, action: onRemove) {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.red.opacity(0.74))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(NSLocalizedString("nutrition.removeLogged", value: "احذف", comment: "Remove logged meal"))
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
    }

    private var servingsCompactStepper: some View {
        HStack(spacing: 0) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                let next = max(0.25, entry.servings - 0.25)
                onServingsChange(next)
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(.primary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .disabled(entry.servings <= 0.25)
            .opacity(entry.servings <= 0.25 ? 0.4 : 1)

            Text(servingsLabel(entry.servings))
                .font(.system(size: 11, weight: .black, design: .rounded))
                .frame(minWidth: 30)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                let next = min(5.0, entry.servings + 0.25)
                onServingsChange(next)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(.primary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .disabled(entry.servings >= 5.0)
            .opacity(entry.servings >= 5.0 ? 0.4 : 1)
        }
        .background(
            Capsule(style: .continuous)
                .fill(Color(.tertiarySystemFill))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(
                format: NSLocalizedString("nutrition.servings.a11y", value: "%@ حصص", comment: "Servings a11y"),
                servingsLabel(entry.servings)
            )
        )
    }

    private func servingsLabel(_ value: Double) -> String {
        if value == value.rounded() {
            return String(format: "×%d", Int(value))
        }
        return String(format: "×%.2f", value)
    }
}

// MARK: - Water Tracker

private struct WaterTrackerCard: View {
    let cupsToday: Int
    let goal: Int
    let onAdd: () -> Void
    let onRemove: () -> Void

    private var progress: CGFloat {
        guard goal > 0 else { return 0 }
        return min(CGFloat(cupsToday) / CGFloat(goal), 1.0)
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Label(
                    NSLocalizedString("nutrition.water.title", value: "الماء", comment: "Water"),
                    systemImage: "drop.fill"
                )
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(NutritionPalette.textPrimary)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(NutritionPalette.fiberColor)

                Spacer()

                Text(
                    String(
                        format: NSLocalizedString(
                            "nutrition.water.cups",
                            value: "%d / %d أكواب",
                            comment: "Cups today"
                        ),
                        cupsToday,
                        goal
                    )
                )
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(NutritionPalette.textSecondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(NutritionPalette.fiberColor.opacity(0.18))

                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(NutritionPalette.fiberColor)
                        .frame(width: geo.size.width * progress)
                        .animation(.spring(response: 0.6), value: cupsToday)
                }
            }
            .frame(height: 10)

            HStack(spacing: 10) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onRemove()
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(NutritionPalette.fiberColor)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(NutritionPalette.fiberColor.opacity(0.14))
                        )
                }
                .buttonStyle(.plain)
                .disabled(cupsToday == 0)
                .opacity(cupsToday == 0 ? 0.4 : 1)
                .accessibilityLabel(NSLocalizedString("nutrition.water.remove", value: "احذف كوب", comment: "Remove a cup"))

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onAdd()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .black))
                        Text(NSLocalizedString("nutrition.water.add", value: "أضف كوب", comment: "Add a cup"))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(
                        Capsule()
                            .fill(NutritionPalette.fiberColor)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(NSLocalizedString("nutrition.water.add", value: "أضف كوب", comment: "Add a cup"))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(NutritionPalette.glassCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(NutritionPalette.glassBorder, lineWidth: 1)
                )
        )
    }
}

// MARK: - Preview

#Preview("Nutrition Summary") {
    NutritionSummaryCard(meals: [
        KitchenPlannedMeal(dayIndex: 1, type: .breakfast, title: "بيض مخفوق مع خبز أسمر", calories: 380, protein: 24, carbs: 35, fat: 18, fiber: 4, ingredients: []),
        KitchenPlannedMeal(dayIndex: 1, type: .lunch, title: "ستيك مع خضار مطبوخة", calories: 560, protein: 42, carbs: 25, fat: 28, fiber: 6, ingredients: []),
        KitchenPlannedMeal(dayIndex: 1, type: .dinner, title: "سمك مشوي مع بطاطا", calories: 430, protein: 35, carbs: 40, fat: 12, fiber: 5, ingredients: [])
    ])
    .padding()
}

#Preview("Quick Add Meal") {
    QuickAddMealView(kitchenStore: KitchenPersistenceStore(defaults: UserDefaults(suiteName: "QuickAddPreview") ?? .standard)) { meal, servings in
        print(meal, servings)
    }
}
