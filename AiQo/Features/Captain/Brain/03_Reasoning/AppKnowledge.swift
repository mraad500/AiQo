import Foundation

/// Static, app-authored knowledge of AiQo's OWN features and screens.
///
/// Why this exists: before this, if the user asked Captain Hamoudi "شنو
/// Peaks؟" / "شلون أستخدم المطبخ؟" / "شنو الفرق بين الاشتراكات؟" the model
/// had zero grounding and would hallucinate — the opposite of a world-class
/// assistant. This is a small, curated, **PII-free constant** catalog plus a
/// deterministic on-device lexical retriever. The selected block rides the
/// trusted cloud-safe string path (like `cloudSafeMemories`) — it is static
/// app copy, so it must NOT be run through `sanitizeText` (that could mangle
/// Arabic feature wording).
///
/// Accuracy contract: every summary here describes a feature that genuinely
/// ships. Keep it factual and conservative — a confidently wrong Captain is
/// worse than a vague one. Tier wording mirrors the official site copy.
struct AppKnowledgeEntry: Sendable {
    /// Stable identifier; also used as the screen-hint boost key.
    let id: String
    /// Deterministic ordering for tie-breaks (lower = earlier).
    let order: Int
    /// Lowercased match terms — Arabic, English, and common variants.
    let keywords: [String]
    /// One concise, accurate passage the Captain can paraphrase (never read
    /// verbatim — the persona layer still owns tone/dialect).
    let summary: String
}

enum AppKnowledge {

    // MARK: - Catalog (only features that genuinely ship)

