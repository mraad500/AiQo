import UIKit
import HealthKit

// MARK: - HealthKit series (per scope)
extension HomeViewController {

    func loadSeries(for kind: MetricKind,
                    scope: TimeScope,
                    completion: @escaping ([Double], String) -> Void) {

        // MARK: - All Time (Lifetime)
        if scope == .allTime {
            Task { [weak self] in
                guard let self else { return }

                let summary = (try? await self.health.fetchAllTimeSummary()) ?? .zero

                await MainActor.run {
                    switch kind {
                    case .steps:
                        completion([summary.steps], self.format(summary.steps))

                    case .calories:
                        completion([summary.activeKcal], self.format(summary.activeKcal))

                    case .distance:
                        let km = summary.distanceMeters / 1000.0
                        completion([km], String(format: "%.2f km", km))

                    case .sleep:
                        completion([summary.sleepHours], String(format: "%.1f h", summary.sleepHours))

                    case .stand:
                        completion([summary.standHours], String(format: "%.0f h", summary.standHours))

                    case .water:
                        let liters = summary.waterML / 1000.0
                        completion([liters], String(format: "%.1f L", liters))
                    }
                }
            }
            return
        }

        // MARK: - Day / Week / Month / Year
        switch kind {

        case .steps:
            seriesQuantity(.stepCount, unit: .count(), scope: scope) { [weak self] vals, tot in
                guard let self else { return }
                completion(vals, self.format(tot))
            }

        case .calories:
            seriesQuantity(.activeEnergyBurned, unit: .kilocalorie(), scope: scope) { [weak self] vals, tot in
                guard let self else { return }
                completion(vals, self.format(tot))
            }

        case .distance:
            seriesQuantity(.distanceWalkingRunning, unit: .meter(), scope: scope) { vals, tot in
                completion(vals.map { $0 / 1000.0 },
                           String(format: "%.2f km", tot / 1000.0))
            }

        case .sleep:
            seriesSleep(scope: scope) { valsSec, totalSec in
                completion(valsSec.map { $0 / 3600.0 },
                           String(format: "%.1f h", totalSec / 3600.0))
            }

        case .stand:
            seriesStand(scope: scope) { vals, totalHours in
                let percent = min(100.0, (totalHours / 12.0) * 100.0)
                completion(vals, String(format: "%.0f%%", percent))
            }

        case .water:
            seriesQuantity(.dietaryWater,
                           unit: .literUnit(with: .milli),
                           scope: scope) { vals, tot in
                completion(vals.map { $0 / 1000.0 },
                           String(format: "%.1f L", tot / 1000.0))
            }

        default:
            completion([], "—")
        }
    }

    // MARK: - Shared Query: Quantities
    func seriesQuantity(_ id: HKQuantityTypeIdentifier,
                        unit: HKUnit,
                        scope: TimeScope,
                        completion: @escaping ([Double], Double) -> Void) {

        let store = HKHealthStore()
        guard let type = HKObjectType.quantityType(forIdentifier: id) else {
            completion([], 0)
            return
        }

        let now = Date()
        let cal = Calendar.current

        let interval: DateComponents
        let start: Date
        let end: Date = now

        switch scope {
        case .day:
            interval = DateComponents(hour: 1)
            start = cal.startOfDay(for: now)

        case .week:
            interval = DateComponents(day: 1)
            start = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: now))!

        case .month:
            interval = DateComponents(day: 1)
            start = cal.date(byAdding: .day, value: -29, to: cal.startOfDay(for: now))!

        case .year:
            interval = DateComponents(month: 1)
            let comp = cal.dateComponents([.year, .month], from: now)
            start = cal.date(from: DateComponents(year: comp.year! - 1,
                                                  month: comp.month,
                                                  day: 1))!

