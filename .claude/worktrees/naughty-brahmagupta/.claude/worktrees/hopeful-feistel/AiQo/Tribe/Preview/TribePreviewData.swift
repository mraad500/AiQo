import Foundation

enum TribePreviewData {
    static func sampleTribe(ownerUserId: String = "preview-owner") -> Tribe {
        Tribe(
            id: "preview-tribe",
            name: "قبيلة الهدوء",
            ownerUserId: ownerUserId,
            inviteCode: "AIQO30",
            createdAt: Date().addingTimeInterval(-(60 * 60 * 24 * 12))
        )
    }

    static func sampleMembers(
        currentUserId: String = "preview-self",
        currentUserName: String = "أنت",
        currentUserPrivacy: PrivacyMode = .private,
        ownerUserId: String = "preview-owner",
        ownerDisplayName: String = "القائد"
    ) -> [TribeMember] {
        var items = [
            TribeMember(
                id: currentUserId,
                displayName: currentUserName,
                avatarURL: nil,
                level: ownerUserId == currentUserId ? 18 : 13,
                privacyMode: currentUserPrivacy,
                energyContributionToday: ownerUserId == currentUserId ? 82 : 68
            )
        ]

        if ownerUserId != currentUserId {
            items.append(
                TribeMember(
                    id: ownerUserId,
                    displayName: ownerDisplayName,
                    avatarURL: "Hammoudi5",
                    level: 18,
                    privacyMode: .public,
                    energyContributionToday: 74
                )
            )
        }

        items.append(contentsOf: [
            TribeMember(
                id: "preview-00",
                displayName: "سارة",
                avatarURL: nil,
                level: 9,
                privacyMode: .public,
                energyContributionToday: 44
            ),
            TribeMember(
                id: "preview-01",
                displayName: "عضو خاص",
                avatarURL: nil,
                level: 11,
                privacyMode: .private,
                energyContributionToday: 52
            ),
            TribeMember(
                id: "preview-02",
                displayName: "حيدر",
                avatarURL: nil,
                level: 14,
                privacyMode: .public,
                energyContributionToday: 38
            ),
            TribeMember(
                id: "preview-03",
                displayName: "عضو خاص",
                avatarURL: nil,
                level: 7,
                privacyMode: .private,
                energyContributionToday: 29
            ),
            TribeMember(
                id: "preview-04",
                displayName: "مريم",
                avatarURL: nil,
                level: 12,
                privacyMode: .public,
                energyContributionToday: 31
            ),
            TribeMember(
                id: "preview-05",
                displayName: "عضو خاص",
                avatarURL: nil,
                level: 5,
                privacyMode: .private,
                energyContributionToday: 18
            ),
            TribeMember(
                id: "preview-06",
                displayName: "حسن",
                avatarURL: nil,
                level: 16,
                privacyMode: .public,
                energyContributionToday: 42
            ),
            TribeMember(
                id: "preview-07",
                displayName: "عضو خاص",
                avatarURL: nil,
                level: 8,
                privacyMode: .private,
                energyContributionToday: 24
            )
        ])

        return items
    }

    static func sampleMissions(
        energyProgress: (current: Int, target: Int) = sampleEnergyProgress(),
        now: Date = Date()
    ) -> [TribeMission] {
        [
            TribeMission(
                id: "preview-energy",
                title: "طاقة جماعية",
                targetValue: energyProgress.target,
                progressValue: energyProgress.current,
                endsAt: Calendar.current.date(byAdding: .hour, value: 7, to: now) ?? now
            ),
            TribeMission(
                id: "preview-checkin",
                title: "تجميع 5 مساهمات اليوم",
                targetValue: 5,
                progressValue: 3,
                endsAt: Calendar.current.date(bySettingHour: 12, minute: 45, second: 0, of: now) ?? now
            ),
            TribeMission(
                id: "preview-streak",
                title: "سلسلة حضور هادئة",
                targetValue: 8,
                progressValue: 6,
                endsAt: Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
            )
        ]
    }

    static func sampleEnergyProgress() -> (current: Int, target: Int) {
        (current: 374, target: 500)
    }

    static func sampleEvents(
        members: [TribeMember],
        ownerUserId: String = "preview-owner",
        now: Date = Date()
    ) -> [TribeEvent] {
        let byId = Dictionary(uniqueKeysWithValues: members.map { ($0.id, $0) })

        func displayName(for memberId: String) -> String {
            guard let member = byId[memberId] else { return "عضو" }
            return member.privacyMode == .public ? member.displayName : "عضو"
        }

        return [
            TribeEvent(
                id: "event-1",
                type: .join,
                actorId: ownerUserId,
                actorDisplayName: displayName(for: ownerUserId),
                message: "\(displayName(for: ownerUserId)) أنشأ القبيلة",
                value: nil,
                createdAt: now.addingTimeInterval(-60 * 60 * 4)
            ),
            TribeEvent(
                id: "event-2",
                type: .contribution,
                actorId: "preview-02",
                actorDisplayName: displayName(for: "preview-02"),
                message: "\(displayName(for: "preview-02")) ساهم +20 طاقة",
                value: 20,
                createdAt: now.addingTimeInterval(-60 * 70)
            ),
            TribeEvent(
                id: "event-3",
                type: .spark,
                actorId: "preview-00",
                actorDisplayName: displayName(for: "preview-00"),
                message: "\(displayName(for: "preview-00")) أرسل شرارة إلى \(displayName(for: "preview-06"))",
                value: 2,
                createdAt: now.addingTimeInterval(-60 * 38)
            ),
            TribeEvent(
                id: "event-4",
                type: .contribution,
                actorId: "preview-self",
                actorDisplayName: displayName(for: "preview-self"),
                message: "\(displayName(for: "preview-self")) ساهم +15 طاقة",
                value: 15,
                createdAt: now.addingTimeInterval(-60 * 12)
            ),
            TribeEvent(
                id: "event-5",
                type: .missionCompleted,
                actorId: "system",
                actorDisplayName: "النظام",
                message: "اكتملت مهمة: تجميع 5 مساهمات اليوم",
                value: nil,
                createdAt: now.addingTimeInterval(-60 * 5)
            )
        ]
        .sorted { $0.createdAt > $1.createdAt }
    }
}
