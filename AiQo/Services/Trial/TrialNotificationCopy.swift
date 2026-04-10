import Foundation

enum TrialNotificationKind: String {
    case welcomeEvening
    case morningBrief
    case paceSpike
    case runDetected
    case inactivityGap
    case sleepDebt
    case goalApproach
    case workoutCompleted
    case featureRevealSmartWake
    case featureRevealKitchen
    case featureRevealZone2
    case day6PaywallPreview
    case day7FinalDay
    case day7WeeklyRecapReady
    case postTrialWeeklyReport
}

struct TrialCopyContext {
    let firstName: String?
    let steps: Int?
    let calories: Int?
    let sleepHours: Double?
    let preferredSportLocalized: String?
    let preferredGoalLocalized: String?
    let weekNumber: Int?
}

enum TrialNotificationCopy {

    static func title(for kind: TrialNotificationKind, ctx: TrialCopyContext, language: String) -> String {
        let isAr = language == "ar"
        let name = ctx.firstName.map { " \($0)" } ?? ""

        switch kind {
        case .welcomeEvening:        return isAr ? "هلا\(name) 👋"                    : "Hey\(name) 👋"
        case .morningBrief:          return isAr ? "صباح الخير\(name) 🌤"              : "Good morning\(name) 🌤"
        case .paceSpike:             return isAr ? "👀 بطل كاعد تمشي سريع"            : "You're walking fast 👀"
        case .runDetected:           return isAr ? "🔥 شفتك تركض"                     : "Caught you running 🔥"
        case .inactivityGap:         return isAr ? "صار لك شوية قاعد"                 : "You've been still a while"
        case .sleepDebt:             return isAr ? "نومك اليوم قليل"                   : "Short sleep last night"
        case .goalApproach:          return isAr ? "💪 قربت من هدفك اليوم"             : "Almost at today's goal 💪"
        case .workoutCompleted:      return isAr ? "🔥 أحسنت"                         : "Great workout 🔥"
        case .featureRevealSmartWake: return isAr ? "نومك يحتاج ترتيب"                : "Your sleep needs structure"
        case .featureRevealKitchen:  return isAr ? "خل أساعدك بالأكل"                 : "Let me help with meals"
        case .featureRevealZone2:    return isAr ? "وقت تشتغل عدل"                    : "Time for real training"
        case .day6PaywallPreview:    return isAr ? "بعد يوم وراح تنتهي تجربتك"        : "One day left in your trial"
        case .day7FinalDay:          return isAr ? "اليوم آخر يوم بتجربتك"            : "Last day of your trial"
        case .day7WeeklyRecapReady:  return isAr ? "📊 تقريرك الأول جاهز"             : "Your first report is ready 📊"
        case .postTrialWeeklyReport: return isAr ? "📊 تقرير الكابتن الأسبوعي"        : "Weekly Captain report 📊"
        }
    }

    static func body(for kind: TrialNotificationKind, ctx: TrialCopyContext, language: String) -> String {
        let isAr = language == "ar"

        switch kind {
        case .welcomeEvening:
            let steps = ctx.steps ?? 0
            return isAr
                ? "مشيت \(steps) خطوة. شفتك اليوم — باجر راح أبدي أحجيك عدل."
                : "I saw you today — \(steps) steps. Tomorrow we start talking properly."

        case .morningBrief:
            let sleep = ctx.sleepHours.map { String(format: "%.1f", $0) } ?? "?"
            return isAr
                ? "نمت \(sleep) ساعة. الجسم جاهز اليوم."
                : "You slept \(sleep)h. Your body is ready today."

        case .paceSpike:
            return isAr
                ? "خل أحسبلك — افتحلك تمرين مشي رسمي؟ Zone 2."
                : "Want to log a real walk? Let me track Zone 2."

        case .runDetected:
            return isAr
                ? "إذا تريد Zone 2 خل أسجلها."
                : "Let me record this as Zone 2 if you want."

        case .inactivityGap:
            return isAr
                ? "قوم 5 دقايق بس — مشي خفيف."
                : "Stand up for 5 minutes — light walk."

        case .sleepDebt:
            let sleep = ctx.sleepHours.map { String(format: "%.1f", $0) } ?? "?"
            return isAr
                ? "نمت \(sleep) ساعة بس. اليوم خفّف الحمل."
                : "Only \(sleep)h of sleep. Take it easy today."

        case .goalApproach:
            let steps = ctx.steps ?? 0
            return isAr
                ? "مشيت \(steps) خطوة — قربت."
                : "\(steps) steps — almost there."

        case .workoutCompleted:
            let cal = ctx.calories ?? 0
            return isAr
                ? "\(cal) سعرة. هذا اللي يحرق الدهون."
                : "\(cal) calories burned. That's how fat goes."

        case .featureRevealSmartWake:
            return isAr
                ? "خل أحسبلك أحسن وقت تصحى — Smart Wake."
                : "Let me calculate your best wake time — Smart Wake."

        case .featureRevealKitchen:
            return isAr
                ? "افتح الكاميرا على ثلاجتك وخل أكتبلك أكلة."
                : "Point your camera at the fridge — I'll write a meal."

        case .featureRevealZone2:
            return isAr
                ? "Zone 2 جاهز — تمرين القلب الذكي."
                : "Zone 2 is ready — smart cardio coaching."

        case .day6PaywallPreview:
            return isAr
                ? "خل أوريك شنو راح تخسر إذا توقفت."
                : "Let me show you what you'll lose."

        case .day7FinalDay:
            return isAr
                ? "تعال شوف شنو تعلمت عنك هاي السبع أيام."
                : "Come see what I learned about you this week."

        case .day7WeeklyRecapReady:
            return isAr
                ? "افتح التطبيق — تقرير الأسبوع الأول جاهز."
                : "Open the app — your first weekly report is ready."

        case .postTrialWeeklyReport:
            let week = ctx.weekNumber ?? 1
            return isAr
                ? "تقرير الأسبوع \(week) جاهز. تعال شوف."
                : "Week \(week) report is ready."
        }
    }
}
