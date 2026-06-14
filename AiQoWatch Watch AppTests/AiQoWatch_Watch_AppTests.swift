//
//  AiQoWatch_Watch_AppTests.swift
//  AiQoWatch Watch AppTests
//
//  Created by Mohammed Raad on 16/01/2026.
//

import Testing
import HealthKit
@testable import AiQoWatch_Watch_App

struct AiQoWatch_Watch_AppTests {

    // MARK: - Workout type recovery (iPhone-launched workouts)
    // When the iPhone launches a workout, the watch only receives an
    // HKWorkoutActivityType + location and must recover the watch-facing type.
    // These guard against the regression where every iPhone-launched workout
    // showed up on the watch as "Outdoor Run".

    @Test func runningPreservesIndoorOutdoor() {
        #expect(WatchWorkoutType(hkType: .running, locationType: .outdoor) == .runOutdoor)
        #expect(WatchWorkoutType(hkType: .running, locationType: .indoor) == .runIndoor)
    }

    @Test func walkingPreservesIndoorOutdoor() {
        #expect(WatchWorkoutType(hkType: .walking, locationType: .outdoor) == .walkOutdoor)
        #expect(WatchWorkoutType(hkType: .walking, locationType: .indoor) == .walkIndoor)
    }

    @Test func distinctActivitiesMapToTheirType() {
        #expect(WatchWorkoutType(hkType: .cycling, locationType: .outdoor) == .cycling)
        #expect(WatchWorkoutType(hkType: .highIntensityIntervalTraining, locationType: .indoor) == .hiit)
        #expect(WatchWorkoutType(hkType: .traditionalStrengthTraining, locationType: .indoor) == .strengthTraining)
        #expect(WatchWorkoutType(hkType: .functionalStrengthTraining, locationType: .indoor) == .strengthTraining)
        #expect(WatchWorkoutType(hkType: .yoga, locationType: .indoor) == .yoga)
        #expect(WatchWorkoutType(hkType: .swimming, locationType: .indoor) == .swimming)
    }

    @Test func unknownLocationIsTreatedAsOutdoor() {
        // Kernel / fitness-assessment launches request `.unknown`.
        #expect(WatchWorkoutType(hkType: .walking, locationType: .unknown) == .walkOutdoor)
        #expect(WatchWorkoutType(hkType: .running, locationType: .unknown) == .runOutdoor)
    }

    @Test func unmappedActivityFallsBackToRun() {
        #expect(WatchWorkoutType(hkType: .other, locationType: .outdoor) == .runOutdoor)
    }

    // MARK: - Round-trip stability
    // A watch-initiated type must survive being mapped to HealthKit and back,
    // so the `currentType` derivation never clobbers an exact selection.

    @Test func watchInitiatedTypesRoundTrip() {
        for type in WatchWorkoutType.allCases {
            let recovered = WatchWorkoutType(hkType: type.hkType, locationType: type.locationType)
            #expect(recovered.hkType == type.hkType)
        }
    }
}
