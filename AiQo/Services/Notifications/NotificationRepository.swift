import Foundation

final class NotificationRepository {
    static let shared = NotificationRepository()
    
    // UserDefaults key لتخزين آخر إندكس لكل كومبو (لغة + جنس + نوع)
    private let lastIndexDefaultsKey = "aiqo.lastNotificationIndex"
    
    private init() {}
    
    // MARK: - Public
    
    func getNotification(
        type: ActivityNotificationType,
        gender: ActivityNotificationGender,
        language: ActivityNotificationLanguage
    ) -> ActivityNotification? {
        let all = notifications(for: type, gender: gender, language: language)
        guard !all.isEmpty else { return nil }
        
        let comboKey = comboKeyFor(type: type, gender: gender, language: language)
        let lastIndex = loadLastIndex(for: comboKey)
        
        // اختار index جديد غير السابق
        let nextIndex: Int
        if all.count == 1 {
            nextIndex = 0
        } else {
            var possible = Array(0..<all.count)
            if lastIndex >= 0 && lastIndex < all.count {
                possible.removeAll { $0 == lastIndex }
            }
            nextIndex = possible.randomElement() ?? 0
        }
        
        saveLastIndex(nextIndex, for: comboKey)
        return all[nextIndex]
    }
    
    // MARK: - Internal storage dispatcher
    
    private func notifications(
        for type: ActivityNotificationType,
        gender: ActivityNotificationGender,
        language: ActivityNotificationLanguage
    ) -> [ActivityNotification] {
        switch (language, gender, type) {
        case (.arabic, .male, .moveNow):          return arabicMaleMoveNow
        case (.arabic, .male, .almostThere):      return arabicMaleAlmostThere
        case (.arabic, .male, .goalCompleted):    return arabicMaleGoalCompleted
            
        case (.arabic, .female, .moveNow):        return arabicFemaleMoveNow
        case (.arabic, .female, .almostThere):    return arabicFemaleAlmostThere
        case (.arabic, .female, .goalCompleted):  return arabicFemaleGoalCompleted
            
        case (.english, .male, .moveNow):         return englishMaleMoveNow
        case (.english, .male, .almostThere):     return englishMaleAlmostThere
        case (.english, .male, .goalCompleted):   return englishMaleGoalCompleted
            
        case (.english, .female, .moveNow):       return englishFemaleMoveNow
        case (.english, .female, .almostThere):   return englishFemaleAlmostThere
        case (.english, .female, .goalCompleted): return englishFemaleGoalCompleted
        }
    }
    
    // MARK: - Last index rotation
    
    private func comboKeyFor(
        type: ActivityNotificationType,
        gender: ActivityNotificationGender,
        language: ActivityNotificationLanguage
    ) -> String {
        return "\(language.rawValue)_\(gender.rawValue)_\(type.rawValue)"
    }
    
    private func loadLastIndex(for comboKey: String) -> Int {
        let dict = UserDefaults.standard.dictionary(forKey: lastIndexDefaultsKey) as? [String: Int]
        return dict?[comboKey] ?? -1
    }
    
    private func saveLastIndex(_ index: Int, for comboKey: String) {
        var dict = UserDefaults.standard.dictionary(forKey: lastIndexDefaultsKey) as? [String: Int] ?? [:]
        dict[comboKey] = index
        UserDefaults.standard.set(dict, forKey: lastIndexDefaultsKey)
    }
}

// MARK: - Arabic – Male

