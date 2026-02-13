import SwiftUI

// =========================
// File: Features/Gym/MyPlanView.swift
// SwiftUI - Plan Screen with Stats & Workouts
// =========================

// MARK: - Data Models
struct StatItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    var value: String
    let isSuggestion: Bool
    
    init(icon: String, title: String, value: String = "", isSuggestion: Bool = false) {
        self.icon = icon
        self.title = title
        self.value = value
        self.isSuggestion = isSuggestion
    }
}

struct WorkoutExerciseItem: Identifiable {
    let id = UUID()
    let name: String
    var isCompleted: Bool
}

struct TemplateExerciseItem: Identifiable {
    let id = UUID()
    var name: String
}

// MARK: - My Plan View
struct MyPlanView: View {
    @State private var stats: [StatItem] = [
        StatItem(icon: "figure.walk", title: L10n.t("metric.steps.title"), value: "8,234 / 10,000"),
        StatItem(icon: "flame.fill", title: L10n.t("metric.calories.title"), value: "420 / 600 kcal"),
        StatItem(icon: "drop.fill", title: L10n.t("metric.water.title"), value: "6 / 8 glasses"),
        StatItem(icon: "sparkles", title: L10n.t("plan.suggested.title"), value: L10n.t("plan.suggested.value"), isSuggestion: true)
    ]
    
    @State private var todayWorkouts: [WorkoutExerciseItem] = [
        WorkoutExerciseItem(name: "Push-ups (3 sets)", isCompleted: false),
        WorkoutExerciseItem(name: "Squats (3 sets)", isCompleted: true),
        WorkoutExerciseItem(name: "Plank (60 sec)", isCompleted: false)
    ]
    
    @State private var templates: [TemplateExerciseItem] = [
        TemplateExerciseItem(name: "Morning Stretch"),
        TemplateExerciseItem(name: "Full Body Workout"),
        TemplateExerciseItem(name: "Evening Run")
    ]
    
    @State private var newExerciseName: String = ""
    @FocusState private var isTextFieldFocused: Bool
    @State private var feedbackTrigger = 0
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                // Title
                Text(L10n.t("plan.title"))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .padding(.top, 18)
                
                // Stats Overview Section
                sectionHeader(L10n.t("plan.overview"))
                statsCard
                
                // Today's Workouts Section
                Text(L10n.t("plan.today_workouts"))
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                    .padding(.top, 4)
                
                todayWorkoutsCard
                
                // Templates Section
                Text(L10n.t("plan.templates"))
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                    .padding(.top, 4)
                
                templatesCard
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
        .background(Color(.systemBackground))
        .sensoryFeedback(.selection, trigger: feedbackTrigger)
    }
    
    // MARK: - Section Header
    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundColor(.secondary)
            .tracking(0.5)
    }
    
    // MARK: - Stats Card
    private var statsCard: some View {
        PlanGlassCard(tone: .mint) {
            VStack(spacing: 10) {
                ForEach(stats) { stat in
                    StatRowView(stat: stat)
                }
            }
            .padding(14)
        }
    }
    
    // MARK: - Today Workouts Card
    private var todayWorkoutsCard: some View {
        PlanGlassCard(tone: .sand) {
            VStack(spacing: 8) {
                ForEach($todayWorkouts) { $workout in
                    TodayWorkoutRowView(workout: $workout)
                }
                
                if todayWorkouts.isEmpty {
                    Text(L10n.t("plan.no_workouts"))
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 20)
                }
            }
            .padding(14)
        }
    }
    
    // MARK: - Templates Card
    private var templatesCard: some View {
        PlanGlassCard(tone: .mint) {
            VStack(spacing: 12) {
                // Input Row
                HStack(spacing: 10) {
                    TextField(L10n.t("plan.add_exercise"), text: $newExerciseName)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(.systemBackground).opacity(0.8))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                        )
                        .focused($isTextFieldFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            addNewExercise()
                        }
                    
                    Button(action: addNewExercise) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(GymTheme.mint)
                            )
                            .shadow(color: GymTheme.mint.opacity(0.3), radius: 6, x: 0, y: 3)
                    }
                }
                
                // Templates List
                ForEach(templates) { template in
                    TemplateRowView(
                        template: template,
                        onDelete: {
                            deleteTemplate(template)
                        }
                    )
                }
                
                if templates.isEmpty {
                    Text(L10n.t("plan.add_routine"))
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 12)
                }
            }
            .padding(14)
        }
    }
    
    // MARK: - Actions
    private func addNewExercise() {
        let trimmed = newExerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            templates.append(TemplateExerciseItem(name: trimmed))
            newExerciseName = ""
        }

        feedbackTrigger += 1
    }
    
    private func deleteTemplate(_ template: TemplateExerciseItem) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            templates.removeAll { $0.id == template.id }
        }

        feedbackTrigger += 1
    }
}

// MARK: - Plan Glass Card
struct PlanGlassCard<Content: View>: View {
    enum Tone {
        case mint, sand
        
        var color: Color {
            switch self {
            case .mint: return GymTheme.mint
            case .sand: return GymTheme.beige
            }
        }
    }
    
    let tone: Tone
    @ViewBuilder let content: Content
    
    var body: some View {
        ZStack {
            // Glass Background
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(tone.color.opacity(0.25))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.35), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 6)
            
            content
        }
    }
}

// MARK: - Stat Row View
struct StatRowView: View {
    let stat: StatItem
    
    var body: some View {
        HStack(spacing: 10) {
            // Icon
            Image(systemName: stat.icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.primary)
                .frame(width: 22, height: 22)
            
            // Title & Value
            VStack(alignment: .leading, spacing: 2) {
                Text(stat.title)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(stat.value)
                    .font(.system(size: stat.isSuggestion ? 15 : 17, weight: stat.isSuggestion ? .regular : .bold, design: .rounded))
                    .foregroundColor(stat.isSuggestion ? .secondary : .primary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.22))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.40), lineWidth: 1)
                )
        )
    }
}

// MARK: - Today Workout Row
struct TodayWorkoutRowView: View {
    @Binding var workout: WorkoutExerciseItem
    @State private var feedbackTrigger = 0
    
    var body: some View {
        HStack(spacing: 12) {
            Text(workout.name)
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundColor(workout.isCompleted ? .secondary : .primary)
                .strikethrough(workout.isCompleted, color: .secondary)
            
            Spacer()
            
            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    workout.isCompleted.toggle()
                }

                feedbackTrigger += 1
            }) {
                Image(systemName: workout.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(workout.isCompleted ? GymTheme.beige : .secondary)
            }
            .sensoryFeedback(.selection, trigger: feedbackTrigger)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Template Row View
struct TemplateRowView: View {
    let template: TemplateExerciseItem
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Text(template.name)
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundColor(.primary)
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Preview
#Preview {
    MyPlanView()
}