    static let entries: [AppKnowledgeEntry] = [
        AppKnowledgeEntry(
            id: "captain",
            order: 0,
            keywords: ["captain", "hamoudi", "حمودي", "كابتن", "الكابتن", "المساعد", "الذكاء", "ai", "chat", "دردشة", "محادثة"],
            summary: "كابتن حمّودي هو مدرّب الصحة الذكي داخل AiQo — يتكلّم باللهجة العراقية، يتذكّر أهدافك وتفاصيلك عبر الجلسات، يقرأ بيانات صحتك (خطوات، سعرات، نوم) ويعطيك توجيه شخصي. تكدر تعلّمه قواعد دائمة (مثلاً: بعد كل تمرين حلّله ودزّ إشعار) ويلتزم بيها."
        ),
        AppKnowledgeEntry(
            id: "peaks",
            order: 1,
            keywords: ["peaks", "بيكس", "بيكز", "legendary", "أسطوري", "اسطوري", "التحديات", "تحدي", "مشروع", "رقم قياسي", "record", "16 أسبوع", "اسبوع"],
            summary: "Peaks (التحديات الأسطورية) مشاريع طويلة لكسر رقم قياسي شخصي على مدى أسابيع (قوة/كارديو/تحمّل/صفاء ذهني). الخطة تتدرّج أسبوع بعد أسبوع (حِمل متصاعد، أسبوع استشفاء كل رابع، وtaper بالأخير) وتسجّل أداءك بنقاط تفتيش أسبوعية."
        ),
        AppKnowledgeEntry(
            id: "kitchen",
            order: 2,
            keywords: ["kitchen", "مطبخ", "المطبخ", "alchemy", "ثلاجة", "اكل", "أكل", "طعام", "وجبات", "وجبة", "خطة اكل", "صورة الثلاجة", "fridge", "meal"],
            summary: "المطبخ يخلّيك تصوّر ثلاجتك، يتعرّف على المكوّنات، ويولّد خطة وجبات (فطور/غداء/عشاء) تستعمل اللي عندك أول. إذا تعذّر الاتصال بالذكاء، يعطيك خطة أساسية بديلة ويبيّنلك صراحة إنها بديلة مع زر إعادة محاولة."
        ),
        AppKnowledgeEntry(
            id: "myvibe",
            order: 3,
            keywords: ["vibe", "my vibe", "فايب", "الفايب", "موسيقى", "اغاني", "أغاني", "spotify", "سبوتيفاي", "صوت"],
            summary: "My Vibe يبدّل طاقة الموسيقى حسب وقت اليوم وإيقاعك اليومي (هدوء الصبح، دفعة الظهر، استرخاء الليل) ويتكامل مع Spotify. ملاحظة: ما يتفاعل مع نبض القلب — هو مبني على الوقت/الإيقاع اليومي."
        ),
        AppKnowledgeEntry(
            id: "plans",
            order: 4,
            keywords: ["plan", "plans", "خطة", "خطط", "تمرين", "تمارين", "workout", "جيم", "نادي", "zone 2", "زون", "runner", "كوتشينج"],
            summary: "خطط التمارين تتولّد حسب هدفك ومستواك وتقدر تكون لأيام/أسابيع متعددة، وكل يوم له عضلات ومجاميع/تكرارات محددة. أثناء التمرين أكو منفّذ خطوة بخطوة، وكوتشينج صوتي (ومنه تدريب Zone 2 بمراقبة النبض من الساعة)."
        ),
        AppKnowledgeEntry(
            id: "outdoor_run",
            order: 5,
            keywords: ["run", "running", "ركض", "جري", "هرولة", "outdoor", "gps", "مسار", "route", "مسافة"],
            summary: "الجري الخارجي يتبّع مسارك بالـGPS مع خريطة، مسافة، وتيرة، وارتفاع، ويكمّل التتبّع بالخلفية حتى لو القفل مغلق، وينطيك بطاقة مشاركة بعد الجري."
        ),
        AppKnowledgeEntry(
            id: "learning",
            order: 6,
            keywords: ["learning", "spark", "تعلم", "تعلّم", "كورس", "كورسات", "دورة", "شهادة", "certificate", "edraak", "coursera", "xp", "نقاط"],
            summary: "Learning Spark يقترح كورسات مختارة (إدراك/كورسيرا)، وتقدر ترفع صورة شهادتك ويتم التحقّق منها على الجهاز، وتكسب نقاط XP ترفع مستواك بالملف الشخصي."
        ),
        AppKnowledgeEntry(
            id: "notifications",
            order: 7,
            keywords: ["notification", "notifications", "اشعار", "إشعار", "اشعارات", "تذكير", "تنبيه", "reminder"],
            summary: "الإشعارات استباقية وذكية — توقيتها مبني على إيقاعك وسلوكك وسياقك، وتجيك بمحتوى يفيدك (متابعة هدف، تذكير، تحفيز) مو مجرد تنبيهات عامة. تكدر تتحكّم بيها حسب اشتراكك وتفضيلاتك."
        ),
        AppKnowledgeEntry(
            id: "sleep",
            order: 8,
            keywords: ["sleep", "نوم", "النوم", "أنام", "انام", "استيقاظ", "wake", "نعاس"],
            summary: "تحليل النوm يعطيك تفصيل لمراحل نومك ونصيحة، ويقدر يساعدك بتوقيت استيقاظ أذكى حتى ما تكون ناعس. الكابتن يستعمل بيانات نومك بتوجيهه اليومي."
        ),
        AppKnowledgeEntry(
            id: "water",
            order: 9,
            keywords: ["water", "ماي", "ماء", "مويه", "هيدريشن", "hydration", "شرب"],
            summary: "تتبّع الماي يحسبلك استهلاكك اليومي مقابل هدف، ويذكّرك تشرب، والكابتن ياخذه بالحسبان بتوصياته."
        ),
        AppKnowledgeEntry(
            id: "profile",
            order: 10,
            keywords: ["profile", "بروفايل", "ملف", "حساب", "مستوى", "level", "xp", "نقاط", "تقدم", "صور التقدم", "progress photo"],
            summary: "الملف الشخصي يبيّن مستواك ونقاط XP وتقدّمك. تقدر تحفظ صور تقدّم لمتابعة تغيّر جسمك مع الوقت."
        ),
        AppKnowledgeEntry(
            id: "watch",
            order: 11,
            keywords: ["watch", "ساعة", "آبل ووتش", "apple watch", "ووتش", "نبض حي", "live"],
            summary: "تطبيق Apple Watch المرافق يعطي مقاييس حيّة (حلقات، نبض، تمرين)، تسجيل صوتي سريع، ويكمّل تتبّع التمارين حتى لو الأيفون مو وياك. اختياري — التطبيق يشتغل كامل من الأيفون."
        ),
        AppKnowledgeEntry(
            id: "subscription",
            order: 12,
            keywords: ["subscription", "اشتراك", "الاشتراك", "خطة الاشتراك", "سعر", "free", "مجاني", "pro", "برو", "max", "ماكس", "intelligence", "ترقية", "upgrade", "premium"],
            summary: "Max هو التطبيق الكامل بأساسياته اليومية — الكابتن، الصحة، النادي، الـVibe، والواتش. Intelligence Pro يضيف فوقه طبقة ذكاء أعلى: ذاكرة موسّعة، نموذج أقوى، صوت Premium، خطط تمارين متكيّفة، وPeaks والتحديات الأسطورية الكاملة. أكو تجربة قبل الاشتراك. للتفاصيل الدقيقة افتح شاشة الاشتراك بالتطبيق."
        ),
        AppKnowledgeEntry(
            id: "privacy",
            order: 13,
            keywords: ["privacy", "خصوصية", "بياناتي", "بيانات", "أمان", "consent", "موافقة", "تصدير", "حذف", "data"],
            summary: "AiQo privacy-first: أغلب المعالجة على الجهاز، وأي إرسال للسحابة يمرّ بمعقّم يشيل المعلومات الحسّاسة قبل الإرسال، وتحتاج موافقتك الصريحة لميزات الذكاء السحابي. تقدر تصدّر بياناتك أو تحذفها من الإعدادات."
        ),
        // Overview: catches BROAD "what is this app / what can it do" asks that
        // name no specific feature, so the lexical retriever would otherwise
        // return nil and leave the Captain ungrounded on exactly the question
        // most prone to hallucination. order=14 (highest) so any specific-
        // feature entry always wins a score tie — this only surfaces when
        // nothing more specific matched.
        AppKnowledgeEntry(
            id: "overview",
            order: 14,
            keywords: [
                "aiqo", "ايكو", "ايكيو", "التطبيق", "تطبيق", "تطبيقكم", "البرنامج",
                "شنو يسوي", "شيسوي", "شنو يكدر", "شيكدر", "وش يسوي", "ايش يسوي",
                "شنو هذا", "شنو هو", "عن التطبيق", "ميزات", "مزايا", "خصائص",
                "features", "what is", "what can", "capabilities", "شلون يساعدني",
                "شنو فايدة", " شنو الفرق", "كلشي", "كل شي", "وش هذا"
            ],
            summary: "AiQo نظام تشغيل حيوي-رقمي: محوره كابتن حمّودي (مدرّب ذكي يحجي عراقي يتذكّرك ويقرأ بيانات صحتك). يضمّ خطط تمارين وكوتشينج صوتي وZone 2، تحليل نوم وتوقيت استيقاظ أذكى، المطبخ (تصوّر ثلاجتك ويطلّع خطة وجبات)، Peaks (تحديات أسطورية متدرّجة)، My Vibe (موسيقى حسب إيقاعك)، Learning Spark، تتبّع ماي وخطوات وستريك ونقاط XP، وتطبيق Apple Watch — كله privacy-first. الاشتراك: Max للأساسيات اليومية، وIntelligence Pro يضيف ذكاء وذاكرة أعمق وPeaks الكاملة."
        ),
    ]