private let arabicMaleMoveNow: [ActivityNotification] = [
    .init(id: 1, text: "لم تتحرك منذ فترة… امشِ قليلاً.", type: .moveNow, gender: .male, language: .arabic),
    .init(id: 2, text: "تحرّك الآن لتلحق هدفك.", type: .moveNow, gender: .male, language: .arabic),
    .init(id: 3, text: "وقت مناسب للمشي… لا تفوّت هدفك.", type: .moveNow, gender: .male, language: .arabic),
    .init(id: 4, text: "خطوة الآن تقرّبك من هدف اليوم.", type: .moveNow, gender: .male, language: .arabic),
    .init(id: 5, text: "تحرّك دقائق قليلة لتحسين تقدمك.", type: .moveNow, gender: .male, language: .arabic),
    .init(id: 6, text: "أنت ساكن منذ مدة… امشِ دقائق.", type: .moveNow, gender: .male, language: .arabic),
    .init(id: 7, text: "نشّط جسمك… خطوة بسيطة تكفي.", type: .moveNow, gender: .male, language: .arabic),
    .init(id: 8, text: "امشِ قليلاً لتحافظ على وتيرتك.", type: .moveNow, gender: .male, language: .arabic),
    .init(id: 9, text: "حركة بسيطة تساعدك على إنجاز هدفك.", type: .moveNow, gender: .male, language: .arabic),
    .init(id: 10, text: "انهض الآن… ما زال لديك هدف لتكمله.", type: .moveNow, gender: .male, language: .arabic)
]

private let arabicMaleAlmostThere: [ActivityNotification] = [
    .init(id: 11, text: "أنت قريب جداً من هدفك.", type: .almostThere, gender: .male, language: .arabic),
    .init(id: 12, text: "خطوات قليلة وتصل.", type: .almostThere, gender: .male, language: .arabic),
    .init(id: 13, text: "أوشكت على إنهاء هدف اليوم.", type: .almostThere, gender: .male, language: .arabic),
    .init(id: 14, text: "تابع… لم يتبقَ الكثير.", type: .almostThere, gender: .male, language: .arabic),
    .init(id: 15, text: "قربت… واصل التقدم.", type: .almostThere, gender: .male, language: .arabic),
    .init(id: 16, text: "دفعة بسيطة وتكمل الهدف.", type: .almostThere, gender: .male, language: .arabic),
    .init(id: 17, text: "أنت على وشك إكمال الهدف.", type: .almostThere, gender: .male, language: .arabic),
    .init(id: 18, text: "تقدمك ممتاز… كملها.", type: .almostThere, gender: .male, language: .arabic),
    .init(id: 19, text: "خطوات قليلة فقط.", type: .almostThere, gender: .male, language: .arabic),
    .init(id: 20, text: "القليل يفصلك عن الإنجاز.", type: .almostThere, gender: .male, language: .arabic)
]

private let arabicMaleGoalCompleted: [ActivityNotification] = [
    .init(id: 21, text: "هنيئاً… اكتمل هدفك اليومي.", type: .goalCompleted, gender: .male, language: .arabic),
    .init(id: 22, text: "عمل ممتاز… وصلت لهدفك.", type: .goalCompleted, gender: .male, language: .arabic),
    .init(id: 23, text: "إنجاز رائع… اكتمل الهدف.", type: .goalCompleted, gender: .male, language: .arabic),
    .init(id: 24, text: "أحسنت… الهدف تحقق.", type: .goalCompleted, gender: .male, language: .arabic),
    .init(id: 25, text: "هدف اليوم مُنجز بالكامل.", type: .goalCompleted, gender: .male, language: .arabic),
    .init(id: 26, text: "جميل… أتممت هدفك اليوم.", type: .goalCompleted, gender: .male, language: .arabic),
    .init(id: 27, text: "أكملت هدف اليوم بنجاح.", type: .goalCompleted, gender: .male, language: .arabic),
    .init(id: 28, text: "إنجاز جديد يُسجَّل لك.", type: .goalCompleted, gender: .male, language: .arabic),
    .init(id: 29, text: "عمل قوي… الهدف تحقق.", type: .goalCompleted, gender: .male, language: .arabic),
    .init(id: 30, text: "يوم ناجح… هدفك اكتمل.", type: .goalCompleted, gender: .male, language: .arabic)
]

// MARK: - Arabic – Female

