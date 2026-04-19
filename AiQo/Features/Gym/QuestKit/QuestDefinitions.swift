import Foundation

enum QuestDefinitions {
    /// Base quest catalog — every stage's quests EXCEPT the flag-gated Stage 2 slot 3.
    /// `QuestDefinitions.all` composes this with whichever Stage 2 slot 3 quest the
    /// `LEARNING_SPARK_STAGE2_ENABLED` / `PLANK_LADDER_CHALLENGE_ENABLED` flag pair
    /// resolves to via `stage2Slot3Quest`.
    static let baseDefinitions: [QuestDefinition] = [
        // Stage 1
        .init(
            id: "s1q1",
            stageIndex: 1,
            questIndex: 1,
            title: "Kindness Spark (Bonus)",
            type: .oneTime,
            source: .manual,
            tiers: [
                .singleMetric(value: 1, unit: .count),
                .singleMetric(value: 1, unit: .count),
                .singleMetric(value: 1, unit: .count)
            ],
            deepLinkAction: nil,
            metricAKey: .manualCount,
            metricBKey: .none,
            streakDailyTargetA: nil,
            streakDailyTargetB: nil
        ),
        .init(
            id: QuestDefinition.learningSparkQuestID,
            stageIndex: 1,
            questIndex: 2,
            title: "Learning Spark",
            type: .oneTime,
            source: .learning,
            tiers: [
                .singleMetric(value: 1, unit: .count),
                .singleMetric(value: 1, unit: .count),
                .singleMetric(value: 1, unit: .count)
            ],
            deepLinkAction: .openLearningCourse,
            metricAKey: .learningCertificate,
            metricBKey: .none,
            streakDailyTargetA: nil,
            streakDailyTargetB: nil,
            rewardImageOverride: "First.Learning.Challenge.Award"
        ),
        .init(
            id: "s1q4",
            stageIndex: 1,
            questIndex: 3,
            title: "Zone 2 Pulse (Cumulative)",
            type: .cumulative,
            source: .workout,
            tiers: [
                .singleMetric(value: 20, unit: .minutes),
                .singleMetric(value: 30, unit: .minutes),
                .singleMetric(value: 40, unit: .minutes)
            ],
            deepLinkAction: nil,
            metricAKey: .zone2Minutes,
            metricBKey: .none,
            streakDailyTargetA: nil,
            streakDailyTargetB: nil,
            rewardImageOverride: "1.4"
        ),
        .init(
            id: "s1q3",
            stageIndex: 1,
            questIndex: 4,
            title: "Recovery Throne (Daily)",
            type: .daily,
            source: .healthkit,
            tiers: [
                .singleMetric(value: 7.0, unit: .hours),
                .singleMetric(value: 7.5, unit: .hours),
                .singleMetric(value: 8.0, unit: .hours)
            ],
            deepLinkAction: nil,
            metricAKey: .sleepHours,
            metricBKey: .none,
            streakDailyTargetA: nil,
            streakDailyTargetB: nil,
            rewardImageOverride: "1.3"
        ),
        .init(
            id: "s1q2",
            stageIndex: 1,
            questIndex: 5,
            title: "Water Spring (Daily)",
            type: .daily,
            source: .water,
            tiers: [
                .singleMetric(value: 2.0, unit: .liters),
                .singleMetric(value: 2.5, unit: .liters),
                .singleMetric(value: 3.0, unit: .liters)
            ],
            deepLinkAction: nil,
            metricAKey: .waterLiters,
            metricBKey: .none,
            streakDailyTargetA: nil,
            streakDailyTargetB: nil,
            rewardImageOverride: "1.2"
        ),

        // Stage 2
        .init(
            id: "s2q1",
            stageIndex: 2,
            questIndex: 1,
            title: "Vision Machine Accuracy (Camera)",
            type: .oneTime,
            source: .camera,
            tiers: [
                .dualMetric(valueA: 10, unitA: .count, valueB: 70, unitB: .percent),
                .dualMetric(valueA: 15, unitA: .count, valueB: 85, unitB: .percent),
                .dualMetric(valueA: 20, unitA: .count, valueB: 100, unitB: .percent)
            ],
            deepLinkAction: nil,
            metricAKey: .pushupReps,
            metricBKey: .cameraAccuracy,
            streakDailyTargetA: nil,
            streakDailyTargetB: nil
        ),
        .init(
            id: "s2q2",
            stageIndex: 2,
            questIndex: 2,
            title: "Move in One Day",
            type: .daily,
            source: .healthkit,
            tiers: [
                .singleMetric(value: 3, unit: .kilometers),
                .singleMetric(value: 5, unit: .kilometers),
                .singleMetric(value: 6, unit: .kilometers)
            ],
            deepLinkAction: nil,
            metricAKey: .distanceKM,
            metricBKey: .none,
            streakDailyTargetA: nil,
            streakDailyTargetB: nil
        ),
        // NOTE: Stage 2 slot 3 (questIndex: 3) was "s2q3" Plank Ladder; it's now
        // extracted as a named `plankLadderQuest` and composed into the public
        // `all` catalog via `stage2Slot3Quest` (flag-gated). See below.
        .init(
            id: "s2q4",
            stageIndex: 2,
            questIndex: 4,
            title: "Gratitude Session",
            type: .daily,
            source: .timer,
            tiers: [
                .singleMetric(value: 2, unit: .minutes),
                .singleMetric(value: 3, unit: .minutes),
                .singleMetric(value: 5, unit: .minutes)
            ],
            deepLinkAction: nil,
            metricAKey: .timerMinutes,
            metricBKey: .none,
            streakDailyTargetA: nil,
            streakDailyTargetB: nil
        ),
        .init(
            id: "s2q5",
            stageIndex: 2,
            questIndex: 5,
            title: "Fuel Streak",
            type: .streak,
            source: .water,
            tiers: [
                .singleMetric(value: 1, unit: .days),
                .singleMetric(value: 2, unit: .days),
                .singleMetric(value: 3, unit: .days)
            ],
            deepLinkAction: nil,
            metricAKey: .comboStreakDays,
            metricBKey: .none,
            streakDailyTargetA: 2.0,
            streakDailyTargetB: nil
        ),

        // Stage 3
        .init(
            id: "s3q1",
            stageIndex: 3,
            questIndex: 1,
            title: "نسبة هدف الحركة",
            type: .daily,
            source: .healthkit,
            tiers: [
                .singleMetric(value: 70, unit: .percent),
                .singleMetric(value: 90, unit: .percent),
                .singleMetric(value: 100, unit: .percent)
            ],
            deepLinkAction: nil,
            metricAKey: .movePercent,
            metricBKey: .none,
            streakDailyTargetA: nil,
            streakDailyTargetB: nil
        ),
        .init(
            id: "s3q2",
            stageIndex: 3,
            questIndex: 2,
            title: "بناء الضغط",
            type: .cumulative,
            source: .manual,
            tiers: [
                .singleMetric(value: 20, unit: .count),
                .singleMetric(value: 40, unit: .count),
                .singleMetric(value: 50, unit: .count)
            ],
            deepLinkAction: nil,
            metricAKey: .manualCount,
            metricBKey: .none,
            streakDailyTargetA: nil,
            streakDailyTargetB: nil
        ),
        .init(
            id: "s3q3",
            stageIndex: 3,
            questIndex: 3,
            title: "حارس زون 2",
            type: .cumulative,
            source: .workout,
            tiers: [
                .singleMetric(value: 30, unit: .minutes),
                .singleMetric(value: 45, unit: .minutes),
                .singleMetric(value: 60, unit: .minutes)
            ],
            deepLinkAction: nil,
            metricAKey: .zone2Minutes,
            metricBKey: .none,
            streakDailyTargetA: nil,
            streakDailyTargetB: nil
        ),
        .init(
            id: "s3q4",
            stageIndex: 3,
            questIndex: 4,
            title: "سلسلة التعافي",
            type: .streak,
            source: .healthkit,
            tiers: [
                .singleMetric(value: 1, unit: .days),
                .singleMetric(value: 2, unit: .days),
                .singleMetric(value: 3, unit: .days)
            ],
            deepLinkAction: nil,
            metricAKey: .comboStreakDays,
            metricBKey: .none,
            streakDailyTargetA: 7,
            streakDailyTargetB: nil
        ),
        .init(
            id: "s3q5",
            stageIndex: 3,
            questIndex: 5,
            title: "ساعد شخصين (مكافأة)",
            type: .weekly,
            source: .manual,
            tiers: [
                .singleMetric(value: 1, unit: .count),
                .singleMetric(value: 2, unit: .count),
                .singleMetric(value: 2, unit: .count)
            ],
            deepLinkAction: nil,
            metricAKey: .manualCount,
            metricBKey: .none,
            streakDailyTargetA: nil,
            streakDailyTargetB: nil
        ),

        // Stage 4
        .init(
            id: "s4q1",
            stageIndex: 4,
            questIndex: 1,
            title: "الخطوات",
            type: .daily,
            source: .healthkit,
            tiers: [
                .singleMetric(value: 8000, unit: .count),
                .singleMetric(value: 10000, unit: .count),
                .singleMetric(value: 12000, unit: .count)
            ],
            deepLinkAction: nil,
            metricAKey: .steps,
            metricBKey: .none,
            streakDailyTargetA: nil,
            streakDailyTargetB: nil
        ),
        .init(
            id: "s4q2",
            stageIndex: 4,
            questIndex: 2,
            title: "سلم البلانك",
            type: .cumulative,
            source: .timer,
            tiers: [
                .singleMetric(value: 60, unit: .seconds),
                .singleMetric(value: 120, unit: .seconds),
                .singleMetric(value: 180, unit: .seconds)
            ],
            deepLinkAction: nil,
            metricAKey: .timerSeconds,
            metricBKey: .none,
            streakDailyTargetA: nil,
            streakDailyTargetB: nil
        ),
        .init(
            id: "s4q3",
            stageIndex: 4,
            questIndex: 3,
            title: "ضغط بالرؤية (كاميرا)",
            type: .oneTime,
            source: .camera,
            tiers: [
                .dualMetric(valueA: 15, unitA: .count, valueB: 70, unitB: .percent),
                .dualMetric(valueA: 25, unitA: .count, valueB: 85, unitB: .percent),
                .dualMetric(valueA: 30, unitA: .count, valueB: 100, unitB: .percent)
            ],
            deepLinkAction: nil,
            metricAKey: .pushupReps,
            metricBKey: .cameraAccuracy,
            streakDailyTargetA: nil,
            streakDailyTargetB: nil
        ),
        .init(
            id: "s4q4",
            stageIndex: 4,
            questIndex: 4,
            title: "نسبة هدف الحركة",
            type: .daily,
            source: .healthkit,
            tiers: [
                .singleMetric(value: 80, unit: .percent),
                .singleMetric(value: 100, unit: .percent),
                .singleMetric(value: 110, unit: .percent)
            ],
            deepLinkAction: nil,
            metricAKey: .movePercent,
            metricBKey: .none,
            streakDailyTargetA: nil,
            streakDailyTargetB: nil
        ),
        .init(
            id: "s4q5",
            stageIndex: 4,
            questIndex: 5,
            title: "سلسلة الماء",
            type: .streak,
            source: .water,
            tiers: [
                .singleMetric(value: 2, unit: .days),
                .singleMetric(value: 3, unit: .days),
                .singleMetric(value: 4, unit: .days)
            ],
            deepLinkAction: nil,
            metricAKey: .comboStreakDays,
            metricBKey: .none,
            streakDailyTargetA: 2.0,
            streakDailyTargetB: nil,
            streakTierTargetsA: [2.0, 2.5, 3.0]
        ),

        // Stage 5
        .init(
            id: "s5q1",
            stageIndex: 5,
            questIndex: 1,
            title: "سلسلة زون 2",
            type: .streak,
            source: .workout,
            tiers: [
                .singleMetric(value: 2, unit: .days),
                .singleMetric(value: 3, unit: .days),
                .singleMetric(value: 4, unit: .days)
            ],
            deepLinkAction: nil,
            metricAKey: .comboStreakDays,
            metricBKey: .none,
            streakDailyTargetA: 25,
            streakDailyTargetB: nil,
            streakTierTargetsA: [25, 30, 35]
        ),
        .init(
            id: "s5q2",
            stageIndex: 5,
            questIndex: 2,
            title: "بناء الضغط",
            type: .cumulative,
            source: .manual,
            tiers: [
                .singleMetric(value: 40, unit: .count),
                .singleMetric(value: 60, unit: .count),
                .singleMetric(value: 70, unit: .count)
            ],
            deepLinkAction: nil,
            metricAKey: .manualCount,
            metricBKey: .none,
            streakDailyTargetA: nil,
            streakDailyTargetB: nil
        ),
        .init(
            id: "s5q3",
            stageIndex: 5,
            questIndex: 3,
            title: "سلسلة الخطوات",
            type: .streak,
            source: .healthkit,
            tiers: [
                .singleMetric(value: 2, unit: .days),
                .singleMetric(value: 3, unit: .days),
                .singleMetric(value: 4, unit: .days)
            ],
            deepLinkAction: nil,
            metricAKey: .comboStreakDays,
            metricBKey: .none,
            streakDailyTargetA: 8000,
            streakDailyTargetB: nil,
            streakTierTargetsA: [8000, 10000, 10000]
        ),
        .init(
            id: "s5q4",
            stageIndex: 5,
            questIndex: 4,
            title: "جلسة صفاء",
            type: .daily,
            source: .timer,
            tiers: [
                .singleMetric(value: 3, unit: .minutes),
                .singleMetric(value: 5, unit: .minutes),
                .singleMetric(value: 7, unit: .minutes)
            ],
            deepLinkAction: nil,
            metricAKey: .timerMinutes,
            metricBKey: .none,
            streakDailyTargetA: nil,
            streakDailyTargetB: nil
        ),
        .init(
            id: "s5q5",
            stageIndex: 5,
            questIndex: 5,
            title: "ساعد 3 غرباء (مكافأة)",
            type: .weekly,
            source: .manual,
            tiers: [
                .singleMetric(value: 1, unit: .count),
                .singleMetric(value: 2, unit: .count),
                .singleMetric(value: 3, unit: .count)
            ],
            deepLinkAction: nil,
            metricAKey: .manualCount,
            metricBKey: .none,
            streakDailyTargetA: nil,
            streakDailyTargetB: nil
        ),

        // Stage 6
        .init(
            id: "s6q1",
            stageIndex: 6,
            questIndex: 1,
            title: "دقة الرؤية المطلقة (كاميرا)",
            type: .oneTime,
            source: .camera,
            tiers: [
                .dualMetric(valueA: 30, unitA: .count, valueB: 70, unitB: .percent),
                .dualMetric(valueA: 40, unitA: .count, valueB: 85, unitB: .percent),
                .dualMetric(valueA: 50, unitA: .count, valueB: 100, unitB: .percent)
            ],
            deepLinkAction: nil,
            metricAKey: .pushupReps,
            metricBKey: .cameraAccuracy,
            streakDailyTargetA: nil,
            streakDailyTargetB: nil
        ),
        .init(
            id: "s6q2",
            stageIndex: 6,
            questIndex: 2,
            title: "مسافة ممتدة",
            type: .daily,
            source: .healthkit,
            tiers: [
                .singleMetric(value: 6, unit: .kilometers),
                .singleMetric(value: 8, unit: .kilometers),
                .singleMetric(value: 10, unit: .kilometers)
            ],
            deepLinkAction: nil,
            metricAKey: .distanceKM,
            metricBKey: .none,
            streakDailyTargetA: nil,
            streakDailyTargetB: nil
        ),
        .init(
            id: "s6q3",
            stageIndex: 6,
            questIndex: 3,
            title: "سلسلة الحركة",
            type: .streak,
            source: .healthkit,
            tiers: [
                .singleMetric(value: 2, unit: .days),
                .singleMetric(value: 3, unit: .days),
                .singleMetric(value: 4, unit: .days)
            ],
            deepLinkAction: nil,
            metricAKey: .comboStreakDays,
            metricBKey: .none,
            streakDailyTargetA: 90,
            streakDailyTargetB: nil,
            streakTierTargetsA: [90, 100, 110]
        ),
        .init(
            id: "s6q4",
            stageIndex: 6,
            questIndex: 4,
            title: "بلانك",
            type: .cumulative,
            source: .timer,
            tiers: [
                .singleMetric(value: 120, unit: .seconds),
                .singleMetric(value: 180, unit: .seconds),
                .singleMetric(value: 240, unit: .seconds)
            ],
            deepLinkAction: nil,
            metricAKey: .timerSeconds,
            metricBKey: .none,
            streakDailyTargetA: nil,
            streakDailyTargetB: nil
        ),
        .init(
            id: "s6q5",
            stageIndex: 6,
            questIndex: 5,
            title: "سلسلة النوم",
            type: .streak,
            source: .healthkit,
            tiers: [
                .singleMetric(value: 2, unit: .days),
                .singleMetric(value: 3, unit: .days),
                .singleMetric(value: 4, unit: .days)
            ],
            deepLinkAction: nil,
            metricAKey: .comboStreakDays,
            metricBKey: .none,
            streakDailyTargetA: 7,
            streakDailyTargetB: nil,
            streakTierTargetsA: [7, 7.5, 8]
        ),

        // Stage 7
        .init(
            id: "s7q1",
            stageIndex: 7,
            questIndex: 1,
            title: "نبض القبيلة (الساحة)",
            type: .cumulative,
            source: .social,
            tiers: [
                .singleMetric(value: 1, unit: .count),
                .singleMetric(value: 2, unit: .count),
                .singleMetric(value: 3, unit: .count)
            ],
            deepLinkAction: .openArena,
            metricAKey: .socialInteractions,
            metricBKey: .none,
            streakDailyTargetA: nil,
            streakDailyTargetB: nil
        ),
        .init(
            id: "s7q2",
            stageIndex: 7,
            questIndex: 2,
            title: "زون 2 العظيم",
            type: .cumulative,
            source: .workout,
            tiers: [
                .singleMetric(value: 45, unit: .minutes),
                .singleMetric(value: 60, unit: .minutes),
                .singleMetric(value: 75, unit: .minutes)
            ],
            deepLinkAction: nil,
            metricAKey: .zone2Minutes,
            metricBKey: .none,
            streakDailyTargetA: nil,
            streakDailyTargetB: nil
        ),
        .init(
            id: "s7q3",
            stageIndex: 7,
            questIndex: 3,
            title: "الخطوات",
            type: .daily,
            source: .healthkit,
            tiers: [
                .singleMetric(value: 10000, unit: .count),
                .singleMetric(value: 12000, unit: .count),
                .singleMetric(value: 14000, unit: .count)
            ],
            deepLinkAction: nil,
            metricAKey: .steps,
            metricBKey: .none,
            streakDailyTargetA: nil,
            streakDailyTargetB: nil
        ),
        .init(
            id: "s7q4",
            stageIndex: 7,
            questIndex: 4,
            title: "سلسلة الماء",
            type: .streak,
            source: .water,
            tiers: [
                .singleMetric(value: 3, unit: .days),
                .singleMetric(value: 4, unit: .days),
                .singleMetric(value: 5, unit: .days)
            ],
            deepLinkAction: nil,
            metricAKey: .comboStreakDays,
            metricBKey: .none,
            streakDailyTargetA: 2.5,
            streakDailyTargetB: nil
        ),
        .init(
            id: "s7q5",
            stageIndex: 7,
            questIndex: 5,
            title: "مشاركة إنجاز داخل التطبيق (مكافأة)",
            type: .oneTime,
            source: .share,
            tiers: [
                .singleMetric(value: 1, unit: .count),
                .singleMetric(value: 2, unit: .count),
                .singleMetric(value: 3, unit: .count)
            ],
            deepLinkAction: .openShare,
            metricAKey: .shares,
            metricBKey: .none,
            streakDailyTargetA: nil,
            streakDailyTargetB: nil
        ),

        // Stage 8
        .init(
            id: "s8q1",
            stageIndex: 8,
            questIndex: 1,
            title: "الخطوات",
            type: .daily,
            source: .healthkit,
            tiers: [
                .singleMetric(value: 12000, unit: .count),
                .singleMetric(value: 14000, unit: .count),
                .singleMetric(value: 16000, unit: .count)
            ],
            deepLinkAction: nil,
            metricAKey: .steps,
            metricBKey: .none,
            streakDailyTargetA: nil,
            streakDailyTargetB: nil
        ),
        .init(
            id: "s8q2",
            stageIndex: 8,
            questIndex: 2,
            title: "بناء الضغط",
            type: .cumulative,
            source: .manual,
            tiers: [
                .singleMetric(value: 60, unit: .count),
                .singleMetric(value: 80, unit: .count),
                .singleMetric(value: 100, unit: .count)
            ],
            deepLinkAction: nil,
            metricAKey: .manualCount,
            metricBKey: .none,
            streakDailyTargetA: nil,
            streakDailyTargetB: nil
        ),
        .init(
            id: "s8q3",
            stageIndex: 8,
            questIndex: 3,
            title: "الرؤية المثالية (كاميرا)",
            type: .oneTime,
            source: .camera,
            tiers: [
                .dualMetric(valueA: 40, unitA: .count, valueB: 70, unitB: .percent),
                .dualMetric(valueA: 50, unitA: .count, valueB: 85, unitB: .percent),
                .dualMetric(valueA: 60, unitA: .count, valueB: 100, unitB: .percent)
            ],
            deepLinkAction: nil,
            metricAKey: .pushupReps,
            metricBKey: .cameraAccuracy,
            streakDailyTargetA: nil,
            streakDailyTargetB: nil
        ),
        .init(
            id: "s8q4",
            stageIndex: 8,
            questIndex: 4,
            title: "سلسلة الحركة",
            type: .streak,
            source: .healthkit,
            tiers: [
                .singleMetric(value: 2, unit: .days),
                .singleMetric(value: 3, unit: .days),
                .singleMetric(value: 4, unit: .days)
            ],
            deepLinkAction: nil,
            metricAKey: .comboStreakDays,
            metricBKey: .none,
            streakDailyTargetA: 100,
            streakDailyTargetB: nil
        ),
        .init(
            id: "s8q5",
            stageIndex: 8,
            questIndex: 5,
            title: "سلسلة الامتنان",
            type: .streak,
            source: .timer,
            tiers: [
                .singleMetric(value: 2, unit: .days),
                .singleMetric(value: 3, unit: .days),
                .singleMetric(value: 4, unit: .days)
            ],
            deepLinkAction: nil,
            metricAKey: .comboStreakDays,
            metricBKey: .none,
            streakDailyTargetA: 120,
            streakDailyTargetB: nil
        ),

        // Stage 9
        .init(
            id: "s9q1",
            stageIndex: 9,
            questIndex: 1,
            title: "الحركة في يوم واحد",
            type: .daily,
            source: .healthkit,
            tiers: [
                .singleMetric(value: 110, unit: .percent),
                .singleMetric(value: 130, unit: .percent),
                .singleMetric(value: 150, unit: .percent)
            ],
            deepLinkAction: nil,
            metricAKey: .movePercent,
            metricBKey: .none,
            streakDailyTargetA: nil,
            streakDailyTargetB: nil
        ),
        .init(
            id: "s9q2",
            stageIndex: 9,
            questIndex: 2,
            title: "بلانك",
            type: .cumulative,
            source: .timer,
            tiers: [
                .singleMetric(value: 180, unit: .seconds),
                .singleMetric(value: 240, unit: .seconds),
                .singleMetric(value: 300, unit: .seconds)
            ],
            deepLinkAction: nil,
            metricAKey: .timerSeconds,
            metricBKey: .none,
            streakDailyTargetA: nil,
            streakDailyTargetB: nil
        ),
        .init(
            id: "s9q3",
            stageIndex: 9,
            questIndex: 3,
            title: "الساحة المتقدمة",
            type: .cumulative,
            source: .social,
            tiers: [
                .singleMetric(value: 2, unit: .count),
                .singleMetric(value: 3, unit: .count),
                .singleMetric(value: 5, unit: .count)
            ],
            deepLinkAction: .openArena,
            metricAKey: .socialInteractions,
            metricBKey: .none,
            streakDailyTargetA: nil,
            streakDailyTargetB: nil
        ),
        .init(
            id: "s9q4",
            stageIndex: 9,
            questIndex: 4,
            title: "سلسلة الخطوات",
            type: .streak,
            source: .healthkit,
            tiers: [
                .singleMetric(value: 3, unit: .days),
                .singleMetric(value: 4, unit: .days),
                .singleMetric(value: 5, unit: .days)
            ],
            deepLinkAction: nil,
            metricAKey: .comboStreakDays,
            metricBKey: .none,
            streakDailyTargetA: 10000,
            streakDailyTargetB: nil
        ),
        .init(
            id: "s9q5",
            stageIndex: 9,
            questIndex: 5,
            title: "أثر حقيقي: ساعد 5 غرباء (مكافأة)",
            type: .oneTime,
            source: .manual,
            tiers: [
                .singleMetric(value: 1, unit: .count),
                .singleMetric(value: 3, unit: .count),
                .singleMetric(value: 5, unit: .count)
            ],
            deepLinkAction: nil,
            metricAKey: .manualCount,
            metricBKey: .none,
            streakDailyTargetA: nil,
            streakDailyTargetB: nil
        ),

        // Stage 10
        .init(
            id: "s10q1",
            stageIndex: 10,
            questIndex: 1,
            title: "أسبوع المحارب",
            type: .weekly,
            source: .healthkit,
            tiers: [
                .singleMetric(value: 3, unit: .days),
                .singleMetric(value: 4, unit: .days),
                .singleMetric(value: 5, unit: .days)
            ],
            deepLinkAction: nil,
            metricAKey: .stepDaysInWeek,
            metricBKey: .none,
            streakDailyTargetA: 10000,
            streakDailyTargetB: nil
        ),
        .init(
            id: "s10q2",
            stageIndex: 10,
            questIndex: 2,
            title: "دقة الرؤية الأسطورية (كاميرا)",
            type: .oneTime,
            source: .camera,
            tiers: [
                .dualMetric(valueA: 60, unitA: .count, valueB: 85, unitB: .percent),
                .dualMetric(valueA: 80, unitA: .count, valueB: 95, unitB: .percent),
                .dualMetric(valueA: 100, unitA: .count, valueB: 100, unitB: .percent)
            ],
            deepLinkAction: nil,
            metricAKey: .pushupReps,
            metricBKey: .cameraAccuracy,
            streakDailyTargetA: nil,
            streakDailyTargetB: nil
        ),
        .init(
            id: "s10q3",
            stageIndex: 10,
            questIndex: 3,
            title: "سلسلة التعافي المركبة",
            type: .combo,
            source: .healthkit,
            tiers: [
                .singleMetric(value: 2, unit: .days),
                .singleMetric(value: 3, unit: .days),
                .singleMetric(value: 4, unit: .days)
            ],
            deepLinkAction: nil,
            metricAKey: .comboStreakDays,
            metricBKey: .none,
            streakDailyTargetA: 7,
            streakDailyTargetB: 2.5
        ),
        .init(
            id: "s10q4",
            stageIndex: 10,
            questIndex: 4,
            title: "قلب الأسد (كارديو)",
            type: .cumulative,
            source: .workout,
            tiers: [
                .singleMetric(value: 60, unit: .minutes),
                .singleMetric(value: 90, unit: .minutes),
                .singleMetric(value: 120, unit: .minutes)
            ],
            deepLinkAction: nil,
            metricAKey: .cardioMinutes,
            metricBKey: .none,
            streakDailyTargetA: nil,
            streakDailyTargetB: nil
        ),
        .init(
            id: "s10q5",
            stageIndex: 10,
            questIndex: 5,
            title: "مشاركة \"شارة الأسطورة\" داخل التطبيق (مكافأة)",
            type: .oneTime,
            source: .share,
            tiers: [
                .singleMetric(value: 1, unit: .count),
                .singleMetric(value: 2, unit: .count),
                .singleMetric(value: 3, unit: .count)
            ],
            deepLinkAction: .openShare,
            metricAKey: .shares,
            metricBKey: .none,
            streakDailyTargetA: nil,
            streakDailyTargetB: nil
        )
    ]

