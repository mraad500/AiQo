import Foundation

/// Phrase banks per Arabic dialect register used to flavor short notification copy.
enum DialectLibrary {

    enum Dialect: String, Sendable, CaseIterable {
        case iraqi
        case gulf
        case levantine
        case msa
    }

    enum Context: String, Sendable, CaseIterable {
        case greeting
        case encouragement
        case gentleReminder
        case celebration
        case concern
        case farewell
        case acknowledgment
        case checkIn
        case recovery
    }

    nonisolated static func phrase(dialect: Dialect, context: Context) -> String {
        let options = bank(dialect: dialect, context: context)
        return options.randomElement() ?? fallback(for: context)
    }

    nonisolated private static func bank(dialect: Dialect, context: Context) -> [String] {
        switch (dialect, context) {
        case (.iraqi, .greeting):
            return ["هلا حبيبي", "هلا والله", "شلونك اليوم؟"]
        case (.iraqi, .encouragement):
            return ["شد حيلك", "إنت تكدر", "مو صعبة عليك"]
        case (.iraqi, .gentleReminder):
            return ["بس تذكير صغير", "خفيف خفيف", "لا تنسى"]
        case (.iraqi, .celebration):
            return ["ها بطل!", "هذا اللي أقصده", "قويّة هاي"]
        case (.iraqi, .concern):
            return ["خير إن شاء الله", "شنو صاير؟", "مقلقانّي عليك"]
        case (.iraqi, .farewell):
            return ["دير بالك", "بسلامة", "الله وياك"]
        case (.iraqi, .acknowledgment):
            return ["فهمتك", "عيني", "سامعك"]
        case (.iraqi, .checkIn):
            return ["شلونك من أمس؟", "شكو اليوم؟", "تعبان لو بخير؟"]
        case (.iraqi, .recovery):
            return ["ريح نفسك", "نام زين", "اليوم يوم راحة"]

        case (.gulf, .greeting):
            return ["هلا بك", "مرحبا", "كيفك اليوم؟"]
        case (.gulf, .encouragement):
            return ["عساك على القوة", "قدها", "أنت لها"]
        case (.gulf, .gentleReminder):
            return ["تذكير بسيط", "لا تنسى", "بس بذكرك"]
        case (.gulf, .celebration):
            return ["ما شاء الله", "يا سلام", "كفو عليك"]
        case (.gulf, .concern):
            return ["كل شي زين؟", "تمام؟", "انتبه على نفسك"]
        case (.gulf, .farewell):
            return ["في أمان الله", "خذ راحتك", "الله يعطيك العافية"]
        case (.gulf, .acknowledgment):
            return ["فاهم", "سمعتك", "تمام"]
        case (.gulf, .checkIn):
            return ["كيف اليوم؟", "تمام من أمس؟", "شلونك الحين؟"]
        case (.gulf, .recovery):
            return ["استريح", "نم زين", "خذ لك يوم هادي"]

        case (.levantine, .greeting):
            return ["أهلين", "مرحبا", "كيفك اليوم؟"]
        case (.levantine, .encouragement):
            return ["شد حالك", "إنت قدها", "منيح هيك"]
        case (.levantine, .gentleReminder):
            return ["بس تذكير", "ما تنسى", "على الهادي"]
        case (.levantine, .celebration):
            return ["برافو عليك", "شو هالطلعة", "عظيم"]
        case (.levantine, .concern):
            return ["كل شي تمام؟", "شو في؟", "احكيلي"]
        case (.levantine, .farewell):
            return ["الله معك", "دير بالك", "بتمنالك الخير"]
        case (.levantine, .acknowledgment):
            return ["فهمت", "تمام", "معك"]
        case (.levantine, .checkIn):
            return ["كيف الحال اليوم؟", "شو الأخبار؟", "كيفك هالفترة؟"]
        case (.levantine, .recovery):
            return ["خد راحتك", "نم منيح", "اليوم ريّح"]

        case (.msa, .greeting):
            return ["السلام عليكم", "مرحباً", "أهلاً بك"]
        case (.msa, .encouragement):
            return ["أنت قادر", "استمر", "خطوتك مهمة"]
        case (.msa, .gentleReminder):
            return ["تذكير لطيف", "لا تنس", "تنبيه بسيط"]
        case (.msa, .celebration):
            return ["أحسنت", "رائع", "إنجاز جميل"]
        case (.msa, .concern):
            return ["هل كل شيء بخير؟", "هل أنت بخير؟", "أطمئن عليك"]
        case (.msa, .farewell):
            return ["إلى اللقاء", "دمت بخير", "في أمان الله"]
        case (.msa, .acknowledgment):
            return ["فهمت", "وصلت الفكرة", "أفهمك"]
        case (.msa, .checkIn):
            return ["كيف حالك اليوم؟", "كيف تسير الأمور؟", "كيف تشعر الآن؟"]
        case (.msa, .recovery):
            return ["خذ قسطاً من الراحة", "استرح اليوم", "نم جيداً"]
        }
    }

    nonisolated private static func fallback(for context: Context) -> String {
        switch context {
        case .greeting:
            return "السلام عليكم"
        case .encouragement:
            return "استمر، أنت قادر"
        case .gentleReminder:
            return "تذكير لطيف"
        case .celebration:
            return "أحسنت"
        case .concern:
            return "هل كل شيء بخير؟"
        case .farewell:
            return "إلى اللقاء"
        case .acknowledgment:
            return "فهمت"
        case .checkIn:
            return "كيف حالك اليوم؟"
        case .recovery:
            return "خذ قسطاً من الراحة"
        }
    }
}
