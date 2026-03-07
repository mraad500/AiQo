import Foundation
import HealthKit

struct SleepStageData: Identifiable, Equatable, Sendable {
    enum Stage: String, CaseIterable, Identifiable, Sendable {
        case awake = "Awake"
        case rem = "REM"
        case core = "Core"
        case deep = "Deep"

        var id: String { rawValue }

        var sortIndex: Int {
            switch self {
            case .deep:
                return 0
            case .core:
                return 1
            case .rem:
                return 2
            case .awake:
                return 3
            }
        }
    }

    let stage: Stage
    let duration: TimeInterval
    let startDate: Date
    let endDate: Date

    init(stage: Stage, startDate: Date, endDate: Date) {
        self.stage = stage
        self.startDate = startDate
        self.endDate = endDate
        self.duration = endDate.timeIntervalSince(startDate)
    }

    var id: String {
        "\(stage.rawValue)-\(startDate.timeIntervalSinceReferenceDate)-\(endDate.timeIntervalSinceReferenceDate)"
    }
}

enum SleepStageFetchError: LocalizedError {
    case healthDataUnavailable
    case sleepAnalysisUnavailable
    case authorizationDenied

    var errorDescription: String? {
        switch self {
        case .healthDataUnavailable:
            return "Health data is not available on this device."
        case .sleepAnalysisUnavailable:
            return "Sleep Analysis is not available in HealthKit."
        case .authorizationDenied:
            return "Sleep access was not granted."
        }
    }
}