        case .allTime:
            // should not reach here
            interval = DateComponents(day: 1)
            start = cal.startOfDay(for: now)
        }

        var anchor = cal.startOfDay(for: start)
        if scope == .year {
            anchor = cal.date(from: cal.dateComponents([.year, .month], from: start))!
        }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        let q = HKStatisticsCollectionQuery(quantityType: type,
                                            quantitySamplePredicate: predicate,
                                            options: [.cumulativeSum],
                                            anchorDate: anchor,
                                            intervalComponents: interval)

        q.initialResultsHandler = { _, results, _ in
            var arr: [Double] = []
            var total: Double = 0

            results?.enumerateStatistics(from: start, to: end) { stat, _ in
                let v = stat.sumQuantity()?.doubleValue(for: unit) ?? 0
                arr.append(v)
                total += v
            }

            DispatchQueue.main.async {
                completion(arr, total)
            }
        }

        store.execute(q)
    }

    // MARK: - Sleep Series
    func seriesSleep(scope: TimeScope,
                     completion: @escaping ([Double], Double) -> Void) {

        let store = HKHealthStore()
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            completion([], 0)
            return
        }

        let now = Date()
        let cal = Calendar.current

        let interval: DateComponents
        let start: Date
        let end: Date = now

        switch scope {
        case .day:
            interval = DateComponents(hour: 1)
            start = cal.startOfDay(for: now)

        case .week:
            interval = DateComponents(day: 1)
            start = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: now))!

        case .month:
            interval = DateComponents(day: 1)
            start = cal.date(byAdding: .day, value: -29, to: cal.startOfDay(for: now))!

        case .year:
            interval = DateComponents(month: 1)
            let comp = cal.dateComponents([.year, .month], from: now)
            start = cal.date(from: DateComponents(
                year: comp.year! - 1,
                month: comp.month,
                day: 1
            ))!

        case .allTime:
            interval = DateComponents(month: 1)
            start = Date.distantPast
        }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        let q = HKSampleQuery(sampleType: type,
                              predicate: predicate,
                              limit: HKObjectQueryNoLimit,
                              sortDescriptors: nil) { _, raw, _ in

            let samples = raw as? [HKCategorySample] ?? []
            var buckets: [Date: Double] = [:]

            func bucketKey(for date: Date) -> Date {
                switch scope {
                case .day:
                    let c = cal.dateComponents([.year, .month, .day, .hour], from: date)
                    return cal.date(from: c)!

                case .week, .month:
                    return cal.startOfDay(for: date)

                default:
                    let c = cal.dateComponents([.year, .month], from: date)
                    return cal.date(from: c)!
                }
            }

            for s in samples {
                let duration = s.endDate.timeIntervalSince(s.startDate)
                buckets[bucketKey(for: s.startDate), default: 0] += duration
            }

            var cursor = start
            var arr: [Double] = []

            while cursor < end {
                arr.append(buckets[bucketKey(for: cursor)] ?? 0)
                cursor = cal.date(byAdding: interval, to: cursor) ?? end
            }

            let total = arr.reduce(0, +)

            DispatchQueue.main.async {
                completion(arr, total)
            }
        }

        store.execute(q)
    }

    // MARK: - Stand Series
    func seriesStand(scope: TimeScope,
                     completion: @escaping ([Double], Double) -> Void) {

        let store = HKHealthStore()
        guard let type = HKObjectType.categoryType(forIdentifier: .appleStandHour) else {
            completion([], 0)
            return
        }

        let now = Date()
        let cal = Calendar.current

        let interval: DateComponents
        let start: Date
        let end: Date = now

        switch scope {
        case .day:
            interval = DateComponents(hour: 1)
            start = cal.startOfDay(for: now)

        case .week:
            interval = DateComponents(day: 1)
            start = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: now))!

        case .month:
            interval = DateComponents(day: 1)
            start = cal.date(byAdding: .day, value: -29, to: cal.startOfDay(for: now))!

        case .year:
            interval = DateComponents(month: 1)
            let comp = cal.dateComponents([.year, .month], from: now)
            start = cal.date(from: DateComponents(
                year: comp.year! - 1,
                month: comp.month,
                day: 1
            ))!

        case .allTime:
            interval = DateComponents(month: 1)
            start = Date.distantPast
        }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        let q = HKSampleQuery(sampleType: type,
                              predicate: predicate,
                              limit: HKObjectQueryNoLimit,
                              sortDescriptors: nil) { _, raw, _ in

            let samples = raw as? [HKCategorySample] ?? []
            var buckets: [Date: Double] = [:]

            func bucketKey(for date: Date) -> Date {
                switch scope {
                case .day:
                    let c = cal.dateComponents([.year, .month, .day, .hour], from: date)
                    return cal.date(from: c)!

                case .week, .month:
                    return cal.startOfDay(for: date)

                default:
                    let c = cal.dateComponents([.year, .month], from: date)
                    return cal.date(from: c)!
                }
            }

            for s in samples where s.value == 1 {
                buckets[bucketKey(for: s.startDate), default: 0] += 1
            }

            var cursor = start
            var arr: [Double] = []

            while cursor < end {
                arr.append(buckets[bucketKey(for: cursor)] ?? 0)
                cursor = cal.date(byAdding: interval, to: cursor) ?? end
            }

            let total = arr.reduce(0, +)

            DispatchQueue.main.async {
                completion(arr, total)
            }
        }

        store.execute(q)
    }
}