private let arabicFemaleMoveNow: [ActivityNotification] = [
    .init(id: 31, text: "لم تتحركي منذ فترة… امشي قليلاً.", type: .moveNow, gender: .female, language: .arabic),
    .init(id: 32, text: "تحركي الآن لتقتربي من هدفك.", type: .moveNow, gender: .female, language: .arabic),
    .init(id: 33, text: "وقت مناسب للمشي… لا تفوّتي هدفك.", type: .moveNow, gender: .female, language: .arabic),
    .init(id: 34, text: "خطوة الآن تقرّبك من هدف اليوم.", type: .moveNow, gender: .female, language: .arabic),
    .init(id: 35, text: "تحركي دقائق قليلة لتحسين تقدمك.", type: .moveNow, gender: .female, language: .arabic),
    .init(id: 36, text: "أنتِ ثابتة منذ مدة… امشي دقائق.", type: .moveNow, gender: .female, language: .arabic),
    .init(id: 37, text: "نشّطي جسمك… خطوة بسيطة تكفي.", type: .moveNow, gender: .female, language: .arabic),
    .init(id: 38, text: "امشي قليلاً لتحافظي على وتيرتك.", type: .moveNow, gender: .female, language: .arabic),
    .init(id: 39, text: "حركة بسيطة تساعدك على إنجاز هدفك.", type: .moveNow, gender: .female, language: .arabic),
    .init(id: 40, text: "انهضي الآن… ما زال لديكِ هدف لتكمليه.", type: .moveNow, gender: .female, language: .arabic)
]

private let arabicFemaleAlmostThere: [ActivityNotification] = [
    .init(id: 41, text: "أنتِ قريبة جداً من هدفك.", type: .almostThere, gender: .female, language: .arabic),
    .init(id: 42, text: "خطوات قليلة وتصلين.", type: .almostThere, gender: .female, language: .arabic),
    .init(id: 43, text: "أوشكتِ على إنهاء هدف اليوم.", type: .almostThere, gender: .female, language: .arabic),
    .init(id: 44, text: "واصلي… لم يتبقَ الكثير.", type: .almostThere, gender: .female, language: .arabic),
    .init(id: 45, text: "قربتِ… تابعي التقدم.", type: .almostThere, gender: .female, language: .arabic),
    .init(id: 46, text: "دفعة بسيطة وتكملين الهدف.", type: .almostThere, gender: .female, language: .arabic),
    .init(id: 47, text: "أنتِ على وشك إكمال الهدف.", type: .almostThere, gender: .female, language: .arabic),
    .init(id: 48, text: "تقدمك ممتاز… كملّيها.", type: .almostThere, gender: .female, language: .arabic),
    .init(id: 49, text: "خطوات قليلة فقط.", type: .almostThere, gender: .female, language: .arabic),
    .init(id: 50, text: "القليل يفصلك عن الإنجاز.", type: .almostThere, gender: .female, language: .arabic)
]

private let arabicFemaleGoalCompleted: [ActivityNotification] = [
    .init(id: 51, text: "هنيئاً… اكتمل هدفك اليومي.", type: .goalCompleted, gender: .female, language: .arabic),
    .init(id: 52, text: "عمل ممتاز… وصلتِ لهدفك.", type: .goalCompleted, gender: .female, language: .arabic),
    .init(id: 53, text: "إنجاز رائع… اكتمل الهدف.", type: .goalCompleted, gender: .female, language: .arabic),
    .init(id: 54, text: "أحسنتِ… تحقق الهدف.", type: .goalCompleted, gender: .female, language: .arabic),
    .init(id: 55, text: "هدف اليوم مُنجز بالكامل.", type: .goalCompleted, gender: .female, language: .arabic),
    .init(id: 56, text: "جميل… أكملتِ هدفك اليوم.", type: .goalCompleted, gender: .female, language: .arabic),
    .init(id: 57, text: "أكملتِ هدف اليوم بنجاح.", type: .goalCompleted, gender: .female, language: .arabic),
    .init(id: 58, text: "إنجاز جديد يُسجَّل لك.", type: .goalCompleted, gender: .female, language: .arabic),
    .init(id: 59, text: "عمل قوي… الهدف تحقق.", type: .goalCompleted, gender: .female, language: .arabic),
    .init(id: 60, text: "يوم ناجح… هدفك اكتمل.", type: .goalCompleted, gender: .female, language: .arabic)
]

