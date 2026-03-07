import Foundation

struct CaptainStructuredResponse: Codable, Sendable {
    let message: String
    let workoutPlan: WorkoutPlan?
    let mealPlan: MealPlan?

    private enum CodingKeys: String, CodingKey {
        case message
        case workoutPlan
        case mealPlan
    }

    init(
        message: String,
        workoutPlan: WorkoutPlan? = nil,
        mealPlan: MealPlan? = nil
    ) {
        self.message = message.trimmingCharacters(in: .whitespacesAndNewlines)
        self.workoutPlan = workoutPlan?.isMeaningful == true ? workoutPlan : nil
        self.mealPlan = mealPlan?.isMeaningful == true ? mealPlan : nil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let rawMessage = try container.decode(String.self, forKey: .message)
        let normalizedMessage = rawMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedMessage.isEmpty else {
            throw DecodingError.dataCorruptedError(
                forKey: .message,
                in: container,
                debugDescription: "Captain response message must not be empty."
            )
        }

        message = normalizedMessage
        workoutPlan = try container.decodeIfPresent(WorkoutPlan.self, forKey: .workoutPlan)
        let decodedMealPlan = try container.decodeIfPresent(MealPlan.self, forKey: .mealPlan)
        mealPlan = decodedMealPlan?.isMeaningful == true ? decodedMealPlan : nil
    }
}

struct MealPlan: Codable, Equatable, Sendable {
    let meals: [Meal]

    private enum CodingKeys: String, CodingKey {
        case meals
    }

    init(meals: [Meal]) {
        self.meals = meals
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedMeals = try container.decode([Meal].self, forKey: .meals)

        guard !decodedMeals.isEmpty else {
            throw DecodingError.dataCorruptedError(
                forKey: .meals,
                in: container,
                debugDescription: "MealPlan.meals must contain at least one meal."
            )
        }

        meals = decodedMeals
    }

    var isMeaningful: Bool {
        !meals.isEmpty
    }

    struct Meal: Codable, Equatable, Identifiable, Sendable {
        var id = UUID()
        let type: String
        let description: String
        let calories: Int

        private enum CodingKeys: String, CodingKey {
            case type
            case description
            case calories
        }

        init(
            id: UUID = UUID(),
            type: String,
            description: String,
            calories: Int
        ) {
            self.id = id
            self.type = type.trimmingCharacters(in: .whitespacesAndNewlines)
            self.description = description.trimmingCharacters(in: .whitespacesAndNewlines)
            self.calories = calories
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            let rawType = try container.decode(String.self, forKey: .type)
            let normalizedType = rawType.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedType.isEmpty else {
                throw DecodingError.dataCorruptedError(
                    forKey: .type,
                    in: container,
                    debugDescription: "Meal.type must not be empty."
                )
            }

            let rawDescription = try container.decode(String.self, forKey: .description)
            let normalizedDescription = rawDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedDescription.isEmpty else {
                throw DecodingError.dataCorruptedError(
                    forKey: .description,
                    in: container,
                    debugDescription: "Meal.description must not be empty."
                )
            }

            let decodedCalories = try container.decode(Int.self, forKey: .calories)
            guard decodedCalories > 0 else {
                throw DecodingError.dataCorruptedError(
                    forKey: .calories,
                    in: container,
                    debugDescription: "Meal.calories must be greater than zero."
                )
            }

            id = UUID()
            type = normalizedType
            description = normalizedDescription
            calories = decodedCalories
        }
    }
}

struct WorkoutPlan: Codable, Equatable, Sendable {
    let title: String
    let exercises: [Exercise]

    private enum CodingKeys: String, CodingKey {
        case title
        case exercises
    }

    init(title: String, exercises: [Exercise]) {
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.exercises = exercises
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let rawTitle = try container.decode(String.self, forKey: .title)
        let normalizedTitle = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTitle.isEmpty else {
            throw DecodingError.dataCorruptedError(
                forKey: .title,
                in: container,
                debugDescription: "WorkoutPlan.title must not be empty."
            )
        }

        let decodedExercises = try container.decode([Exercise].self, forKey: .exercises)
        guard !decodedExercises.isEmpty else {
            throw DecodingError.dataCorruptedError(
                forKey: .exercises,
                in: container,
                debugDescription: "WorkoutPlan.exercises must contain at least one exercise."
            )
        }

        title = normalizedTitle
        exercises = decodedExercises
    }

    var isMeaningful: Bool {
        !title.isEmpty && !exercises.isEmpty
    }
}

struct Exercise: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    let name: String
    let sets: Int
    let repsOrDuration: String

    private enum CodingKeys: String, CodingKey {
        case name
        case sets
        case repsOrDuration
    }

    init(
        id: UUID = UUID(),
        name: String,
        sets: Int,
        repsOrDuration: String
    ) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.sets = sets
        self.repsOrDuration = repsOrDuration.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let rawName = try container.decode(String.self, forKey: .name)
        let normalizedName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty else {
            throw DecodingError.dataCorruptedError(
                forKey: .name,
                in: container,
                debugDescription: "Exercise.name must not be empty."
            )
        }

        let decodedSets = try container.decode(Int.self, forKey: .sets)
        guard decodedSets > 0 else {
            throw DecodingError.dataCorruptedError(
                forKey: .sets,
                in: container,
                debugDescription: "Exercise.sets must be greater than zero."
            )
        }

        let rawRepsOrDuration = try container.decode(String.self, forKey: .repsOrDuration)
        let normalizedRepsOrDuration = rawRepsOrDuration.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedRepsOrDuration.isEmpty else {
            throw DecodingError.dataCorruptedError(
                forKey: .repsOrDuration,
                in: container,
                debugDescription: "Exercise.repsOrDuration must not be empty."
            )
        }

        id = UUID()
        name = normalizedName
        sets = decodedSets
        repsOrDuration = normalizedRepsOrDuration
    }
}
