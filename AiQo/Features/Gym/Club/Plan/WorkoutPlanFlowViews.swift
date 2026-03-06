import SwiftData
import SwiftUI

struct WorkoutPlanDashboard: View {
    @Environment(\.modelContext) private var modelContext

    @State private var savedDailyPlans: [WorkoutPlanDailySnapshot] = []

    private let mintTint = Color(red: 0.82, green: 0.95, blue: 0.87)
    private let beigeTint = Color(red: 0.98, green: 0.90, blue: 0.78)

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                NavigationLink {
                    CaptainPlanChatView()
                } label: {
                    captainHeroCard
                }
                .buttonStyle(.plain)

                Text("خطط التمارين اليومية")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .padding(.top, 2)

                dailyPlansSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(
            LinearGradient(
                colors: [
                    mintTint.opacity(0.24),
                    Color(.systemBackground),
                    Color(.systemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationTitle("خطة التمرين")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: reloadDailyPlans)
        .onReceive(NotificationCenter.default.publisher(for: .aiqoWorkoutPlanSaved)) { _ in
            reloadDailyPlans()
        }
    }

    private var captainHeroCard: some View {
        HStack(spacing: 16) {
            Image("Hammoudi5")
                .resizable()
                .scaledToFit()
                .frame(width: 124, height: 170, alignment: .bottom)
                .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 10) {
                Text("إنشاء خطة تمارين مع الكابتن")
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Text("اضغط وابدأ")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                    Image(systemName: "arrow.left.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(.primary.opacity(0.72))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.33))
                )
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(minHeight: 200)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            PastelGlassSurface(tint: mintTint)
        )
    }

    @ViewBuilder
    private var dailyPlansSection: some View {
        if savedDailyPlans.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("لا توجد خطط مثبتة حالياً.")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)

                Text("ابدأ محادثة الكابتن بالأعلى حتى نملأ الجدول تلقائياً.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                PastelGlassSurface(tint: beigeTint)
            )
        } else {
            LazyVStack(spacing: 12) {
                ForEach(savedDailyPlans) { snapshot in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "calendar")
                                .font(.system(size: 14, weight: .semibold))
                            Text(snapshot.formattedDate)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.secondary)

                        ForEach(snapshot.workouts, id: \.self) { workout in
                            HStack(spacing: 9) {
                                Circle()
                                    .fill(Color.primary.opacity(0.35))
                                    .frame(width: 6, height: 6)

                                Text(workout)
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        PastelGlassSurface(tint: mintTint.opacity(0.95))
                    )
                }
            }
        }
    }

    private func reloadDailyPlans() {
        savedDailyPlans = WorkoutPlanMemoryStore.fetchSavedPlans(modelContext: modelContext)
    }
}