    // MARK: - Stage 2 slot 3 — flag-gated variants
    //
    // The Stage 2 challenges list has five slots. Slot 3 (questIndex: 3) historically
    // held "Plank Ladder" (id "s2q3"). Feature flags now resolve one of three variants
    // into the slot at app launch (flag flips require an app restart — QuestEngine.shared
    // caches `stages` at init). All three variants carry `rewardImageOverride: "2.3"`
    // to reuse the existing Plank Ladder shield asset verbatim.

    /// Rollback target — the original Plank Ladder challenge. Preserved fully
    /// compilable. Reached when LEARNING_SPARK_STAGE2_ENABLED is OFF and
    /// PLANK_LADDER_CHALLENGE_ENABLED is ON. Uses the legacy `quests.stage.2.quest.3.*`
    /// localization keys (no override), so "سلم البلانك" / "Plank Ladder" copy stays.
    private static let plankLadderQuest = QuestDefinition(
        id: "s2q3",
        stageIndex: 2,
        questIndex: 3,
        title: "Plank Ladder",
        type: .cumulative,
        source: .timer,
        tiers: [
            .singleMetric(value: 30, unit: .seconds),
            .singleMetric(value: 60, unit: .seconds),
            .singleMetric(value: 90, unit: .seconds)
        ],
        deepLinkAction: nil,
        metricAKey: .timerSeconds,
        metricBKey: .none,
        streakDailyTargetA: nil,
        streakDailyTargetB: nil
    )

