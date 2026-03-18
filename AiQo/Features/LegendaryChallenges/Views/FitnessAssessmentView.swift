import SwiftUI
import HealthKit

// MARK: - Fitness Assessment View (4-Step HRR Test)

struct FitnessAssessmentView: View {
    let record: LegendaryRecord

    @State private var step = 1
    @State private var hrrManager = HRRWorkoutManager()

    // Timer state
    @State private var timeRemaining: Int = 0
    @State private var timer: Timer?

    // Navigation
    @State private var navigateToProject = false
    @State private var newRecordProject: RecordProject?
    @State private var isCreatingProject = false

    // Captain instructions for Step 2 (change every 30s within 180s)
    private let captainInstructions: [(Int, String)] = [
        (180, "اصعد وانزل على الدرجة بإيقاع ثابت 💪"),
        (150, "حافظ على الإيقاع... ٢٤ صعدة بالدقيقة"),
        (120, "ممتاز، كمّل نفس السرعة 🔥"),
        (90, "نص الطريق! لا توقف"),
        (60, "آخر دقيقة، اعطها كلشي!"),
        (30, "٣٠ ثانية وتخلص... كمّل!")
    ]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            switch step {
            case 1: explanationStep
            case 2: activeTestStep
            case 3: recoveryStep
            case 4: resultStep
            default: explanationStep
            }
        }
        .navigationTitle(step == 1 ? "قياس المحرك" : "")
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.layoutDirection, .rightToLeft)
        .navigationDestination(isPresented: $navigateToProject) {
            if let project = newRecordProject {
                RecordProjectView(project: project)
            }
        }
        .onDisappear {
            timer?.invalidate()
            // FIXED: endWorkout() is now synchronous
            if hrrManager.isWorkoutActive {
                hrrManager.endWorkout()
            }
        }
    }

    // MARK: - Step 1: Explanation

    private var explanationStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // Header icon
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(GymTheme.mint)
                    .padding(.top, 20)

                // Title
                VStack(spacing: 8) {
                    Text("قياس المحرك")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.primary)

                    Text("فحص جاهزية جسمك")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.5))
                }

                // Explanation card
                VStack(alignment: .trailing, spacing: 12) {
                    Text("جسمك فيه نظامين:")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.primary)

                    // CHANGED: Added السمبثاوي and الباراسمبثاوي
                    VStack(alignment: .trailing, spacing: 8) {
                        Text("واحد يدوس بنزين 🔥 السمبثاوي (للحركة والتوتر)")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.primary.opacity(0.7))

                        Text("وواحد يدوس بريك 🧊 الباراسمبثاوي (للراحة والاسترداد)")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.primary.opacity(0.7))
                    }

                    Text("هالفحص يكشف قوة البريك حقّك — يعني شلون جسمك يسترد بعد الجهد.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.7))
                        .multilineTextAlignment(.trailing)
                        .lineSpacing(4)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(hex: "F7F7F7"))
                )

                // How it works
                VStack(alignment: .trailing, spacing: 12) {
                    Text("كيف يشتغل؟")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.primary)

                    howItWorksRow(icon: "⏱️", text: "٣ دقايق جهد (صعود ونزول على درجة)")
                    howItWorksRow(icon: "🪑", text: "دقيقة راحة (كاعد ومرتاح)")
                    howItWorksRow(icon: "📊", text: "النتيجة فورية")
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(hex: "F7F7F7"))
                )

                // Watch requirement
                HStack(spacing: 10) {
                    Spacer()
                    Text("يحتاج Apple Watch حتى نقيس نبضك بدقة")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.6))
                    Text("⌚")
                        .font(.system(size: 18))
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(GymTheme.mint.opacity(0.15))
                )

                // Disclaimer
                Text("هذا التقييم لأغراض اللياقة فقط وليس بديلاً عن استشارة طبية.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.35))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                // CTA
                Button {
                    Task {
                        let authorized = await hrrManager.requestAuthorization()
                        if authorized {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                step = 2
                            }
                            startActiveTest()
                        }
                    }
                } label: {
                    ctaLabel("يلا نبدأ الفحص ⚡")
                }
                .buttonStyle(.plain)

                // Skip button
                Button {
                    skipAssessment()
                } label: {
                    Text("تخطي الفحص")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.35))
                }
                .buttonStyle(.plain)

                // Error display
                if let error = hrrManager.error {
                    Text(error)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.red.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
    }

    private func howItWorksRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Spacer()
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.primary.opacity(0.65))
            Text(icon)
                .font(.system(size: 18))
        }
    }

    // MARK: - Step 2: Active Test (3 min)

    private var activeTestStep: some View {
        VStack(spacing: 32) {
            Spacer()

            // Timer
            Text(formattedTime)
                .font(.system(size: 72, weight: .heavy, design: .rounded))
                .foregroundStyle(GymTheme.beige)
                .monospacedDigit()

            // Heart rate
            VStack(spacing: 4) {
                Text("\(Int(hrrManager.currentHeartRate))")
                    .font(.system(size: 48, weight: .heavy, design: .rounded))
                    .foregroundStyle(GymTheme.mint)
                    .monospacedDigit()
                    .contentTransition(.numericText())

                Text("bpm")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.primary.opacity(0.4))
            }

            // HR Zone indicator
            hrZoneIndicator

            // Captain instruction
            Text(currentCaptainInstruction)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(Color.primary.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .animation(.easeInOut(duration: 0.3), value: currentCaptainInstruction)

            Spacer()

            // FIXED: Show error if Watch isn't streaming HR
            if let errorMsg = hrrManager.error {
                Text(errorMsg)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            // Activity label
            HStack(spacing: 8) {
                Image(systemName: "figure.step.training")
                    .font(.system(size: 14))
                    .foregroundStyle(GymTheme.mint)
                Text("صعود ونزول على الدرجة")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.45))
            }
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity)
    }

    private var hrZoneIndicator: some View {
        let hr = hrrManager.currentHeartRate
        let zone: String
        let color: Color

        if hr < 100 {
            zone = "إحماء"
            color = Color.blue.opacity(0.6)
        } else if hr < 130 {
            zone = "معتدل"
            color = Color.green.opacity(0.7)
        } else if hr < 160 {
            zone = "مكثّف"
            color = Color.orange
        } else {
            zone = "أقصى"
            color = Color.red.opacity(0.8)
        }

        return Text(zone)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Capsule().fill(color))
    }

    private var currentCaptainInstruction: String {
        for (threshold, instruction) in captainInstructions {
            if timeRemaining >= threshold {
                return instruction
            }
        }
        return captainInstructions.last?.1 ?? ""
    }

    // MARK: - Step 3: Recovery (1 min)

    private var recoveryStep: some View {
        VStack(spacing: 32) {
            Spacer()

            // Recovery title
            Text("استرخ... تنفّس بعمق 🧘")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.primary)

            // Timer
            Text(formattedTime)
                .font(.system(size: 72, weight: .heavy, design: .rounded))
                .foregroundStyle(GymTheme.beige)
                .monospacedDigit()

            // Current HR (dropping)
            VStack(spacing: 4) {
                Text("\(Int(hrrManager.currentHeartRate))")
                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                    .foregroundStyle(GymTheme.mint)
                    .monospacedDigit()
                    .contentTransition(.numericText())

                Text("bpm")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.primary.opacity(0.4))
            }

            // Peak HR from Step 2
            HStack(spacing: 6) {
                Text("\(Int(hrrManager.peakHeartRate)) bpm")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary.opacity(0.5))
                Text("أعلى نبض:")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.4))
            }

            Spacer()

            // Breathing prompt
            Image(systemName: "wind")
                .font(.system(size: 28))
                .foregroundStyle(GymTheme.mint.opacity(0.5))
                .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Step 4: Result

    private var resultStep: some View {
        let level = hrrManager.calculateRecoveryLevel()

        return ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                Spacer().frame(height: 20)

                // Result icon
                resultIcon(for: level)

                // Level title
                Text(level.titleAr)
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.primary)

                levelEmoji(for: level)

                // Stats card
                VStack(spacing: 14) {
                    statRow(label: "أعلى نبض", value: "\(Int(hrrManager.peakHeartRate)) bpm")
                    Divider().opacity(0.3)
                    statRow(label: "نبض الاسترداد", value: "\(Int(hrrManager.recoveryHeartRate)) bpm")
                    Divider().opacity(0.3)
                    statRow(label: "الفرق", value: "\(Int(hrrManager.hrrDrop)) نبضة")
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(hex: "F7F7F7"))
                )

                // Captain comment
                VStack(alignment: .trailing, spacing: 8) {
                    Text("🗨️ كابتن حمّودي:")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.primary.opacity(0.5))

                    Text(level.captainComment)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.8))
                        .multilineTextAlignment(.trailing)
                        .lineSpacing(4)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(hex: "F7F7F7"))
                )

                // Disclaimer
                Text("هذا التقييم لأغراض اللياقة فقط وليس بديلاً عن استشارة طبية.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.35))
                    .multilineTextAlignment(.center)

                // CTA
                Button {
                    createProjectWithHRR()
                } label: {
                    HStack {
                        Spacer()
                        if isCreatingProject {
                            ProgressView()
                                .tint(.primary)
                        } else {
                            Text("ابدأ الخطة 🚀")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.primary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(GymTheme.mint.opacity(0.5))
                    )
                }
                .buttonStyle(.plain)
                .disabled(isCreatingProject)
                .opacity(isCreatingProject ? 0.7 : 1)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
    }

    private func resultIcon(for level: RecoveryLevel) -> some View {
        let color: Color = switch level {
        case .excellent: GymTheme.mint
        case .good: GymTheme.beige
        case .needsWork: Color.orange.opacity(0.7)
        }

        return Image(systemName: level.iconName)
            .font(.system(size: 40, weight: .medium))
            .foregroundStyle(color)
            .frame(width: 90, height: 90)
            .background(Circle().fill(color.opacity(0.2)))
    }

    private func levelEmoji(for level: RecoveryLevel) -> some View {
        let emoji: String = switch level {
        case .excellent: "🔥"
        case .good: "👍"
        case .needsWork: "💪"
        }
        return Text(emoji)
            .font(.system(size: 32))
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Color.primary)
            Spacer()
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.primary.opacity(0.5))
        }
    }

    // MARK: - Shared Components

    private func ctaLabel(_ text: String) -> some View {
        HStack {
            Spacer()
            Text(text)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(Color.primary)
            Spacer()
        }
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(GymTheme.mint.opacity(0.5))
        )
    }

    private var formattedTime: String {
        let minutes = timeRemaining / 60
        let seconds = timeRemaining % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Timer Logic

    private func startActiveTest() {
        timeRemaining = 180 // 3 minutes

        // FIXED: startStepTest() is now synchronous — launches workout on Watch
        // via PhoneConnectivityManager (no longer async throws)
        hrrManager.startStepTest()

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                if timeRemaining > 0 {
                    timeRemaining -= 1
                } else {
                    timer?.invalidate()
                    // Auto-advance to recovery
                    withAnimation(.easeInOut(duration: 0.4)) {
                        step = 3
                    }
                    startRecoveryPhase()
                }
            }
        }
    }

    private func startRecoveryPhase() {
        timeRemaining = 60 // 1 minute

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                if timeRemaining > 0 {
                    timeRemaining -= 1
                } else {
                    timer?.invalidate()
                    // FIXED: Capture recovery HR and end workout on Watch
                    // endWorkout() is now synchronous (sends end command to Watch)
                    hrrManager.captureRecoveryHR()
                    hrrManager.endWorkout()
                    // Auto-advance to result
                    withAnimation(.easeInOut(duration: 0.4)) {
                        step = 4
                    }
                }
            }
        }
    }

    // MARK: - Project Creation

    private func createProjectWithHRR() {
        isCreatingProject = true
        let level = hrrManager.calculateRecoveryLevel()

        Task {
            let planJSON = RecordProjectManager.generateDefaultPlan(
                for: record,
                totalWeeks: record.estimatedWeeks,
                hrrLevel: level.rawValue
            )

            let project = RecordProjectManager.shared.createProject(
                record: record,
                userBestAtStart: 0,
                totalWeeks: record.estimatedWeeks,
                planJSON: planJSON,
                difficulty: record.difficulty.labelAr,
                userWeight: Double(MemoryStore.shared.get("weight") ?? ""),
                fitnessLevel: MemoryStore.shared.get("fitness_level"),
                hrrPeakHR: hrrManager.peakHeartRate,
                hrrRecoveryHR: hrrManager.recoveryHeartRate,
                hrrLevel: level.rawValue
            )

            newRecordProject = project
            isCreatingProject = false

            if project != nil {
                navigateToProject = true
            }
        }
    }

    private func skipAssessment() {
        isCreatingProject = true

        Task {
            let planJSON = RecordProjectManager.generateDefaultPlan(
                for: record,
                totalWeeks: record.estimatedWeeks
            )

            let project = RecordProjectManager.shared.createProject(
                record: record,
                userBestAtStart: 0,
                totalWeeks: record.estimatedWeeks,
                planJSON: planJSON,
                difficulty: record.difficulty.labelAr,
                userWeight: Double(MemoryStore.shared.get("weight") ?? ""),
                fitnessLevel: MemoryStore.shared.get("fitness_level")
            )

            newRecordProject = project
            isCreatingProject = false

            if project != nil {
                navigateToProject = true
            }
        }
    }
}
