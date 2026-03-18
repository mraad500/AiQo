import SwiftUI

/// شاشة المراجعة الأسبوعية وضبط البوصلة
struct WeeklyReviewView: View {
    let project: RecordProject
    @State private var currentWeight = ""
    @State private var bestPerformance = ""
    @State private var feedback = ""
    @State private var weekRating = 0
    @State private var selectedObstacle = ""
    @State private var isSubmitting = false
    @State private var showResult = false
    @State private var reviewResult: ReviewResult?

    @Environment(\.dismiss) private var dismiss

    private let obstacles = [
        "إصابة / ألم",
        "انشغال / وقت",
        "تعب / إرهاق",
        "ما في شي، كل شي تمام"
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                weekHeader
                weightInput
                performanceInput
                feedbackInput
                ratingSection
                obstaclesSection
                submitButton
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .background(Color.white.ignoresSafeArea())
        .navigationTitle("المراجعة وضبط البوصلة")
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.layoutDirection, .rightToLeft)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("إغلاق") { dismiss() }
            }
        }
        .sheet(isPresented: $showResult) {
            if let result = reviewResult {
                WeeklyReviewResultView(result: result) {
                    showResult = false
                    dismiss()
                }
            }
        }
    }

    // MARK: - Week Header

    private var weekHeader: some View {
        Text("الأسبوع \(project.currentWeek)")
            .font(.system(size: 22, weight: .heavy, design: .rounded))
            .foregroundStyle(Color.primary)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    // MARK: - Weight Input

    private var weightInput: some View {
        VStack(alignment: .trailing, spacing: 8) {
            Label("⚖️ وزنك الحالي", systemImage: "")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Color.primary)

            HStack(spacing: 8) {
                Text("كغم")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.45))

                TextField("", text: $currentWeight)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(hex: "F5F5F5"))
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(hex: "FAFAFA"))
        )
    }

    // MARK: - Performance Input

    private var performanceInput: some View {
        VStack(alignment: .trailing, spacing: 8) {
            Text("💪 أفضل أداء هالأسبوع")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Color.primary)

            HStack(spacing: 8) {
                Text(project.unit)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.45))

                TextField("", text: $bestPerformance)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(hex: "F5F5F5"))
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(hex: "FAFAFA"))
        )
    }

    // MARK: - Feedback Input

    private var feedbackInput: some View {
        VStack(alignment: .trailing, spacing: 8) {
            Text("📝 شلون كانت التمارين؟")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Color.primary)

            TextEditor(text: $feedback)
                .font(.system(size: 15, weight: .regular))
                .frame(minHeight: 80)
                .padding(8)
                .scrollContentBackground(.hidden)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(hex: "F5F5F5"))
                )
                .multilineTextAlignment(.trailing)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(hex: "FAFAFA"))
        )
    }

    // MARK: - Rating Section

    private var ratingSection: some View {
        VStack(alignment: .trailing, spacing: 8) {
            Text("⭐ قيّم أسبوعك")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Color.primary)

            HStack(spacing: 8) {
                Spacer()
                ForEach(1...5, id: \.self) { star in
                    Button {
                        weekRating = star
                    } label: {
                        Image(systemName: star <= weekRating ? "star.fill" : "star")
                            .font(.system(size: 28))
                            .foregroundStyle(star <= weekRating ? GymTheme.gold : Color.primary.opacity(0.15))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(hex: "FAFAFA"))
        )
    }

    // MARK: - Obstacles Section

    private var obstaclesSection: some View {
        VStack(alignment: .trailing, spacing: 10) {
            Text("😤 في شي منعك أو أثر عليك؟")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Color.primary)

            ForEach(obstacles, id: \.self) { obstacle in
                Button {
                    selectedObstacle = obstacle
                } label: {
                    HStack(spacing: 10) {
                        Spacer()
                        Text(obstacle)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.primary.opacity(0.7))

                        Circle()
                            .stroke(selectedObstacle == obstacle ? GymTheme.mint : Color.primary.opacity(0.15), lineWidth: 2)
                            .frame(width: 22, height: 22)
                            .overlay {
                                if selectedObstacle == obstacle {
                                    Circle()
                                        .fill(GymTheme.mint)
                                        .frame(width: 12, height: 12)
                                }
                            }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(hex: "FAFAFA"))
        )
    }

    // MARK: - Submit Button

    private var submitButton: some View {
        Button {
            submitReview()
        } label: {
            HStack {
                Spacer()
                if isSubmitting {
                    ProgressView()
                        .tint(.primary)
                } else {
                    Text("أرسل للكابتن حمّودي 📤")
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
        .disabled(isSubmitting)
    }

    // MARK: - Submit Logic

    private func submitReview() {
        isSubmitting = true

        Task {
            let result = await sendReviewToLLM()

            let log = WeeklyLog(weekNumber: project.currentWeek)
            log.currentWeight = Double(currentWeight)
            log.performanceThisWeek = Double(bestPerformance)
            log.userFeedback = feedback
            log.weekRating = weekRating
            log.obstacles = selectedObstacle
            log.isOnTrack = result?.isOnTrack ?? true
            log.captainNotes = result?.captainMessage
            log.adjustments = result?.adjustments

            RecordProjectManager.shared.addWeeklyLog(log, to: project)

            // تحديث الخطة إذا في تعديلات
            if let result, let newPlan = result.nextWeekPlanJSON {
                RecordProjectManager.shared.updatePlan(
                    for: project,
                    newPlanJSON: newPlan,
                    newTotalWeeks: result.updatedTotalWeeks
                )
            }

            // تحديث الذاكرة
            if let weight = Double(currentWeight) {
                MemoryStore.shared.set("weight", value: currentWeight, category: "body", source: "user_explicit", confidence: 1.0)
                _ = weight // suppress unused warning
            }

            reviewResult = result ?? ReviewResult(
                isOnTrack: true,
                captainMessage: "أحسنت! كمّل بنفس المستوى 💪",
                adjustments: nil,
                nextWeekPlanJSON: nil,
                updatedTotalWeeks: nil,
                warningIfAny: nil
            )

            isSubmitting = false
            showResult = true
        }
    }

    private func sendReviewToLLM() async -> ReviewResult? {
        let systemPrompt = """
        أنت كابتن حمّودي. المستخدم أكمل أسبوع \(project.currentWeek) من مشروع كسر رقم "\(project.recordTitle)".

        بيانات المشروع:
        - الهدف: \(project.targetValue) \(project.unit)
        - الأسبوع: \(project.currentWeek) من \(project.totalWeeks)
        - أفضل أداء سابق: \(project.bestPerformance)

        بيانات المراجعة:
        - الوزن الحالي: \(currentWeight) كغم
        - أفضل أداء هالأسبوع: \(bestPerformance)
        - رأي المستخدم: "\(feedback)"
        - تقييم الأسبوع: \(weekRating)/5
        - عوائق: \(selectedObstacle)

        المطلوب:
        1. حلل التقدم (هل ماشي صح أو يحتاج تعديل)
        2. أرجع JSON فقط بدون markdown:
        {
          "isOnTrack": true,
          "captainMessage": "رسالة تحفيزية قصيرة بالعامي",
          "adjustments": "وصف التعديلات أو null",
          "updatedTotalWeeks": null,
          "warningIfAny": null
        }
        """

        do {
            let info = Bundle.main.infoDictionary ?? [:]
            let env = ProcessInfo.processInfo.environment
            let apiKey = normalized(env["CAPTAIN_API_KEY"])
                ?? normalized(info["CAPTAIN_API_KEY"] as? String)
                ?? normalized(env["COACH_BRAIN_LLM_API_KEY"])
                ?? normalized(info["COACH_BRAIN_LLM_API_KEY"] as? String)

            guard let apiKey, let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
                return nil
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 25
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

            let body: [String: Any] = [
                "model": "gpt-4o-mini",
                "messages": [
                    ["role": "system", "content": systemPrompt],
                    ["role": "user", "content": "راجع أسبوعي وعطني رأيك"]
                ],
                "max_tokens": 300,
                "temperature": 0.7
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else { return nil }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let content = message["content"] as? String else { return nil }

            let cleanContent = content
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard let contentData = cleanContent.data(using: .utf8),
                  let resultDict = try JSONSerialization.jsonObject(with: contentData) as? [String: Any] else { return nil }

            return ReviewResult(
                isOnTrack: resultDict["isOnTrack"] as? Bool ?? true,
                captainMessage: resultDict["captainMessage"] as? String ?? "أحسنت!",
                adjustments: resultDict["adjustments"] as? String,
                nextWeekPlanJSON: nil,
                updatedTotalWeeks: resultDict["updatedTotalWeeks"] as? Int,
                warningIfAny: resultDict["warningIfAny"] as? String
            )
        } catch {
            return nil
        }
    }

    private func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !(trimmed.hasPrefix("$(") && trimmed.hasSuffix(")")) else { return nil }
        return trimmed
    }
}

// MARK: - Review Result

struct ReviewResult {
    let isOnTrack: Bool
    let captainMessage: String
    let adjustments: String?
    let nextWeekPlanJSON: String?
    let updatedTotalWeeks: Int?
    let warningIfAny: String?
}