    /// Default production Stage 2 slot 3 challenge — Learning Spark Stage 2.
    /// Routes through the existing `source == .learning` dispatch in QuestDetailSheet,
    /// which reads the 5-course catalog via `LearningChallengeRegistry.config(for:)`.
    /// Reuses the Plank Ladder shield asset via `rewardImageOverride: "2.3"`.
    private static let learningSparkStage2Quest = QuestDefinition(
        id: QuestDefinition.learningSparkStage2QuestID,
        stageIndex: 2,
        questIndex: 3,
        title: "Learning Spark",
        type: .oneTime,
        source: .learning,
        tiers: [.singleMetric(value: 1, unit: .count)],
        deepLinkAction: .openLearningCourse,
        metricAKey: .learningCertificate,
        metricBKey: .none,
        streakDailyTargetA: nil,
        streakDailyTargetB: nil,
        rewardImageOverride: "2.3",
        localizedTitleKeyOverride: "learningSpark.stage2.title",
        localizedLevelsKeyOverride: "learningSpark.stage2.levels"
    )

    /// Emergency safety net — reached only when BOTH flags are OFF. Production never
    /// ships this state. Non-interactive card (gated in QuestsView via id check).
    /// Title/levels resolve via Cluster A's `learningSpark.stage2.soon*` localization
    /// keys (Arabic: "قريباً" / English: "Coming Soon" — "Coming Soon" is arguably
    /// better for an English user in a degraded state than a raw Arabic string).
    private static let stage2PlaceholderQuest = QuestDefinition(
        id: QuestDefinition.stage2PlaceholderID,
        stageIndex: 2,
        questIndex: 3,
        title: "قريباً",
        type: .oneTime,
        source: .manual,
        tiers: [.singleMetric(value: 1, unit: .count)],
        deepLinkAction: nil,
        metricAKey: .none,
        metricBKey: .none,
        streakDailyTargetA: nil,
        streakDailyTargetB: nil,
        rewardImageOverride: "2.3",
        localizedTitleKeyOverride: "learningSpark.stage2.soon",
        localizedLevelsKeyOverride: "learningSpark.stage2.soon.subtitle"
    )

