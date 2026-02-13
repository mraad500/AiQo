import Foundation
import HealthKit
import SwiftUI

// MARK: - Gym Exercise Model
struct GymExercise: Identifiable, Hashable {
    let id: UUID
    let titleKey: String
    let type: HKWorkoutActivityType
    let location: HKWorkoutSessionLocationType
    let icon: String
    let tint: Color

    init(
        id: UUID = UUID(),
        titleKey: String,
        type: HKWorkoutActivityType,
        location: HKWorkoutSessionLocationType = .indoor,
        icon: String = "figure.mixed.cardio",
        tint: Color = .aiqoBeige
    ) {
        self.id = id
        self.titleKey = titleKey
        self.type = type
        self.location = location
        self.icon = icon
        self.tint = tint
    }

    var title: String {
        L10n.t(titleKey)
    }

    // MARK: - Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: GymExercise, rhs: GymExercise) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Sample Exercises
extension GymExercise {

    /// Workout list used by the Body tab cards.
    static let samples: [GymExercise] = [
        GymExercise(
            titleKey: "gym.exercise.running",
            type: .running,
            location: .outdoor,
            icon: "figure.run",
            tint: .aiqoBeige
        ),
        GymExercise(
            titleKey: "gym.exercise.walking",
            type: .walking,
            location: .outdoor,
            icon: "figure.walk",
            tint: .aiqoBeige
        ),

        GymExercise(
            titleKey: "gym.exercise.cycling",
            type: .cycling,
            location: .outdoor,
            icon: "figure.outdoor.cycle",
            tint: .aiqoMint
        ),
        GymExercise(
            titleKey: "gym.exercise.swimming",
            type: .swimming,
            location: .indoor,
            icon: "figure.pool.swim",
            tint: .aiqoMint
        ),

        GymExercise(
            titleKey: "gym.exercise.strength",
            type: .traditionalStrengthTraining,
            location: .indoor,
            icon: "dumbbell.fill",
            tint: .aiqoBeige
        ),
        GymExercise(
            titleKey: "gym.exercise.hiit",
            type: .highIntensityIntervalTraining,
            location: .indoor,
            icon: "flame.fill",
            tint: .aiqoBeige
        ),

        GymExercise(
            titleKey: "gym.exercise.yoga",
            type: .yoga,
            location: .indoor,
            icon: "figure.yoga",
            tint: .aiqoMint
        ),
        GymExercise(
            titleKey: "gym.exercise.equestrian",
            type: .equestrianSports,
            location: .outdoor,
            icon: "figure.equestrian.sports",
            tint: .aiqoMint
        ),
        GymExercise(
            titleKey: "gym.exercise.calisthenics",
            type: .functionalStrengthTraining,
            location: .indoor,
            icon: "figure.strengthtraining.traditional",
            tint: .aiqoBeige
        ),
        GymExercise(
            titleKey: "gym.exercise.pilates",
            type: .pilates,
            location: .indoor,
            icon: "figure.core.training",
            tint: .aiqoMint
        ),
        GymExercise(
            titleKey: "gym.exercise.gratitude",
            type: .mindAndBody,
            location: .indoor,
            icon: "heart.text.square",
            tint: .aiqoBeige
        ),
        GymExercise(
            titleKey: "gym.exercise.indoor_cycle",
            type: .cycling,
            location: .indoor,
            icon: "figure.indoor.cycle",
            tint: .aiqoMint
        ),
        GymExercise(
            titleKey: "gym.exercise.elliptical",
            type: .elliptical,
            location: .indoor,
            icon: "figure.elliptical",
            tint: .aiqoBeige
        ),
        GymExercise(
            titleKey: "gym.exercise.stair_stepper",
            type: .stairClimbing,
            location: .indoor,
            icon: "figure.stair.stepper",
            tint: .aiqoMint
        ),
        GymExercise(
            titleKey: "gym.exercise.football",
            type: .soccer,
            location: .outdoor,
            icon: "soccerball",
            tint: .aiqoBeige
        ),
        GymExercise(
            titleKey: "gym.exercise.padel_tennis",
            type: .tennis,
            location: .outdoor,
            icon: "tennis.racket",
            tint: .aiqoMint
        ),
        GymExercise(
            titleKey: "gym.exercise.basketball",
            type: .basketball,
            location: .indoor,
            icon: "basketball",
            tint: .aiqoBeige
        ),
        GymExercise(
            titleKey: "gym.exercise.boxing",
            type: .boxing,
            location: .indoor,
            icon: "figure.boxing",
            tint: .aiqoMint
        ),
        GymExercise(
            titleKey: "gym.exercise.martial_arts",
            type: .martialArts,
            location: .indoor,
            icon: "figure.martial.arts",
            tint: .aiqoBeige
        ),
        GymExercise(
            titleKey: "gym.exercise.jump_rope",
            type: .jumpRope,
            location: .indoor,
            icon: "figure.jumprope",
            tint: .aiqoMint
        )
    ]
}
