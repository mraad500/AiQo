#if DEBUG
import Foundation

enum MockArenaData {

    // MARK: - القبائل

    static func makeTribes() -> [ArenaTribe] {
        let names = ["قبيلة الصقور", "قبيلة النمور", "قبيلة الذئاب", "قبيلة الأسود", "قبيلة الفهود"]
        let creators = ["user_1", "user_6", "user_10", "user_13", "user_16"]

        let memberData: [[(String, String, String, Bool)]] = [
            // الصقور
            [
                ("user_1", "حمودي", "حم", true),
                ("user_2", "سارة", "سا", false),
                ("user_3", "Noah", "NR", false),
                ("user_4", "فيصل", "فص", false),
                ("user_5", "ليان", "لي", false),
            ],
            // النمور
            [
                ("user_6", "خالد", "خل", true),
                ("user_7", "Lara", "LR", false),
                ("user_8", "عبدالله", "عب", false),
                ("user_9", "نوره", "نو", false),
            ],
            // الذئاب
            [
                ("user_10", "ريم", "رم", true),
                ("user_11", "طلال", "طل", false),
                ("user_12", "Emma", "EM", false),
            ],
            // الأسود
            [
                ("user_13", "سلطان", "سل", true),
                ("user_14", "جود", "جو", false),
                ("user_15", "Adam", "AD", false),
            ],
            // الفهود
            [
                ("user_16", "منيرة", "من", true),
                ("user_17", "يزيد", "يز", false),
                ("user_18", "سمر", "سم", false),
            ],
        ]

        var tribes: [ArenaTribe] = []
        for (i, name) in names.enumerated() {
            let tribe = ArenaTribe(name: name, creatorUserID: creators[i])
            var members: [ArenaTribeMember] = []
            for md in memberData[i] {
                let member = ArenaTribeMember(
                    userID: md.0,
                    displayName: md.1,
                    initials: md.2,
                    isCreator: md.3
                )
                member.tribe = tribe
                members.append(member)
            }
            tribe.members = members
            tribes.append(tribe)
        }
        return tribes
    }

    // MARK: - تحدي الأسبوع الحالي

    static func makeCurrentChallenge() -> ArenaWeeklyChallenge {
        let cal = Calendar.current
        let now = Date()
        // أقرب أحد ماضي
        let weekday = cal.component(.weekday, from: now)
        let daysFromSunday = (weekday == 1) ? 0 : (weekday - 1)
        let sunday = cal.date(byAdding: .day, value: -daysFromSunday, to: cal.startOfDay(for: now)) ?? Date()
        let saturday = cal.date(byAdding: .day, value: 6, to: sunday) ?? Date()
        let endOfSaturday = cal.date(bySettingHour: 23, minute: 59, second: 59, of: saturday) ?? Date()

        return ArenaWeeklyChallenge(
            title: "أكثر قبيلة ملتزمة بالتمارين",
            descriptionText: "معدل أيام التمرين لكل فرد بالقبيلة خلال الأسبوع",
            metric: .consistency,
            startDate: sunday,
            endDate: endOfSaturday
        )
    }

    // MARK: - قادة الإمارة (الفايزين الأسبوع الماضي)

    static func makeCurrentLeaders() -> ArenaEmirateLeaders {
        let cal = Calendar.current
        let now = Date()
        let weekday = cal.component(.weekday, from: now)
        let daysFromSunday = (weekday == 1) ? 0 : (weekday - 1)
        let thisSunday = cal.date(byAdding: .day, value: -daysFromSunday, to: cal.startOfDay(for: now)) ?? Date()
        let lastSunday = cal.date(byAdding: .day, value: -7, to: thisSunday) ?? Date()
        let lastSaturday = cal.date(byAdding: .day, value: 6, to: lastSunday) ?? Date()

        let leaders = ArenaEmirateLeaders(
            weekNumber: 12,
            startDate: lastSunday,
            endDate: lastSaturday
        )
        leaders.isDefending = true
        return leaders
    }

    // MARK: - سجل الأمجاد

    static func makeHallOfFame() -> [ArenaHallOfFameEntry] {
        let cal = Calendar.current
        let now = Date()

        return (0..<5).map { weeksAgo in
            let date = cal.date(byAdding: .weekOfYear, value: -(weeksAgo), to: now) ?? Date()
            let data: [(String, String)] = [
                ("قبيلة الصقور", "أكثر التزام"),
                ("قبيلة النمور", "أبطال النوم"),
                ("قبيلة الصقور", "ماشين مع بعض"),
                ("قبيلة الذئاب", "أسبوع الطاقة"),
                ("قبيلة الأسود", "الثبات"),
            ]
            return ArenaHallOfFameEntry(
                weekNumber: 12 - weeksAgo,
                tribeName: data[weeksAgo].0,
                challengeTitle: data[weeksAgo].1,
                date: date
            )
        }
    }

    // MARK: - ترتيب المشاركات

    static let participationScores: [LeaderboardRow] = [
        LeaderboardRow(tribeName: "قبيلة الصقور", score: 87, rank: 1),
        LeaderboardRow(tribeName: "قبيلة النمور", score: 64, rank: 2),
        LeaderboardRow(tribeName: "قبيلة الذئاب", score: 52, rank: 3),
        LeaderboardRow(tribeName: "قبيلة الأسود", score: 41, rank: 4),
        LeaderboardRow(tribeName: "قبيلة الفهود", score: 33, rank: 5),
    ]
}
#endif