struct CaptainPlanChatView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var globalBrain: CaptainViewModel
    @State private var isSavingPlan = false
    @State private var showSuccessState = false
    @State private var errorMessage: String?
    @FocusState private var inputFieldFocused: Bool

    private let userBubbleTint = Color(red: 0.82, green: 0.95, blue: 0.87)
    private let captainBubbleTint = Color(red: 0.92, green: 0.89, blue: 0.83)
    private let screenMintTint = Color(red: 0.82, green: 0.95, blue: 0.87)
    private let screenBeigeTint = Color(red: 0.98, green: 0.90, blue: 0.78)
    private let chatBottomID = "captain-plan-chat-bottom"

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    screenMintTint.opacity(0.22),
                    Color(.systemBackground),
                    Color(.systemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                messagesSection

                if let workoutPlan = globalBrain.currentWorkoutPlan {
                    pinPlanButton(for: workoutPlan)
                }

                if showSuccessState {
                    successCard
                }

                if let errorMessage {
                    errorCard(errorMessage)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 6)
        }
        .navigationTitle("محادثة الكابتن")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            inputBar
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 10)
                .background(Color.clear)
        }
        .task {
            bootstrapPlanChatIfNeeded()
        }
    }

    private var messagesSection: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 10) {
                    ForEach(globalBrain.messages) { message in
                        messageRow(message)
                            .id(message.id)
                    }

                    if let workoutPlan = globalBrain.currentWorkoutPlan {
                        pendingPlanPreviewRow(for: workoutPlan)
                            .id("captain-plan-preview")
                    }

                    if globalBrain.isLoading {
                        typingIndicatorRow
                    }

                    Color.clear
                        .frame(height: 1)
                        .id(chatBottomID)
                }
                .padding(10)
            }
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.45), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.07), radius: 12, x: 0, y: 7)
            .onAppear {
                scrollToBottom(proxy: proxy, animated: false)
            }
            .onChange(of: globalBrain.messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: globalBrain.isLoading) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: globalBrain.currentWorkoutPlan != nil) { _, _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }

    private func messageRow(_ message: ChatMessage) -> some View {
        HStack {
            if message.isUser { Spacer(minLength: 36) }

            Text(message.text)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(.ultraThinMaterial)

                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill((message.isUser ? userBubbleTint : captainBubbleTint).opacity(0.82))
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.45), lineWidth: 1)
                )

            if !message.isUser { Spacer(minLength: 36) }
        }
    }

    private func pendingPlanPreviewRow(for workoutPlan: WorkoutPlan) -> some View {
        HStack {
            CaptainPendingWorkoutPreviewCard(plan: workoutPlan)
            Spacer(minLength: 36)
        }
    }

    private var typingIndicatorRow: some View {
        HStack {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("الكابتن يكتب...")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.ultraThinMaterial)

                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(screenBeigeTint.opacity(0.7))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.45), lineWidth: 1)
            )

            Spacer(minLength: 36)
        }
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("اكتب رسالتك للكابتن...", text: $globalBrain.inputText)
                .textInputAutocapitalization(.sentences)
                .autocorrectionDisabled(false)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.systemBackground).opacity(0.82))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                )
                .focused($inputFieldFocused)
                .onSubmit {
                    sendCurrentMessage()
                }

            Button {
                sendCurrentMessage()
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.black.opacity(0.82))
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(userBubbleTint)
                    )
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(trimmedInput.isEmpty || isSavingPlan || globalBrain.isLoading)
        }
        .padding(8)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)

                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(screenMintTint.opacity(0.42))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.45), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.07), radius: 10, x: 0, y: 6)
    }

    private func pinPlanButton(for workoutPlan: WorkoutPlan) -> some View {
        Button {
            pinPlan(workoutPlan)
        } label: {
            Text("موافق، ثبّت الخطة بالجدول")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.black.opacity(0.85))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(screenBeigeTint)
                )
        }
        .buttonStyle(.plain)
        .disabled(isSavingPlan)
        .opacity(isSavingPlan ? 0.6 : 1)
    }

    private var successCard: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 18, weight: .bold))
            Text("تم تثبيت الخطة بنجاح ورح تنعرض بالجدول اليومي.")
                .font(.system(size: 14, weight: .bold, design: .rounded))
        }
        .foregroundStyle(.green)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            PastelGlassSurface(tint: screenMintTint)
        )
    }

    private func errorCard(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(.red)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                PastelGlassSurface(tint: screenBeigeTint)
            )
    }

    private func sendCurrentMessage() {
        let message = trimmedInput
        guard !message.isEmpty else { return }

        showSuccessState = false
        errorMessage = nil
        globalBrain.sendMessage(message)
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool = true) {
        let action = {
            proxy.scrollTo(chatBottomID, anchor: .bottom)
        }

        if animated {
            withAnimation(.easeOut(duration: 0.22)) {
                action()
            }
        } else {
            action()
        }
    }

    private func pinPlan(_ workoutPlan: WorkoutPlan) {
        guard !isSavingPlan else { return }
        isSavingPlan = true
        errorMessage = nil

        do {
            try WorkoutPlanMemoryStore.savePlan(
                workoutPlan: workoutPlan,
                modelContext: modelContext
            )

            NotificationCenter.default.post(name: .aiqoWorkoutPlanSaved, object: nil)
            showSuccessState = true
            inputFieldFocused = false
            globalBrain.messages.append(
                ChatMessage(
                    text: "تمام بطل، ثبتتلك خطة \(workoutPlan.title) بالجدول اليومي.",
                    isUser: false
                )
            )

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) {
                dismiss()
            }
        } catch {
            errorMessage = "تعذر تثبيت الخطة حالياً. حاول مرة ثانية."
        }

        isSavingPlan = false
    }


    private var trimmedInput: String {
        globalBrain.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func bootstrapPlanChatIfNeeded() {
        guard globalBrain.currentWorkoutPlan == nil else { return }
        guard !globalBrain.isLoading else { return }

        let kickoffPrompt = "حتى أبني خطة تمرين شخصية، اكتب وزنك الحالي وهدفك مثل: 95 كيلو وتنشيف."
        guard !globalBrain.messages.contains(where: { $0.text == kickoffPrompt }) else { return }

        let hasUserMessages = globalBrain.messages.contains(where: \.isUser)
        guard !hasUserMessages else { return }

        globalBrain.messages.append(
            ChatMessage(
                text: kickoffPrompt,
                isUser: false
            )
        )
    }
}

