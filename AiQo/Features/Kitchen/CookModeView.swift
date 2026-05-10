import SwiftUI
import Combine
import AudioToolbox

/// Focused step-by-step cooking flow. The user advances one step at a time, each is
/// tickable so they can pause and come back. Includes a built-in timer with quick
/// presets and step-time auto-detect. On finish, they can mark the meal as eaten
/// which writes adherence in one tap.
struct CookModeView: View {
    let meal: KitchenPlannedMeal
    let onMarkEaten: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var currentStep: Int = 0
    @State private var completedSteps: Set<Int> = []
    @State private var timerEndDate: Date?
    @State private var timerTotalSeconds: Int = 0
    @State private var displayedRemaining: Int = 0
    @State private var timerHasFired: Bool = false

    private let tickTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    init(meal: KitchenPlannedMeal, onMarkEaten: (() -> Void)? = nil) {
        self.meal = meal
        self.onMarkEaten = onMarkEaten
    }

    private var hasSteps: Bool { !meal.steps.isEmpty }
    private var totalSteps: Int { meal.steps.count }
    private var progress: CGFloat {
        guard totalSteps > 0 else { return 0 }
        return CGFloat(completedSteps.count) / CGFloat(totalSteps)
    }

    private var isComplete: Bool {
        totalSteps > 0 && completedSteps.count == totalSteps
    }