    /// Flag-driven slot resolver. Read once per consumer at init time — flag flips
    /// require an app restart to propagate through `QuestEngine.shared.stages`.
    private static var stage2Slot3Quest: QuestDefinition {
        if FeatureFlags.learningSparkStage2Enabled {
            return learningSparkStage2Quest
        } else if FeatureFlags.plankLadderChallengeEnabled {
            return plankLadderQuest
        } else {
            return stage2PlaceholderQuest
        }
    }

    /// Public quest catalog consumed by `QuestEngine`, `QuestSwiftDataStore`, etc.
    /// Converted from `static let` to computed so the flag-gated Stage 2 slot 3
    /// resolves on first read. Downstream caches (QuestEngine.shared) evaluate this
    /// once at init — flag flips require an app restart to fully propagate.
    static var all: [QuestDefinition] {
        baseDefinitions + [stage2Slot3Quest]
    }

    static func stageModels() -> [QuestStageViewModel] {
        let grouped = Dictionary(grouping: all, by: { $0.stageIndex })

        return (1...10).map { stage in
            QuestStageViewModel(
                id: stage,
                titleKey: "quests.stage.\(stage).title",
                tabTitleKey: "quests.stage.\(stage).tab",
                quests: grouped[stage, default: []].sorted(by: { $0.questIndex < $1.questIndex })
            )
        }
    }
}
