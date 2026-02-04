import HealthKit

@MainActor
protocol WorkoutManaging: AnyObject {
    func startWorkout(workoutType: HKWorkoutActivityType, location: HKWorkoutSessionLocationType)
    func endWorkout()
}