    var body: some View {
        NavigationStack {
            ZStack {
                background

                VStack(spacing: 18) {
                    headerCard
                    progressBar

                    if hasSteps {
                        currentStepCard
                        timerCard
                        stepNavigation
                        Spacer(minLength: 8)
                        if isComplete {
                            completionFooter
                        }
                    } else {
                        emptyStateCard
                        Spacer()
                    }
                }
                .padding(20)
            }
            .onReceive(tickTimer) { _ in
                tick()
            }
            .navigationTitle("kitchen.cook.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("kitchen.cook.close".localized) {
                        dismiss()
                    }
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                }
            }
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color.kitchenMint.opacity(0.18),
                Color.aiqoSand.opacity(0.18),
                Color(.systemBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(meal.title)
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 10) {
                if let cooking = meal.cookingMinutes, cooking > 0 {
                    Label(
                        String(format: "kitchen.mealdetail.cookingMinutes".localized, cooking),
                        systemImage: "timer"
                    )
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color(.tertiarySystemFill)))
                }

                if let calories = meal.calories {
                    Label(
                        "\(calories) " + "screen.kitchen.caloriesUnit".localized,
                        systemImage: "flame.fill"
                    )
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color(.tertiarySystemFill)))
                }

                Spacer()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.6), lineWidth: 1)
        )
    }

    private var progressBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(
                    String(
                        format: "kitchen.cook.progress".localized,
                        completedSteps.count,
                        totalSteps
                    )
                )
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)

                Spacer()

                if isComplete {
                    Text("kitchen.cook.allDone".localized)
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(.green)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.kitchenMint.opacity(0.18))
                    Capsule()
                        .fill(Color.kitchenMint)
                        .frame(width: geo.size.width * progress)
                        .animation(.spring(response: 0.55), value: progress)
                }
            }
            .frame(height: 8)
        }
    }

    private var currentStepCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                Text("\(currentStep + 1)")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(Color.kitchenMint))

                Text(
                    String(
                        format: "kitchen.cook.stepOfTotal".localized,
                        currentStep + 1,
                        totalSteps
                    )
                )
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)

                Spacer()

                Button {
                    toggleCurrentStep()
                } label: {
                    Image(systemName: completedSteps.contains(currentStep) ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(completedSteps.contains(currentStep) ? .green : .secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    completedSteps.contains(currentStep)
                        ? "kitchen.cook.markUndone".localized
                        : "kitchen.cook.markDone".localized
                )
            }

            Text(meal.steps[currentStep])
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.6), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 14, y: 8)
    }

    private var stepNavigation: some View {
        HStack(spacing: 10) {
            Button {
                guard currentStep > 0 else { return }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.42)) {
                    currentStep -= 1
                }
            } label: {
                Label("kitchen.cook.previous".localized, systemImage: "chevron.backward")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 48)
                    .background(
                        Capsule().fill(Color(.tertiarySystemFill))
                    )
            }
            .buttonStyle(.plain)
            .disabled(currentStep == 0)
            .opacity(currentStep == 0 ? 0.4 : 1)

            Button {
                advance()
            } label: {
                Label(advanceButtonTitle, systemImage: "chevron.forward")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 48)
                    .background(
                        Capsule().fill(Color.kitchenMint)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private var completionFooter: some View {
        VStack(spacing: 10) {
            Text("kitchen.cook.completedHeadline".localized)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)

            if onMarkEaten != nil {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onMarkEaten?()
                    dismiss()
                } label: {
                    Label("kitchen.cook.markEaten".localized, systemImage: "checkmark.seal.fill")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 50)
                        .background(
                            Capsule().fill(NutritionEatenColor.color)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private var timerCard: some View {
        if let endDate = timerEndDate {
            activeTimerCard(endDate: endDate)
        } else {
            timerPresetsCard
        }
    }

    private var timerPresetsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("kitchen.timer.title".localized, systemImage: "timer")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                Spacer()
                if let detected = detectedMinutesInCurrentStep, detected > 0 {
                    Button {
                        startTimer(minutes: detected)
                    } label: {
                        Label(
                            String(format: "kitchen.timer.suggested".localized, detected),
                            systemImage: "sparkles"
                        )
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.kitchenMint))
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 8) {
                ForEach([3, 5, 10, 15], id: \.self) { minutes in
                    Button {
                        startTimer(minutes: minutes)
                    } label: {
                        Text(
                            String(format: "kitchen.mealplan.cookingMinutes".localized, minutes)
                        )
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 38)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color(.tertiarySystemFill))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.55), lineWidth: 1)
        )
    }

    private func activeTimerCard(endDate: Date) -> some View {
        let remaining = max(0, displayedRemaining)
        let progress = timerTotalSeconds > 0
            ? min(CGFloat(timerTotalSeconds - remaining) / CGFloat(timerTotalSeconds), 1.0)
            : 1.0

        return VStack(spacing: 10) {
            HStack {
                Label("kitchen.timer.running".localized, systemImage: "timer")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                Spacer()
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    cancelTimer()
                } label: {
                    Text("kitchen.timer.cancel".localized)
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(.red.opacity(0.86))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.red.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 12) {
                Text(formattedRemaining(remaining))
                    .font(.system(size: 30, weight: .black, design: .monospaced))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.spring(response: 0.4), value: remaining)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.kitchenMint.opacity(0.18))
                        Capsule()
                            .fill(Color.kitchenMint)
                            .frame(width: geo.size.width * progress)
                            .animation(.linear(duration: 0.5), value: progress)
                    }
                }
                .frame(height: 8)
            }

            if remaining == 0 {
                Text("kitchen.timer.done".localized)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.green)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.kitchenMint.opacity(0.55), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(
                format: "kitchen.timer.a11y".localized,
                formattedRemaining(remaining)
            )
        )
    }

    private var emptyStateCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "list.bullet.rectangle.portrait")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("kitchen.cook.noSteps".localized)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }

    private var advanceButtonTitle: String {
        if currentStep == totalSteps - 1 && !isComplete {
            return "kitchen.cook.finish".localized
        }
        return "kitchen.cook.next".localized
    }

    private func toggleCurrentStep() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.42)) {
            if completedSteps.contains(currentStep) {
                completedSteps.remove(currentStep)
            } else {
                completedSteps.insert(currentStep)
            }
        }
    }

    private func advance() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.42)) {
            completedSteps.insert(currentStep)
            if currentStep < totalSteps - 1 {
                currentStep += 1
            }
        }
    }

    // MARK: - Timer

    private var detectedMinutesInCurrentStep: Int? {
        guard hasSteps && currentStep < meal.steps.count else { return nil }
        let text = meal.steps[currentStep]
        return Self.parseMinutes(from: text)
    }

    /// Parses a "5 minutes / 5 min / 5 د / 5 دقائق" hint from a step. Returns the first
    /// reasonable match, ignoring values > 90 minutes which are likely something else.
    static func parseMinutes(from text: String) -> Int? {
        let pattern = #"(\d{1,3})\s*(?:min|mins|minute|minutes|د|دقائق|دقيقة|دقيقتين|دقيقتان)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let nsText = text as NSString
        let matches = regex.matches(
            in: text,
            options: [],
            range: NSRange(location: 0, length: nsText.length)
        )

        for match in matches where match.numberOfRanges >= 2 {
            let numberRange = match.range(at: 1)
            let numberText = nsText.substring(with: numberRange)
            if let value = Int(numberText), (1...90).contains(value) {
                return value
            }
        }
        return nil
    }

    private func startTimer(minutes: Int) {
        let total = max(minutes * 60, 30)
        timerTotalSeconds = total
        timerEndDate = Date().addingTimeInterval(TimeInterval(total))
        displayedRemaining = total
        timerHasFired = false
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func cancelTimer() {
        timerEndDate = nil
        timerTotalSeconds = 0
        displayedRemaining = 0
        timerHasFired = false
    }

    private func tick() {
        guard let endDate = timerEndDate else { return }
        let remaining = max(0, Int(endDate.timeIntervalSinceNow.rounded()))
        if remaining != displayedRemaining {
            displayedRemaining = remaining
        }
        if remaining == 0 && !timerHasFired {
            timerHasFired = true
            fireTimerCompletion()
        }
    }

    private func fireTimerCompletion() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        AudioServicesPlaySystemSound(SystemSoundID(1005))
    }

    private func formattedRemaining(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}

private enum NutritionEatenColor {
    static let color = Color(red: 0.35, green: 0.72, blue: 0.55)
}

#if DEBUG
#Preview {
    CookModeView(
        meal: KitchenPlannedMeal(
            dayIndex: 1,
            type: .lunch,
            title: "دجاج مشوي مع رز",
            calories: 540,
            protein: 42,
            ingredients: [
                KitchenIngredient(name: "صدر دجاج", amount: 200, unit: "غم"),
                KitchenIngredient(name: "رز", amount: 1, unit: "كوب")
            ],
            steps: [
                "تبّل الدجاج بالملح والفلفل",
                "اشوي الدجاج 5 دقائق لكل وجه",
                "اسلق الرز",
                "اطبخ البروكلي على البخار",
                "اجمع الكل بصحن واحد"
            ],
            cookingMinutes: 25
        )
    ) {
        // mark as eaten
    }
}
#endif
