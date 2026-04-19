import Foundation

/// Bilingual notification templates. BATCH 6 ships a minimal set;
/// persona-aware variants arrive in BATCH 7.
public enum TemplateLibrary {

    public struct Template: Sendable {
        public let title: String
        public let body: String

        public nonisolated init(title: String, body: String) {
            self.title = title
            self.body = body
        }
    }

    public nonisolated static func template(
        for kind: NotificationKind,
        language: String = "ar"
    ) -> Template {
        switch (kind, language) {
        case (.morningKickoff, "ar"):
            return Template(title: "صباحك نور", body: "جاهز لخطواتك اليوم؟")
        case (.morningKickoff, _):
            return Template(title: "Good morning", body: "Ready for today's steps?")

        case (.inactivityNudge, "ar"):
            return Template(title: "حركة خفيفة؟", body: "خطوة صغيرة أحسن من ولا خطوة.")
        case (.inactivityNudge, _):
            return Template(title: "Quick move?", body: "A small step beats no step.")

        case (.sleepDebtAcknowledgment, "ar"):
            return Template(title: "نومك قليل", body: "بالك مرتاح؟ خذ وقتك اليوم.")
        case (.sleepDebtAcknowledgment, _):
            return Template(title: "Low sleep", body: "Take it easy today.")

        case (.personalRecord, "ar"):
            return Template(title: "رقم شخصي جديد! 🔥", body: "كسرت رقمك اليوم. فخور فيك.")
        case (.personalRecord, _):
            return Template(title: "New PR!", body: "You crushed it today.")

        case (.memoryCallback, "ar"):
            return Template(title: "تذكرت شي", body: "رح أشارك وياك شي من قبل.")
        case (.memoryCallback, _):
            return Template(title: "Remembering", body: "Something on my mind.")

        case (.recoveryReminder, "ar"):
            return Template(title: "يوم راحة", body: "جسمك يحتاج استراحة. استمع له.")
        case (.recoveryReminder, _):
            return Template(title: "Rest day", body: "Your body needs rest today.")

        case (.ramadanMindful, "ar"):
            return Template(title: "رمضان مبارك", body: "خذ نفسك ولا تثقل على روحك.")
        case (.ramadanMindful, _):
            return Template(title: "Ramadan Mubarak", body: "Be gentle with yourself.")

        case (.eidCelebration, "ar"):
            return Template(title: "عيد مبارك 🎉", body: "كل سنة وأنت بخير.")
        case (.eidCelebration, _):
            return Template(title: "Eid Mubarak", body: "Wishing you joy today.")

        case (.jumuahSpecial, "ar"):
            return Template(title: "جمعة مباركة", body: "يوم هادئ. خذ وقتك.")
        case (.jumuahSpecial, _):
            return Template(title: "Blessed Friday", body: "Calm day. Take your time.")

        case (.streakRisk, "ar"):
            return Template(title: "سلسلتك", body: "يمكن تكملها بخطوة وحدة بعد.")
        case (.streakRisk, _):
            return Template(title: "Streak at risk", body: "One move could save it.")

        case (.moodShift, "ar"):
            return Template(title: "شلونك اليوم؟", body: "لاحظت شي. تحب نتكلم؟")
        case (.moodShift, _):
            return Template(title: "Checking in", body: "Want to talk?")

        case (.engagementMomentum, "ar"):
            return Template(title: "شكلك بخير", body: "استمر على هالإيقاع.")
        case (.engagementMomentum, _):
            return Template(title: "Strong momentum", body: "Keep the rhythm going.")

        case (.emotionalFollowUp, "ar"):
            return Template(title: "قاعد أفكر فيك", body: "آخر مرة كنت زعلان شوي. شلونك الحين؟")
        case (.emotionalFollowUp, _):
            return Template(title: "Checking in", body: "How are you feeling now?")

        case (.relationshipCheckIn, "ar"):
            return Template(title: "شخص مهم", body: "صار وقت من آخر ما ذكرته.")
        case (.relationshipCheckIn, _):
            return Template(title: "Someone important", body: "It's been a while.")

        case (.circadianNudge, "ar"):
            return Template(title: "وقت النوم", body: "يوم طويل. جسمك يحتاج راحة.")
        case (.circadianNudge, _):
            return Template(title: "Wind down", body: "Your body needs rest.")

        case (.disengagement, "ar"):
            return Template(title: "فيك لحد هسه؟", body: "أنا هنا لو احتجتني.")
        case (.disengagement, _):
            return Template(title: "Still with me?", body: "I'm here when you need me.")

        default:
            return (language == "ar")
                ? Template(title: "كابتن حمودي", body: "عندي شي إلك.")
                : Template(title: "Captain", body: "I have something for you.")
        }
    }
}
