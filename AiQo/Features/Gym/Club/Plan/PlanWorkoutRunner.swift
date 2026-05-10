import Combine
import SwiftUI

// MARK: - Plan Workout Runner
//
// Full-screen, distraction-free live execution of a pinned `WorkoutPlan`.
// Tracks per-exercise sets, runs an auto rest timer between sets, surfaces a
// running total session timer, and celebrates completion.

struct PlanWorkoutRunner: View {
    let plan: WorkoutPlan
    let language: AppLanguage
    let onCompleteAll: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var currentExerciseIndex: Int = 0
    @State private var setsCompleted: [Int: Int] = [:]            // exerciseIndex -> sets done
    @State private var sessionStart: Date = Date()
    @State private var elapsedSeconds: Int = 0
    @State private var restRemaining: Int = 0
    @State private var isResting: Bool = false
    @State private var isPaused: Bool = false
    @State private var showCompletion: Bool = false
    @State private var didFireSuccessHaptic: Bool = false

    private let timerTick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var isArabic: Bool { language == .arabic }
    private var currentExercise: Exercise { plan.exercises[currentExerciseIndex] }
    private var currentInsights: ExerciseInsights { currentExercise.insights(language: language) }
    private var totalExercises: Int { plan.exercises.count }
    private var setsDoneForCurrent: Int { setsCompleted[currentExerciseIndex] ?? 0 }
    private var totalSetsAcross: Int { plan.exercises.reduce(0) { $0 + $1.sets } }
    private var totalSetsDone: Int { setsCompleted.values.reduce(0, +) }
    private var allDone: Bool { totalSetsDone >= totalSetsAcross }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        progressHeader
                        exerciseFocusCard
                        setsTracker
                        if isResting {
                            restCard
                        }
                        upcomingStrip
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 14)
                    .padding(.bottom, 30)
                }

                bottomActions
            }

            if showCompletion {
                completionOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
        }
        .onReceive(timerTick) { _ in
            tick()
        }
    }

    // MARK: - Sections

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(.primary)
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(isArabic ? "تنفيذ الخطة" : "Live workout")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Text(plan.title)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Text(formatElapsed(elapsedSeconds))
                .font(.system(size: 16, weight: .heavy, design: .monospaced))
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule(style: .continuous))
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(String(format: isArabic ? "تمرين %d من %d" : "Exercise %d of %d", currentExerciseIndex + 1, totalExercises))
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.4)

                Spacer()

                Text("\(totalSetsDone)/\(totalSetsAcross) \(isArabic ? "مجموعة" : "sets")")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.55))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.45, green: 0.83, blue: 0.78),
                                    Color(red: 0.55, green: 0.72, blue: 0.95)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, proxy.size.width * progressFraction))
                        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: progressFraction)
                }
            }
            .frame(height: 8)
        }
    }

    private var exerciseFocusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    currentInsights.muscleGroup.accent.opacity(0.95),
                                    currentInsights.muscleGroup.accent.opacity(0.55)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: currentInsights.muscleGroup.icon)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 56, height: 56)
                .shadow(color: currentInsights.muscleGroup.accent.opacity(0.45), radius: 12, x: 0, y: 6)

                VStack(alignment: .leading, spacing: 4) {
                    Text(isArabic ? currentInsights.muscleGroup.arabicLabel : currentInsights.muscleGroup.englishLabel)
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(currentInsights.muscleGroup.accent)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    Text(currentExercise.name)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                metricPill(
                    icon: "repeat",
                    label: isArabic ? "مجاميع" : "Sets",
                    value: "\(currentExercise.sets)"
                )
                metricPill(
                    icon: "number",
                    label: isArabic ? "تكرار" : "Reps",
                    value: currentExercise.repsOrDuration
                )
                metricPill(
                    icon: "pause.circle",
                    label: isArabic ? "استراحة" : "Rest",
                    value: "\(currentInsights.restSeconds)s"
                )
            }

            if !currentInsights.formCues.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(Color(red: 0.99, green: 0.78, blue: 0.45))
                        Text(isArabic ? "تذكير سريع" : "Quick cue")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.4)
                    }
                    if let firstCue = currentInsights.formCues.first {
                        Text(firstCue)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary.opacity(0.85))
                            .lineLimit(2)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(red: 0.99, green: 0.78, blue: 0.45).opacity(0.16))
                )
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Color.white.opacity(0.5), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.08), radius: 18, y: 8)
    }

    private func metricPill(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(currentInsights.muscleGroup.accent)
            Text(label)
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(value)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(currentInsights.muscleGroup.accent.opacity(0.12))
        )
    }

    private var setsTracker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(isArabic ? "ضغطة لكل مجموعة" : "Tap each set")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.4)
                Spacer()
                Text("\(setsDoneForCurrent)/\(currentExercise.sets)")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary)
            }

            HStack(spacing: 10) {
                ForEach(0..<currentExercise.sets, id: \.self) { index in
                    setButton(at: index)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.5), lineWidth: 1)
                )
        )
    }

    private func setButton(at index: Int) -> some View {
        let isComplete = index < setsDoneForCurrent
        let isCurrent = index == setsDoneForCurrent && !isResting
        return Button {
            tapSet(at: index)
        } label: {
            ZStack {
                Circle()
                    .fill(
                        isComplete
                            ? AnyShapeStyle(LinearGradient(
                                colors: [
                                    currentInsights.muscleGroup.accent,
                                    currentInsights.muscleGroup.accent.opacity(0.7)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            : AnyShapeStyle(Color.white.opacity(isCurrent ? 0.78 : 0.42))
                    )
                    .frame(width: 50, height: 50)
                    .overlay(
                        Circle()
                            .stroke(
                                isCurrent
                                    ? currentInsights.muscleGroup.accent
                                    : Color.white.opacity(0.45),
                                lineWidth: isCurrent ? 2.5 : 1
                            )
                    )

                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(.white)
                        .symbolEffect(.bounce, value: isComplete)
                } else {
                    Text("\(index + 1)")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(.primary.opacity(isCurrent ? 0.92 : 0.55))
                }
            }
            .scaleEffect(isCurrent ? 1.06 : 1)
            .shadow(
                color: isCurrent ? currentInsights.muscleGroup.accent.opacity(0.4) : .clear,
                radius: 8,
                y: 4
            )
        }
        .buttonStyle(.plain)
        .disabled(isComplete || isResting)
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: isCurrent)
    }

    private var restCard: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "hourglass")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Color(red: 0.55, green: 0.72, blue: 0.95))
                Text(isArabic ? "وقت الاستراحة" : "Rest")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
                Button {
                    skipRest()
                } label: {
                    Text(isArabic ? "تخطّى" : "Skip")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(red: 0.55, green: 0.72, blue: 0.95))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color(red: 0.55, green: 0.72, blue: 0.95).opacity(0.18))
                        )
                }
                .buttonStyle(.plain)
            }

            Text(formatElapsed(restRemaining))
                .font(.system(size: 38, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.4))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.55, green: 0.72, blue: 0.95),
                                    Color(red: 0.85, green: 0.66, blue: 0.96)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(6, proxy.size.width * restProgress))
                }
            }
            .frame(height: 6)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.55, green: 0.72, blue: 0.95).opacity(0.22),
                            Color(red: 0.85, green: 0.66, blue: 0.96).opacity(0.22)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.45), lineWidth: 1)
                )
        )
    }

    private var upcomingStrip: some View {
        let upcoming = Array(plan.exercises.enumerated()).filter { $0.offset > currentExerciseIndex }.prefix(3)
        return Group {
            if !upcoming.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(isArabic ? "بعدها" : "Up next")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.4)

                    VStack(spacing: 7) {
                        ForEach(upcoming.map(\.element), id: \.id) { exercise in
                            upcomingRow(exercise)
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(Color.white.opacity(0.45), lineWidth: 1)
                        )
                )
            }
        }
    }

    private func upcomingRow(_ exercise: Exercise) -> some View {
        let info = exercise.insights(language: language)
        return HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(info.muscleGroup.accent.opacity(0.22))
                Image(systemName: info.muscleGroup.icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(info.muscleGroup.accent)
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(exercise.name)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text("\(exercise.sets) × \(exercise.repsOrDuration)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)
        }
    }

    private var bottomActions: some View {
        HStack(spacing: 10) {
            Button {
                isPaused.toggle()
            } label: {
                Label(
                    isPaused ? (isArabic ? "استكمل" : "Resume") : (isArabic ? "إيقاف" : "Pause"),
                    systemImage: isPaused ? "play.fill" : "pause.fill"
                )
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    Capsule(style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Color.white.opacity(0.45), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)

            Button {
                advanceExercise()
            } label: {
                Label(
                    setsDoneForCurrent >= currentExercise.sets
                        ? (isArabic ? "التالي" : "Next")
                        : (isArabic ? "تخطّى" : "Skip"),
                    systemImage: setsDoneForCurrent >= currentExercise.sets ? "arrow.right.circle.fill" : "forward.fill"
                )
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    currentInsights.muscleGroup.accent,
                                    currentInsights.muscleGroup.accent.opacity(0.78)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .shadow(color: currentInsights.muscleGroup.accent.opacity(0.45), radius: 12, y: 6)
            }
            .buttonStyle(.plain)
            .disabled(currentExerciseIndex >= totalExercises - 1 && setsDoneForCurrent < currentExercise.sets)
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .background(
            LinearGradient(
                colors: [Color(.systemBackground).opacity(0), Color(.systemBackground).opacity(0.9)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var completionOverlay: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()

            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.45, green: 0.83, blue: 0.78),
                                    Color(red: 0.55, green: 0.72, blue: 0.95)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "checkmark")
                        .font(.system(size: 40, weight: .heavy))
                        .foregroundStyle(.white)
                }
                .frame(width: 96, height: 96)
                .shadow(color: Color(red: 0.45, green: 0.83, blue: 0.78).opacity(0.55), radius: 22, y: 10)

                Text(isArabic ? "🎉 خلصت بطل!" : "🎉 You crushed it!")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary)

                Text(String(
                    format: isArabic ? "%d تمرين • %d مجموعة • %@" : "%d exercises • %d sets • %@",
                    totalExercises,
                    totalSetsAcross,
                    formatElapsed(elapsedSeconds)
                ))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

                Button {
                    onCompleteAll()
                    dismiss()
                } label: {
                    Text(isArabic ? "تمام، رجّعني" : "Done")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            Capsule(style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.45, green: 0.83, blue: 0.78),
                                            Color(red: 0.55, green: 0.72, blue: 0.95)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            }
            .padding(28)
            .frame(maxWidth: 320)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(.regularMaterial)
            )
            .padding(.horizontal, 30)

            ConfettiView()
                .allowsHitTesting(false)
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [
                currentInsights.muscleGroup.accent.opacity(0.18),
                Color(.systemBackground),
                Color(.systemBackground)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Logic

    private var progressFraction: Double {
        guard totalSetsAcross > 0 else { return 0 }
        return Double(totalSetsDone) / Double(totalSetsAcross)
    }

    private var restProgress: Double {
        guard currentInsights.restSeconds > 0 else { return 0 }
        return 1.0 - (Double(restRemaining) / Double(currentInsights.restSeconds))
    }

    private func tapSet(at index: Int) {
        guard index == setsDoneForCurrent else { return }
        UISelectionFeedbackGenerator().selectionChanged()
        let newCount = setsDoneForCurrent + 1
        setsCompleted[currentExerciseIndex] = newCount

        if newCount >= currentExercise.sets {
            // finished this exercise — auto-advance after a beat
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                advanceExercise()
            }
        } else {
            startRest()
        }
    }

    private func startRest() {
        restRemaining = currentInsights.restSeconds
        isResting = true
    }

    private func skipRest() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        restRemaining = 0
        isResting = false
    }

    private func advanceExercise() {
        isResting = false
        if currentExerciseIndex < totalExercises - 1 {
            currentExerciseIndex += 1
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } else if allDone {
            triggerCompletion()
        }
    }

    private func tick() {
        guard !isPaused else { return }
        if !showCompletion {
            elapsedSeconds += 1
        }
        if isResting {
            if restRemaining > 0 {
                restRemaining -= 1
                if restRemaining == 0 {
                    isResting = false
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            }
        }
        if allDone && !showCompletion {
            triggerCompletion()
        }
    }

    private func triggerCompletion() {
        guard !showCompletion else { return }
        if !didFireSuccessHaptic {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            didFireSuccessHaptic = true
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
            showCompletion = true
        }
    }

    private func formatElapsed(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - Lightweight confetti

private struct ConfettiPiece: Identifiable {
    let id = UUID()
    let xPercent: Double
    let delay: Double
    let duration: Double
    let rotation: Double
    let color: Color
    let size: CGFloat
}

private struct ConfettiView: View {
    private static let pieces: [ConfettiPiece] = (0..<60).map { _ in
        ConfettiPiece(
            xPercent: Double.random(in: 0...1),
            delay: Double.random(in: 0...0.6),
            duration: Double.random(in: 1.6...2.8),
            rotation: Double.random(in: 0...360),
            color: [
                Color(red: 0.45, green: 0.83, blue: 0.78),
                Color(red: 0.55, green: 0.72, blue: 0.95),
                Color(red: 0.99, green: 0.78, blue: 0.45),
                Color(red: 0.96, green: 0.50, blue: 0.55),
                Color(red: 0.85, green: 0.66, blue: 0.96)
            ].randomElement() ?? .yellow,
            size: CGFloat.random(in: 6...12)
        )
    }

    @State private var animate: Bool = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(Self.pieces) { piece in
                    Rectangle()
                        .fill(piece.color)
                        .frame(width: piece.size, height: piece.size * 0.45)
                        .rotationEffect(.degrees(piece.rotation))
                        .position(
                            x: proxy.size.width * piece.xPercent,
                            y: animate ? proxy.size.height + 30 : -40
                        )
                        .animation(
                            .easeIn(duration: piece.duration).delay(piece.delay),
                            value: animate
                        )
                }
            }
        }
        .onAppear { animate = true }
    }
}