    // MARK: - Retrieval (deterministic, on-device, zero-latency)

    /// Returns a compact, prompt-ready block of the entries most relevant to
    /// `message`, or `nil` when nothing is relevant (so the caller can omit
    /// the section entirely — no prompt bloat on unrelated turns).
    ///
    /// Lexical only by design: deterministic, no embedding/cloud cost, and
    /// good enough because the catalog is tiny and the keywords are curated.
    /// `screenHint` (the current screen id, e.g. "kitchen") gives a small
    /// boost so on-screen questions resolve to the right feature.
    static func relevantBlock(
        for message: String,
        screenHint: String? = nil,
        maxEntries: Int = 3,
        charBudget: Int = 900
    ) -> String? {
        let haystack = message.lowercased()
        guard !haystack.isEmpty else { return nil }
        let hint = screenHint?.lowercased()

        let scored: [(entry: AppKnowledgeEntry, score: Int)] = entries.compactMap { entry in
            var score = entry.keywords.reduce(0) { partial, keyword in
                partial + (haystack.contains(keyword.lowercased()) ? 1 : 0)
            }
            if let hint, hint == entry.id || hint.contains(entry.id) || entry.id.contains(hint) {
                score += 1
            }
            return score > 0 ? (entry, score) : nil
        }

        guard !scored.isEmpty else { return nil }

        // Deterministic: higher score first, then stable catalog order.
        let ranked = scored.sorted { lhs, rhs in
            lhs.score != rhs.score ? lhs.score > rhs.score : lhs.entry.order < rhs.entry.order
        }

        var lines: [String] = []
        var used = 0
        for item in ranked.prefix(maxEntries) {
            let line = "• \(item.entry.id): \(item.entry.summary)"
            if used + line.count > charBudget { break }
            used += line.count
            lines.append(line)
        }

        guard !lines.isEmpty else { return nil }

        return """
        APP KNOWLEDGE (authoritative facts about AiQo's own features — use these to answer questions about the app accurately; never invent features or screens that are not listed here; paraphrase in your own voice):
        \(lines.joined(separator: "\n"))
        """
    }
}
