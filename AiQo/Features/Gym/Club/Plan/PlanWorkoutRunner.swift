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
                        .fill(PlanPalette.hairline)
                    Capsule()
                        .fill(PlanPalette.mintDeep)
                        .frame(width: max(8, proxy.size.width * progressFraction))
                        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: progressFraction)
                }
            }
            .frame(height: 6)
        }
    }

    private var exerciseFocusCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(isArabic ? currentInsights.muscleGroup.arabicLabel : currentInsights.muscleGroup.englishLabel)
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(currentInsights.muscleGroup.ink)
                    .textCase(.uppercase)
                    .tracking(0.7)

                Text(currentExercise.name)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 16) {
                metricColumn(
                    label: isArabic ? "مجاميع" : "Sets",
                    value: "\(currentExercise.sets)"
                )
                metricDivider
                metricColumn(
                    label: isArabic ? "تكرار" : "Reps",
                    value: currentExercise.repsOrDuration
                )
                metricDivider
                metricColumn(
                    label: isArabic ? "استراحة" : "Rest",
                    value: "\(currentInsights.restSeconds)s"
                )
                Spacer(minLength: 0)
            }

            if !currentInsights.formCues.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(PlanPalette.lemonDeep)
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
                        .fill(PlanPalette.lemon.opacity(0.45))
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
                .foregroundStyle(PlanPalette.mintDeep)
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
                .fill(PlanPalette.surfaceTint)
        )
    }

    private func metricColumn(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.4)
        }
    }

    private var metricDivider: some View {
        Rectangle()
            .fill(PlanPalette.hairline)
            .frame(width: 1, height: 30)
    }

    private var setsTracker: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(isArabic ? "ضغطة لكل مجموعة" : "Tap each set")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
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
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(PlanPalette.hairline, lineWidth: 1)
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
                            ? PlanPalette.mint
                            : (isCurrent ? PlanPalette.mint.opacity(0.18) : Color.clear)
                    )
                    .frame(width: 48, height: 48)
                    .overlay(
                        Circle()
                            .stroke(
                                isCurrent
                                    ? PlanPalette.mintDeep
                                    : (isComplete ? PlanPalette.mintDeep.opacity(0.35) : PlanPalette.hairline),
                                lineWidth: isCurrent ? 2 : 1
                            )
                    )

                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(PlanPalette.mintDeep)
                        .symbolEffect(.bounce, value: isComplete)
                } else {
                    Text("\(index + 1)")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(isCurrent ? PlanPalette.mintDeep : .secondary)
                }
            }
            .scaleEffect(isCurrent ? 1.04 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isComplete || isResting)
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: isCurrent)
    }

    private var restCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "hourglass")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(PlanPalette.lavenderDeep)
                Text(isArabic ? "وقت الاستراحة" : "Rest")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(PlanPalette.lavenderDeep)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
                Button {
                    skipRest()
                } label: {
                    Text(isArabic ? "تخطّى" : "Skip")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(PlanPalette.lavenderDeep)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule(style: .continuous)
                                .fill(PlanPalette.lavender.opacity(0.55))
                        )
                }
                .buttonStyle(.plain)
            }

            Text(formatElapsed(restRemaining))
                .font(.system(size: 42, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(PlanPalette.hairline)
                    Capsule()
                        .fill(PlanPalette.lavenderDeep)
                        .frame(width: max(6, proxy.size.width * restProgress))
                }
            }
            .frame(height: 5)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(PlanPalette.lavender.opacity(0.32))
        )
    }

    private var upcomingStrip: some View {
        let upcoming = Array(plan.exercises.enumerated()).filter { $0.offset > currentExerciseIndex }.prefix(3)
        return Group {
            if !upcoming.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(isArabic ? "بعدها" : "Up next")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    VStack(spacing: 0) {
                        ForEach(Array(upcoming.enumerated()), id: \.offset) { idx, pair in
                            upcomingRow(pair.element, ordinal: pair.offset + 1)
                            if idx < upcoming.count - 1 {
                                Rectangle()
                                    .fill(PlanPalette.hairline)
                                    .frame(height: 1)
                                    .padding(.leading, 38)
                            }
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(PlanPalette.hairline, lineWidth: 1)
                        )
                )
            }
        }
    }

    private func upcomingRow(_ exercise: Exercise, ordinal: Int) -> some View {
        let info = exercise.insights(language: language)
        return HStack(spacing: 12) {
            Text("\(ordinal)")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 26)
                .background(
                    Circle().stroke(PlanPalette.hairline, lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text("\(exercise.sets) × \(exercise.repsOrDuration)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text(isArabic ? info.muscleGroup.arabicLabel : info.muscleGroup.englishLabel)
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundStyle(info.muscleGroup.ink)
                        .textCase(.uppercase)
                        .tracking(0.4)
                }
            }

            Spacer(minLength: 4)
        }
        .padding(.vertical, 9)
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
                .padding(.vertical, 14)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color(.systemBackground))
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(PlanPalette.hairline, lineWidth: 1)
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
                .foregroundStyle(PlanPalette.mintDeep)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    Capsule(style: .continuous)
                        .fill(PlanPalette.mint)
                )
            }
            .buttonStyle(.plain)
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
            Color.black.opacity(0.4).ignoresSafeArea()

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(PlanPalette.mint)
                    Image(systemName: "checkmark")
                        .font(.system(size: 38, weight: .heavy))
                        .foregroundStyle(PlanPalette.mintDeep)
                }
                .frame(width: 92, height: 92)

                Text(isArabic ? "🎉 خلصت بطل!" : "🎉 You crushed it!")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary)

                Text(String(
                    format: isArabic ? "%d تمرين • %d مجموعة • %@" : "%d exercises • %d sets • %@",
                    totalExercises,
                    totalSetsAcross,
                    formatElapsed(elapsedSeconds)
                ))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

                Button {
                    onCompleteAll()
                    dismiss()
                } label: {
                    Text(isArabic ? "تمام، رجّعني" : "Done")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(PlanPalette.mintDeep)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            Capsule(style: .continuous)
                                .fill(PlanPalette.mint)
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(28)
            .frame(maxWidth: 320)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color(.systemBackground))
            )
            .padding(.horizontal, 30)

            ConfettiView()
                .allowsHitTesting(false)
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [
                PlanPalette.sand.opacity(0.35),
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
                PlanPalette.mint,
                PlanPalette.sand,
                PlanPalette.lavender,
                PlanPalette.lemon,
                PlanPalette.mintDeep
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
