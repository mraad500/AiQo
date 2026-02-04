import Foundation
import HealthKit

// ✅ هذا التعريف كان ناقصك وهو سبب الخطأ الثاني
public enum HKAsyncError: Error {
    case failed(String)
}

// MARK: - HKHealthStore async wrapper (safe)
public extension HKHealthStore {
    
    func requestAuthorizationAsync(toShare: Set<HKSampleType>, read toRead: Set<HKObjectType>) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            requestAuthorization(toShare: toShare, read: toRead) { success, error in
                if let error = error {
                    cont.resume(throwing: error)
                    return
                }
                guard success else {
                    cont.resume(throwing: HKAsyncError.failed("Health authorization failed"))
                    return
                }
                cont.resume(returning: ())
            }
        }
    }
}

// MARK: - HKLiveWorkoutBuilder async wrappers
public extension HKLiveWorkoutBuilder {
    
    func beginCollectionAsync(withStart startDate: Date) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            beginCollection(withStart: startDate) { success, error in
                if let error = error {
                    cont.resume(throwing: error)
                    return
                }
                guard success else {
                    cont.resume(throwing: HKAsyncError.failed("beginCollection failed"))
                    return
                }
                cont.resume(returning: ())
            }
        }
    }
    
    func endCollectionAsync(withEnd endDate: Date) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            endCollection(withEnd: endDate) { success, error in
                if let error = error {
                    cont.resume(throwing: error)
                    return
                }
                guard success else {
                    cont.resume(throwing: HKAsyncError.failed("endCollection failed"))
                    return
                }
                cont.resume(returning: ())
            }
        }
    }
}
