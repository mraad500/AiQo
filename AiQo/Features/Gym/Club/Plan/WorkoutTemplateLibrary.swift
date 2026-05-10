import SwiftUI

// MARK: - Curated quick-start workout templates
//
// Hand-picked, evidence-grounded plans the user can pin in one tap without
// going through the Captain chat — designed to hit the most common needs
// (quick energy, mobility, core, full-body, cardio bias, strength bias).

struct WorkoutTemplate: Identifiable {
    let id: String
    let titleAr: String
    let titleEn: String
    let durationMinutes: Int
    let exercisesAr: [Exercise]
    let exercisesEn: [Exercise]
    let icon: String
    let tint: Color
    let descriptorAr: String
    let descriptorEn: String

    func plan(language: AppLanguage) -> WorkoutPlan {
        let isArabic = language == .arabic
        return WorkoutPlan(
            title: isArabic ? titleAr : titleEn,
            exercises: isArabic ? exercisesAr : exercisesEn
        )
    }

    func displayTitle(language: AppLanguage) -> String {
        language == .arabic ? titleAr : titleEn
    }

    func descriptor(language: AppLanguage) -> String {
        language == .arabic ? descriptorAr : descriptorEn
    }
}

enum WorkoutTemplateCatalog {
    static let all: [WorkoutTemplate] = [
        // 1) 5-min quick energizer
        WorkoutTemplate(
            id: "energy.5min",
            titleAr: "صحوة 5 دقائق",
            titleEn: "5-Min Wake-Up",
            durationMinutes: 5,
            exercisesAr: [
                Exercise(name: "تنفّس 4-6", sets: 1, repsOrDuration: "60 ثانية"),
                Exercise(name: "إحماء مفاصل", sets: 1, repsOrDuration: "60 ثانية"),
                Exercise(name: "Jumping Jacks", sets: 2, repsOrDuration: "30 ثانية"),
                Exercise(name: "سكوات وزن جسم", sets: 2, repsOrDuration: "10 تكرار")
            ],
            exercisesEn: [
                Exercise(name: "4-6 Breathing", sets: 1, repsOrDuration: "60 sec"),
                Exercise(name: "Joint Activation", sets: 1, repsOrDuration: "60 sec"),
                Exercise(name: "Jumping Jacks", sets: 2, repsOrDuration: "30 sec"),
                Exercise(name: "Bodyweight Squat", sets: 2, repsOrDuration: "10 reps")
            ],
            icon: "bolt.fill",
            tint: Color(red: 0.99, green: 0.78, blue: 0.45),
            descriptorAr: "ابدأ يومك بطاقة عالية وبدون معدّات",
            descriptorEn: "Wake up the body in five — no gear"
        ),

        // 2) 10-min mobility flow
        WorkoutTemplate(
            id: "mobility.10min",
            titleAr: "مرونة 10 دقائق",
            titleEn: "10-Min Mobility",
            durationMinutes: 10,
            exercisesAr: [
                Exercise(name: "تنفّس 4-6", sets: 1, repsOrDuration: "60 ثانية"),
                Exercise(name: "قطة-بقرة", sets: 2, repsOrDuration: "45 ثانية"),
                Exercise(name: "فتح الورك", sets: 2, repsOrDuration: "45 ثانية"),
                Exercise(name: "تمدد أوتار خلفية", sets: 2, repsOrDuration: "45 ثانية"),
                Exercise(name: "تمدد كتف وصدر", sets: 2, repsOrDuration: "45 ثانية")
            ],
            exercisesEn: [
                Exercise(name: "4-6 Breathing", sets: 1, repsOrDuration: "60 sec"),
                Exercise(name: "Cat-Cow Flow", sets: 2, repsOrDuration: "45 sec"),
                Exercise(name: "Hip Opener", sets: 2, repsOrDuration: "45 sec"),
                Exercise(name: "Hamstring Stretch", sets: 2, repsOrDuration: "45 sec"),
                Exercise(name: "Shoulder & Chest Opener", sets: 2, repsOrDuration: "45 sec")
            ],
            icon: "figure.flexibility",
            tint: Color(red: 0.72, green: 0.80, blue: 0.96),
            descriptorAr: "تخفيف الشد وتحسين المدى الحركي",
            descriptorEn: "Decompress, lengthen, restore range"
        ),

        // 3) 15-min core finisher
        WorkoutTemplate(
            id: "core.15min",
            titleAr: "كور 15 دقيقة",
            titleEn: "15-Min Core",
            durationMinutes: 15,
            exercisesAr: [
                Exercise(name: "بلانك", sets: 3, repsOrDuration: "40 ثانية"),
                Exercise(name: "بلانك جانبي", sets: 3, repsOrDuration: "30 ثانية لكل جهة"),
                Exercise(name: "Mountain Climber", sets: 3, repsOrDuration: "30 ثانية"),
                Exercise(name: "Russian Twist", sets: 3, repsOrDuration: "20 تكرار"),
                Exercise(name: "Leg Raise", sets: 3, repsOrDuration: "12 تكرار")
            ],
            exercisesEn: [
                Exercise(name: "Plank", sets: 3, repsOrDuration: "40 sec"),
                Exercise(name: "Side Plank", sets: 3, repsOrDuration: "30 sec each side"),
                Exercise(name: "Mountain Climber", sets: 3, repsOrDuration: "30 sec"),
                Exercise(name: "Russian Twist", sets: 3, repsOrDuration: "20 reps"),
                Exercise(name: "Leg Raise", sets: 3, repsOrDuration: "12 reps")
            ],
            icon: "figure.core.training",
            tint: Color(red: 0.45, green: 0.83, blue: 0.78),
            descriptorAr: "كور قوي = توازن أفضل وظهر محمي",
            descriptorEn: "Sturdy core, balanced body, safer back"
        ),

        // 4) 20-min full-body bodyweight
        WorkoutTemplate(
            id: "fullBody.20min",
            titleAr: "جسم كامل 20 دقيقة",
            titleEn: "20-Min Full Body",
            durationMinutes: 20,
            exercisesAr: [
                Exercise(name: "إحماء ديناميكي", sets: 1, repsOrDuration: "90 ثانية"),
                Exercise(name: "سكوات وزن جسم", sets: 4, repsOrDuration: "12 تكرار"),
                Exercise(name: "ضغط مائل", sets: 4, repsOrDuration: "10 تكرار"),
                Exercise(name: "ريفرس لانجز", sets: 3, repsOrDuration: "10 لكل رجل"),
                Exercise(name: "إنفرتد رو", sets: 3, repsOrDuration: "10 تكرار"),
                Exercise(name: "بلانك", sets: 3, repsOrDuration: "40 ثانية")
            ],
            exercisesEn: [
                Exercise(name: "Dynamic Warm-Up", sets: 1, repsOrDuration: "90 sec"),
                Exercise(name: "Bodyweight Squat", sets: 4, repsOrDuration: "12 reps"),
                Exercise(name: "Incline Push-Up", sets: 4, repsOrDuration: "10 reps"),
                Exercise(name: "Reverse Lunge", sets: 3, repsOrDuration: "10 each leg"),
                Exercise(name: "Inverted Row", sets: 3, repsOrDuration: "10 reps"),
                Exercise(name: "Plank", sets: 3, repsOrDuration: "40 sec")
            ],
            icon: "figure.mixed.cardio",
            tint: Color(red: 0.55, green: 0.72, blue: 0.95),
            descriptorAr: "جسم كامل بدون معدّات وبفعالية عالية",
            descriptorEn: "Whole-body session, zero equipment"
        ),

        // 5) 30-min cardio bias
        WorkoutTemplate(
            id: "cardio.30min",
            titleAr: "كارديو 30 دقيقة",
            titleEn: "30-Min Cardio",
            durationMinutes: 30,
            exercisesAr: [
                Exercise(name: "إحماء ديناميكي", sets: 1, repsOrDuration: "3 دقائق"),
                Exercise(name: "هرولة خفيفة", sets: 1, repsOrDuration: "10 دقائق"),
                Exercise(name: "Burpee", sets: 4, repsOrDuration: "10 تكرار"),
                Exercise(name: "Mountain Climber", sets: 4, repsOrDuration: "40 ثانية"),
                Exercise(name: "نط حبل أو Jumping Jacks", sets: 4, repsOrDuration: "60 ثانية"),
                Exercise(name: "تهدئة ومشي", sets: 1, repsOrDuration: "3 دقائق")
            ],
            exercisesEn: [
                Exercise(name: "Dynamic Warm-Up", sets: 1, repsOrDuration: "3 min"),
                Exercise(name: "Light Jog", sets: 1, repsOrDuration: "10 min"),
                Exercise(name: "Burpee", sets: 4, repsOrDuration: "10 reps"),
                Exercise(name: "Mountain Climber", sets: 4, repsOrDuration: "40 sec"),
                Exercise(name: "Jump Rope or Jacks", sets: 4, repsOrDuration: "60 sec"),
                Exercise(name: "Cool-Down Walk", sets: 1, repsOrDuration: "3 min")
            ],
            icon: "heart.fill",
            tint: Color(red: 0.96, green: 0.50, blue: 0.55),
            descriptorAr: "حرق سعرات وتعزيز قوة القلب",
            descriptorEn: "Burn calories, build a stronger heart"
        ),

        // 6) 45-min strength block
        WorkoutTemplate(
            id: "strength.45min",
            titleAr: "قوة 45 دقيقة",
            titleEn: "45-Min Strength",
            durationMinutes: 45,
            exercisesAr: [
                Exercise(name: "إحماء مفاصل + 5 دقائق كارديو خفيف", sets: 1, repsOrDuration: "6 دقائق"),
                Exercise(name: "سكوات", sets: 4, repsOrDuration: "8-10 تكرار"),
                Exercise(name: "ضغط أو بنش", sets: 4, repsOrDuration: "8-10 تكرار"),
                Exercise(name: "رو", sets: 4, repsOrDuration: "10 تكرار"),
                Exercise(name: "Hip Thrust", sets: 3, repsOrDuration: "12 تكرار"),
                Exercise(name: "بلانك جانبي", sets: 3, repsOrDuration: "40 ثانية لكل جهة"),
                Exercise(name: "تمدد ختامي", sets: 1, repsOrDuration: "3 دقائق")
            ],
            exercisesEn: [
                Exercise(name: "Joint Prep + Light Cardio", sets: 1, repsOrDuration: "6 min"),
                Exercise(name: "Squat", sets: 4, repsOrDuration: "8-10 reps"),
                Exercise(name: "Press or Bench", sets: 4, repsOrDuration: "8-10 reps"),
                Exercise(name: "Row", sets: 4, repsOrDuration: "10 reps"),
                Exercise(name: "Hip Thrust", sets: 3, repsOrDuration: "12 reps"),
                Exercise(name: "Side Plank", sets: 3, repsOrDuration: "40 sec each side"),
                Exercise(name: "Cool-Down Stretch", sets: 1, repsOrDuration: "3 min")
            ],
            icon: "figure.strengthtraining.traditional",
            tint: Color(red: 0.85, green: 0.66, blue: 0.96),
            descriptorAr: "بناء قوة ووضوح في كل المجموعات",
            descriptorEn: "Build strength across every major group"
        )
    ]
}