// MARK: - English – Male

private let englishMaleMoveNow: [ActivityNotification] = [
    .init(id: 61, text: "You haven’t moved for a while… walk a bit.", type: .moveNow, gender: .male, language: .english),
    .init(id: 62, text: "Move now to stay on track.", type: .moveNow, gender: .male, language: .english),
    .init(id: 63, text: "Good time to walk… keep your goal alive.", type: .moveNow, gender: .male, language: .english),
    .init(id: 64, text: "A small walk brings you closer to your goal.", type: .moveNow, gender: .male, language: .english),
    .init(id: 65, text: "Move a little to improve today’s progress.", type: .moveNow, gender: .male, language: .english),
    .init(id: 66, text: "You’ve been still… take a short walk.", type: .moveNow, gender: .male, language: .english),
    .init(id: 67, text: "Activate your body… a small step helps.", type: .moveNow, gender: .male, language: .english),
    .init(id: 68, text: "Walk a bit to maintain your pace.", type: .moveNow, gender: .male, language: .english),
    .init(id: 69, text: "A little movement helps you reach your goal.", type: .moveNow, gender: .male, language: .english),
    .init(id: 70, text: "Stand up now… you still have a goal to finish.", type: .moveNow, gender: .male, language: .english)
]

private let englishMaleAlmostThere: [ActivityNotification] = [
    .init(id: 71, text: "You’re very close to your goal.", type: .almostThere, gender: .male, language: .english),
    .init(id: 72, text: "Just a few steps left.", type: .almostThere, gender: .male, language: .english),
    .init(id: 73, text: "You’re almost done… keep going.", type: .almostThere, gender: .male, language: .english),
    .init(id: 74, text: "Stay steady… you’re close.", type: .almostThere, gender: .male, language: .english),
    .init(id: 75, text: "A small push will finish the goal.", type: .almostThere, gender: .male, language: .english),
    .init(id: 76, text: "You’re nearly at your target.", type: .almostThere, gender: .male, language: .english),
    .init(id: 77, text: "A bit more effort to complete your goal.", type: .almostThere, gender: .male, language: .english),
    .init(id: 78, text: "Great progress… finish strong.", type: .almostThere, gender: .male, language: .english),
    .init(id: 79, text: "Almost finished… keep moving.", type: .almostThere, gender: .male, language: .english),
    .init(id: 80, text: "Very close… just a little more.", type: .almostThere, gender: .male, language: .english)
]

private let englishMaleGoalCompleted: [ActivityNotification] = [
    .init(id: 81, text: "Great job… your goal is complete.", type: .goalCompleted, gender: .male, language: .english),
    .init(id: 82, text: "You reached today’s target.", type: .goalCompleted, gender: .male, language: .english),
    .init(id: 83, text: "Well done… goal achieved.", type: .goalCompleted, gender: .male, language: .english),
    .init(id: 84, text: "Your goal is fully completed.", type: .goalCompleted, gender: .male, language: .english),
    .init(id: 85, text: "Excellent work today.", type: .goalCompleted, gender: .male, language: .english),
    .init(id: 86, text: "You finished your activity goal.", type: .goalCompleted, gender: .male, language: .english),
    .init(id: 87, text: "Strong finish… well done.", type: .goalCompleted, gender: .male, language: .english),
    .init(id: 88, text: "Your progress is complete.", type: .goalCompleted, gender: .male, language: .english),
    .init(id: 89, text: "Goal accomplished successfully.", type: .goalCompleted, gender: .male, language: .english),
    .init(id: 90, text: "A great achievement today.", type: .goalCompleted, gender: .male, language: .english)
]