extension HealthKitManager {
    func requestSleepAuthorizationIfNeeded() async throws -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw SleepStageFetchError.healthDataUnavailable
        }

        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw SleepStageFetchError.sleepAnalysisUnavailable
        }

        let store = HKHealthStore()
        try await store.requestAuthorization(toShare: [], read: Set([sleepType]))
        return true
    }

    func fetchSleepStagesForLastNight(
        now: Date = Date(),
        calendar: Calendar = .current
    ) async throws -> [SleepStageData] {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw SleepStageFetchError.healthDataUnavailable
        }

        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw SleepStageFetchError.sleepAnalysisUnavailable
        }

        let queryWindow = lastNightQueryWindow(now: now, calendar: calendar)
        let predicate = HKQuery.predicateForSamples(
            withStart: queryWindow.start,
            end: queryWindow.end,
            options: []
        )
        let sortDescriptors = [
            NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        ]

        let store = HKHealthStore()
        let samples: [HKCategorySample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: sortDescriptors
            ) { _, rawSamples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(returning: (rawSamples as? [HKCategorySample]) ?? [])
            }

            store.execute(query)
        }

        let parsedSamples = samples.compactMap { parseSleepSample($0, constrainedTo: queryWindow) }
        guard !parsedSamples.isEmpty else { return [] }

        let mergedSegments = dominantSleepSession(from: parsedSamples, gapThreshold: 90 * 60)
        return mergedSegments.map {
            SleepStageData(stage: $0.stage, startDate: $0.startDate, endDate: $0.endDate)
        }
    }

    private func lastNightQueryWindow(now: Date, calendar: Calendar) -> DateInterval {
        let dayStart = calendar.startOfDay(for: now)
        let eveningStart = calendar.date(byAdding: .hour, value: -6, to: dayStart)
            ?? dayStart.addingTimeInterval(-21_600)
        let morningCap = calendar.date(byAdding: .hour, value: 14, to: dayStart)
            ?? dayStart.addingTimeInterval(50_400)
        let effectiveEnd = min(morningCap, now)
        return DateInterval(start: eveningStart, end: max(effectiveEnd, eveningStart.addingTimeInterval(1)))
    }

    private func parseSleepSample(
        _ sample: HKCategorySample,
        constrainedTo queryWindow: DateInterval
    ) -> ParsedSleepSample? {
        guard let resolution = SleepStageData.Stage.resolved(from: sample.value) else {
            return nil
        }

        let clampedStart = max(sample.startDate, queryWindow.start)
        let clampedEnd = min(sample.endDate, queryWindow.end)
        guard clampedEnd > clampedStart else { return nil }

        return ParsedSleepSample(
            stage: resolution.stage,
            fidelity: resolution.fidelity,
            sourceIdentifier: sample.sourceRevision.source.bundleIdentifier,
            startDate: clampedStart,
            endDate: clampedEnd
        )
    }

    private func dominantSleepSession(
        from parsedSamples: [ParsedSleepSample],
        gapThreshold: TimeInterval
    ) -> [SleepStageSegment] {
        let groupedBySource = Dictionary(grouping: parsedSamples, by: \.sourceIdentifier)
        let candidates = groupedBySource.compactMap { _, sourceSamples in
            sessionCandidate(from: sourceSamples, gapThreshold: gapThreshold)
        }

        guard let bestCandidate = candidates.max(by: { lhs, rhs in
            if lhs.asleepDuration == rhs.asleepDuration {
                return lhs.endDate < rhs.endDate
            }
            return lhs.asleepDuration < rhs.asleepDuration
        }) else {
            return []
        }

        return bestCandidate.segments
    }

    private func sessionCandidate(
        from sourceSamples: [ParsedSleepSample],
        gapThreshold: TimeInterval
    ) -> SleepSessionCandidate? {
        let filteredSamples = preferredFidelitySamples(from: sourceSamples)
        let clusteredSamples = bestCluster(in: filteredSamples, gapThreshold: gapThreshold)
        let mergedSegments = mergeContiguousSegments(from: clusteredSamples)

        guard !mergedSegments.isEmpty else { return nil }

        let asleepDuration = mergedSegments
            .filter { $0.stage != .awake }
            .reduce(0) { $0 + $1.duration }

        return SleepSessionCandidate(
            segments: mergedSegments,
            asleepDuration: asleepDuration,
            endDate: mergedSegments.last?.endDate ?? .distantPast
        )
    }

    private func preferredFidelitySamples(from sourceSamples: [ParsedSleepSample]) -> [ParsedSleepSample] {
        let hasDetailedSleepStages = sourceSamples.contains {
            $0.fidelity == .detailed && $0.stage != .awake
        }

        return sourceSamples
            .filter { !hasDetailedSleepStages || $0.fidelity == .detailed }
            .sorted {
                if $0.startDate == $1.startDate {
                    return $0.endDate < $1.endDate
                }
                return $0.startDate < $1.startDate
            }
    }

    private func bestCluster(
        in sourceSamples: [ParsedSleepSample],
        gapThreshold: TimeInterval
    ) -> [ParsedSleepSample] {
        guard let firstSample = sourceSamples.first else { return [] }

        var clusters: [[ParsedSleepSample]] = []
        var currentCluster: [ParsedSleepSample] = [firstSample]
        var clusterEnd = firstSample.endDate

        for sample in sourceSamples.dropFirst() {
            let gap = sample.startDate.timeIntervalSince(clusterEnd)
            if gap <= gapThreshold {
                currentCluster.append(sample)
                clusterEnd = max(clusterEnd, sample.endDate)
            } else {
                clusters.append(currentCluster)
                currentCluster = [sample]
                clusterEnd = sample.endDate
            }
        }

        clusters.append(currentCluster)

        return clusters.max(by: { lhs, rhs in
            let lhsScore = sleepScore(for: lhs)
            let rhsScore = sleepScore(for: rhs)

            if lhsScore == rhsScore {
                return (lhs.last?.endDate ?? .distantPast) < (rhs.last?.endDate ?? .distantPast)
            }

            return lhsScore < rhsScore
        }) ?? []
    }

    private func sleepScore(for samples: [ParsedSleepSample]) -> TimeInterval {
        mergeContiguousSegments(from: samples)
            .filter { $0.stage != .awake }
            .reduce(0) { $0 + $1.duration }
    }

    private func mergeContiguousSegments(
        from samples: [ParsedSleepSample],
        tolerance: TimeInterval = 5 * 60
    ) -> [SleepStageSegment] {
        guard let firstSample = samples.first else { return [] }

        var mergedSegments: [SleepStageSegment] = []
        var currentSegment = SleepStageSegment(
            stage: firstSample.stage,
            startDate: firstSample.startDate,
            endDate: firstSample.endDate
        )

        for sample in samples.dropFirst() {
            if sample.stage == currentSegment.stage,
               sample.startDate <= currentSegment.endDate.addingTimeInterval(tolerance) {
                currentSegment.endDate = max(currentSegment.endDate, sample.endDate)
                continue
            }

            if sample.startDate < currentSegment.endDate {
                if sample.stage == currentSegment.stage {
                    currentSegment.endDate = max(currentSegment.endDate, sample.endDate)
                    continue
                }

                if sample.startDate > currentSegment.startDate {
                    currentSegment.endDate = sample.startDate
                    if currentSegment.duration > 0 {
                        mergedSegments.append(currentSegment)
                    }
                }

                currentSegment = SleepStageSegment(
                    stage: sample.stage,
                    startDate: sample.startDate,
                    endDate: max(sample.endDate, currentSegment.endDate)
                )
                continue
            }

            if currentSegment.duration > 0 {
                mergedSegments.append(currentSegment)
            }

            currentSegment = SleepStageSegment(
                stage: sample.stage,
                startDate: sample.startDate,
                endDate: sample.endDate
            )
        }

        if currentSegment.duration > 0 {
            mergedSegments.append(currentSegment)
        }

        return mergedSegments
    }
}

private enum SleepStageFidelity: Sendable {
    case detailed
    case fallback
}

private struct ParsedSleepSample: Sendable {
    let stage: SleepStageData.Stage
    let fidelity: SleepStageFidelity
    let sourceIdentifier: String
    let startDate: Date
    let endDate: Date
}

private struct SleepStageSegment: Sendable {
    let stage: SleepStageData.Stage
    let startDate: Date
    var endDate: Date

    var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }
}

private struct SleepSessionCandidate: Sendable {
    let segments: [SleepStageSegment]
    let asleepDuration: TimeInterval
    let endDate: Date
}

private extension SleepStageData.Stage {
    static func resolved(from rawValue: Int) -> (stage: SleepStageData.Stage, fidelity: SleepStageFidelity)? {
        let categoryValue = HKCategoryValueSleepAnalysis(rawValue: rawValue)

        if #available(iOS 16.0, *) {
            switch categoryValue {
            case .awake?:
                return (.awake, .detailed)
            case .asleepREM?:
                return (.rem, .detailed)
            case .asleepCore?:
                return (.core, .detailed)
            case .asleepDeep?:
                return (.deep, .detailed)
            case .asleep?, .asleepUnspecified?:
                return (.core, .fallback)
            default:
                return nil
            }
        } else {
            switch categoryValue {
            case .awake?:
                return (.awake, .detailed)
            case .asleep?:
                return (.core, .fallback)
            default:
                return nil
            }
        }
    }
}