// MARK: - Quick-start templates strip (horizontal scroll)

struct QuickStartTemplatesStrip: View {
    let language: AppLanguage
    let onPickTemplate: (WorkoutTemplate) -> Void

    private var isArabic: Bool { language == .arabic }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Color(red: 0.99, green: 0.78, blue: 0.45))
                Text(isArabic ? "بدء فوري" : "Quick start")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary)
                Spacer()
                Text(isArabic ? "بضغطة وحدة" : "One-tap pin")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule(style: .continuous).fill(Color.white.opacity(0.55))
                    )
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 11) {
                    ForEach(WorkoutTemplateCatalog.all) { template in
                        Button {
                            onPickTemplate(template)
                        } label: {
                            templateCard(template)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.bottom, 4)
            }
        }
    }

    private func templateCard(_ template: WorkoutTemplate) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [template.tint, template.tint.opacity(0.65)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: template.icon)
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(.white)
                }
                .frame(width: 36, height: 36)
                .shadow(color: template.tint.opacity(0.45), radius: 8, y: 4)

                VStack(alignment: .leading, spacing: 1) {
                    Text("\(template.durationMinutes) \(isArabic ? "د" : "min")")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundStyle(template.tint)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    Text("\(template.exercisesAr.count) \(isArabic ? "تمارين" : "moves")")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }

            Text(template.displayTitle(language: language))
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(template.descriptor(language: language))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 4) {
                Image(systemName: "pin.fill")
                    .font(.system(size: 9, weight: .heavy))
                Text(isArabic ? "ثبّت الآن" : "Pin now")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(template.tint)
            )
        }
        .padding(13)
        .frame(width: 175, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(template.tint.opacity(0.16))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.55), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }
}