// MARK: - English – Female

private let englishFemaleMoveNow: [ActivityNotification] = [
    .init(id: 91, text: "You haven’t moved for a while… walk a bit.", type: .moveNow, gender: .female, language: .english),
    .init(id: 92, text: "Move now to stay on track.", type: .moveNow, gender: .female, language: .english),
    .init(id: 93, text: "A short walk brings you closer to your goal.", type: .moveNow, gender: .female, language: .english),
    .init(id: 94, text: "Move a little… don’t miss your goal.", type: .moveNow, gender: .female, language: .english),
    .init(id: 95, text: "A gentle walk helps your progress.", type: .moveNow, gender: .female, language: .english),
    .init(id: 96, text: "You’ve been still… take a small walk.", type: .moveNow, gender: .female, language: .english),
    .init(id: 97, text: "Activate your body with a tiny move.", type: .moveNow, gender: .female, language: .english),
    .init(id: 98, text: "Walk a bit to keep your pace steady.", type: .moveNow, gender: .female, language: .english),
    .init(id: 99, text: "A few steps help you reach today’s goal.", type: .moveNow, gender: .female, language: .english),
    .init(id: 100, text: "Stand up now… your goal needs progress.", type: .moveNow, gender: .female, language: .english)
]

private let englishFemaleAlmostThere: [ActivityNotification] = [
    .init(id: 101, text: "You’re very close to your goal.", type: .almostThere, gender: .female, language: .english),
    .init(id: 102, text: "Just a few steps and you’re there.", type: .almostThere, gender: .female, language: .english),
    .init(id: 103, text: "Almost done… keep going.", type: .almostThere, gender: .female, language: .english),
    .init(id: 104, text: "Stay steady… you’re nearly there.", type: .almostThere, gender: .female, language: .english),
    .init(id: 105, text: "A little more effort finishes the goal.", type: .almostThere, gender: .female, language: .english),
    .init(id: 106, text: "Your target is very close.", type: .almostThere, gender: .female, language: .english),
    .init(id: 107, text: "You’re only steps away from finishing.", type: .almostThere, gender: .female, language: .english),
    .init(id: 108, text: "Beautiful progress… almost complete.", type: .almostThere, gender: .female, language: .english),
    .init(id: 109, text: "Almost finished… keep moving.", type: .almostThere, gender: .female, language: .english),
    .init(id: 110, text: "Very close… one last push.", type: .almostThere, gender: .female, language: .english)
]

private let englishFemaleGoalCompleted: [ActivityNotification] = [
    .init(id: 111, text: "Great job… your goal is complete.", type: .goalCompleted, gender: .female, language: .english),
    .init(id: 112, text: "You reached today’s target.", type: .goalCompleted, gender: .female, language: .english),
    .init(id: 113, text: "Well done… you finished beautifully.", type: .goalCompleted, gender: .female, language: .english),
    .init(id: 114, text: "Your goal is fully achieved.", type: .goalCompleted, gender: .female, language: .english),
    .init(id: 115, text: "Lovely work today.", type: .goalCompleted, gender: .female, language: .english),
    .init(id: 116, text: "You completed today’s progress.", type: .goalCompleted, gender: .female, language: .english),
    .init(id: 117, text: "Strong finish… excellent work.", type: .goalCompleted, gender: .female, language: .english),
    .init(id: 118, text: "Your activity goal is done.", type: .goalCompleted, gender: .female, language: .english),
    .init(id: 119, text: "Goal accomplished successfully.", type: .goalCompleted, gender: .female, language: .english),
    .init(id: 120, text: "Beautiful progress today.", type: .goalCompleted, gender: .female, language: .english)
]