private struct CaptainPendingWorkoutPreviewCard: View {
    let plan: WorkoutPlan

    private var previewHeight: CGFloat {
        let rowHeight: CGFloat = 52
        return min(max(CGFloat(plan.exercises.count) * rowHeight, 92), 220)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.98, green: 0.90, blue: 0.78),
                                    Color(red: 0.82, green: 0.95, blue: 0.87)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Image(systemName: "list.bullet.clipboard")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.black.opacity(0.72))
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Preview")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    Text(plan.title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }
            }

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    ForEach(plan.exercises) { exercise in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(exercise.name)
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.primary)
                                    .lineLimit(2)

                                Text(exercise.repsOrDuration)
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 8)

                            Text("\(exercise.sets) جولات")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(Color.white.opacity(0.52))
                                )
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white.opacity(0.20))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(Color.white.opacity(0.34), lineWidth: 1)
                                )
                        )
                    }
                }
                .padding(.trailing, 4)
            }
            .frame(height: previewHeight)
            .scrollBounceBehavior(.basedOnSize)
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

private extension Exercise {
    var workoutTaskTitle: String {
        "\(name) - \(sets) جولات - \(repsOrDuration)"
    }
}

private struct WorkoutPlanDailySnapshot: Identifiable {
    let id: String
    let date: Date
    let workouts: [String]

    var formattedDate: String {
        WorkoutPlanMemoryStore.dateLabelFormatter.string(from: date)
    }
}

private enum WorkoutPlanMemoryStore {
    static let dateLabelFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = .current
        formatter.locale = .current
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private static let recordIDFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = .current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func savePlan(
        workoutPlan: WorkoutPlan,
        modelContext: ModelContext
    ) throws {
        let now = Date()
        let todayID = recordIDFormatter.string(from: now)

        let descriptor = FetchDescriptor<AiQoDailyRecord>(
            predicate: #Predicate { record in
                record.id == todayID
            }
        )

        let record: AiQoDailyRecord
        if let existing = try modelContext.fetch(descriptor).first {
            record = existing
        } else {
            let created = AiQoDailyRecord(date: now)
            modelContext.insert(created)
            record = created
        }

        for task in record.workouts {
            modelContext.delete(task)
        }
        record.workouts = []

        let workouts = workoutPlan.exercises.map { exercise in
            let workout = WorkoutTask(title: exercise.workoutTaskTitle, isCompleted: false)
            workout.dailyRecord = record
            modelContext.insert(workout)
            return workout
        }

        record.workouts = workouts
        record.captainDailySuggestion = workoutPlan.title

        try modelContext.save()
    }

    static func fetchSavedPlans(modelContext: ModelContext) -> [WorkoutPlanDailySnapshot] {
        let descriptor = FetchDescriptor<AiQoDailyRecord>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let records = (try? modelContext.fetch(descriptor)) ?? []

        return records
            .filter { !$0.workouts.isEmpty }
            .map { record in
                WorkoutPlanDailySnapshot(
                    id: record.id,
                    date: record.date,
                    workouts: record.workouts.map(\.title)
                )
            }
    }
}

private struct PastelGlassSurface: View {
    let tint: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(tint.opacity(0.68))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.46), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.07), radius: 12, x: 0, y: 7)
    }
}

private extension Notification.Name {
    static let aiqoWorkoutPlanSaved = Notification.Name("aiqo.workout.plan.saved")
}
