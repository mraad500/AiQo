import SwiftUI

struct CaptainKitchenChatView: View {
    @EnvironmentObject private var kitchenStore: KitchenPersistenceStore

    @State private var messages: [KitchenChatMessage] = [
        KitchenChatMessage(
            text: "kitchen.captain.welcome".localized,
            isUser: false
        )
    ]
    @State private var inputText: String = ""
    @State private var isSending: Bool = false
    @State private var draftManualPlan: KitchenMealPlan?

    private let generationService = KitchenPlanGenerationService()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.kitchenMint.opacity(0.22),
                    Color(.systemBackground),
                    Color(.systemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                quickActionsSection

                if let draftManualPlan {
                    draftPinSection(plan: draftManualPlan)
                }

                messagesSection
                inputSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 14)
        }
        .navigationTitle("kitchen.captain.title".localized)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private extension CaptainKitchenChatView {
    var quickActionsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                quickActionButton(title: "kitchen.quick.3days".localized, icon: "calendar") {
                    requestPlan(days: 3, triggerText: "kitchen.quick.3days".localized)
                }
                quickActionButton(title: "kitchen.quick.week".localized, icon: "calendar.badge.clock") {
                    requestPlan(days: 7, triggerText: "kitchen.quick.week".localized)
                }
                quickActionButton(title: "kitchen.quick.10min".localized, icon: "timer") {
                    sendMessage("kitchen.quick.10min".localized)
                }
                quickActionButton(title: "kitchen.quick.highProtein".localized, icon: "bolt.heart.fill") {
                    sendMessage("kitchen.quick.highProtein".localized)
                }
                quickActionButton(title: "kitchen.quick.swap".localized, icon: "arrow.triangle.2.circlepath") {
                    sendMessage("kitchen.quick.swap".localized)
                }
            }
            .padding(8)
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.55), lineWidth: 1)
        )
    }

    func quickActionButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(Color(.secondarySystemBackground).opacity(0.85))
            )
        }
        .buttonStyle(.plain)
        .disabled(isSending)
    }

    func draftPinSection(plan: KitchenMealPlan) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("kitchen.captain.draftDetected".localized)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)

            Text("kitchen.captain.draftHint".localized)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.primary)

            Button {
                pinDraftPlan(plan)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "pin.fill")
                    Text("kitchen.captain.pinDraft".localized)
                }
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.kitchenMint)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.45), lineWidth: 1)
        )
    }

    var messagesSection: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(messages) { message in
                        messageBubble(for: message)
                            .id(message.id)
                    }

                    if isSending {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("...")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                            Spacer()
                        }
                        .padding(.horizontal, 6)
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 8)
            }
            .onChange(of: messages.count) {
                guard let last = messages.last else { return }
                withAnimation(.easeOut(duration: 0.22)) {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
        .frame(maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.6), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 18, x: 0, y: 7)
    }

    func messageBubble(for message: KitchenChatMessage) -> some View {
        HStack {
            if message.isUser { Spacer(minLength: 40) }

            Text(message.text)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.primary)
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(message.isUser ? Color.kitchenMint.opacity(0.92) : Color(.secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(Color.white.opacity(message.isUser ? 0.2 : 0.45), lineWidth: 1)
                )

            if !message.isUser { Spacer(minLength: 40) }
        }
    }

    var inputSection: some View {
        HStack(spacing: 10) {
            TextField("captain.input.prompt".localized, text: $inputText)
                .textInputAutocapitalization(.sentences)
                .autocorrectionDisabled(false)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .padding(.horizontal, 13)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.secondarySystemBackground).opacity(0.9))
                )

            Button {
                sendMessage(inputText)
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Color.kitchenMint))
                    .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.45), lineWidth: 1)
        )
    }

    func sendMessage(_ rawText: String) {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }

        messages.append(.init(text: text, isUser: true))
        inputText = ""

        if let manualPlan = extractManualPlan(from: text) {
            draftManualPlan = manualPlan
            messages.append(.init(text: "kitchen.captain.draftHint".localized, isUser: false))
            return
        }

        if let days = inferredPlanDays(from: text) {
            requestPlan(days: days, triggerText: text)
            return
        }

        isSending = true

        Task {
            let reply = await generationService.generateKitchenReply(
                userMessage: text,
                fridgeItems: kitchenStore.fridgeItems,
                userGoal: UserProfileStore.shared.current.goalText,
                cookingTimeMinutes: 30
            )

            await MainActor.run {
                messages.append(.init(text: reply, isUser: false))
                if let manualPlan = extractManualPlan(from: reply) {
                    draftManualPlan = manualPlan
                    messages.append(.init(text: "kitchen.captain.draftHint".localized, isUser: false))
                }
                isSending = false
            }
        }
    }

    func requestPlan(days: Int, triggerText: String) {
        guard !isSending else { return }
        isSending = true

        Task {
            let plan = await generationService.generatePlan(
                days: days,
                triggerText: triggerText,
                fridgeItems: kitchenStore.fridgeItems,
                userGoal: UserProfileStore.shared.current.goalText,
                cookingTimeMinutes: 30
            )

            await MainActor.run {
                kitchenStore.setPinnedPlan(plan)
                draftManualPlan = nil
                messages.append(
                    .init(
                        text: String(
                            format: "kitchen.captain.planReady".localized,
                            plan.days
                        ),
                        isUser: false
                    )
                )
                isSending = false
            }
        }
    }

    func pinDraftPlan(_ plan: KitchenMealPlan) {
        kitchenStore.setPinnedPlan(plan)
        draftManualPlan = nil
        messages.append(.init(text: "kitchen.captain.pinSuccess".localized, isUser: false))
    }

    func inferredPlanDays(from text: String) -> Int? {
        let lowercase = text.lowercased()
        let likelyPlanIntent = lowercase.contains("plan") ||
        lowercase.contains("خطة") ||
        lowercase.contains("وجبات")

        guard likelyPlanIntent else { return nil }

        if lowercase.contains("7") || lowercase.contains("week") || lowercase.contains("أسبوع") {
            return 7
        }

        if lowercase.contains("3") || lowercase.contains("ثلاث") {
            return 3
        }

        return 3
    }

    func extractManualPlan(from text: String) -> KitchenMealPlan? {
        let breakfastKeywords = ["الفطور", "فطور", "breakfast"]
        let lunchKeywords = ["الغداء", "غداء", "lunch"]
        let dinnerKeywords = ["العشاء", "عشاء", "dinner"]

        guard let breakfastRange = firstKeywordRange(in: text, keywords: breakfastKeywords),
              let lunchRange = firstKeywordRange(in: text, keywords: lunchKeywords),
              let dinnerRange = firstKeywordRange(in: text, keywords: dinnerKeywords)
        else {
            return nil
        }

        let markers: [(type: KitchenMealType, range: Range<String.Index>)] = [
            (.breakfast, breakfastRange),
            (.lunch, lunchRange),
            (.dinner, dinnerRange)
        ]
            .sorted(by: { $0.range.lowerBound < $1.range.lowerBound })

        var titlesByType: [KitchenMealType: String] = [:]

        for (index, marker) in markers.enumerated() {
            let nextStart = index + 1 < markers.count ? markers[index + 1].range.lowerBound : text.endIndex
            let rawSegment = String(text[marker.range.upperBound..<nextStart])
            let title = cleanedMealTitle(rawSegment)
            guard !title.isEmpty else { return nil }
            titlesByType[marker.type] = title
        }

        guard let breakfastTitle = titlesByType[.breakfast],
              let lunchTitle = titlesByType[.lunch],
              let dinnerTitle = titlesByType[.dinner]
        else {
            return nil
        }

        let days = inferredPlanDays(from: text) ?? 3
        let safeDays = days == 7 ? 7 : 3

        var meals: [KitchenPlannedMeal] = []
        for day in 1...safeDays {
            meals.append(makeManualMeal(day: day, type: .breakfast, title: breakfastTitle))
            meals.append(makeManualMeal(day: day, type: .lunch, title: lunchTitle))
            meals.append(makeManualMeal(day: day, type: .dinner, title: dinnerTitle))
        }

        return KitchenMealPlan(startDate: Date(), days: safeDays, meals: meals)
    }

    func makeManualMeal(day: Int, type: KitchenMealType, title: String) -> KitchenPlannedMeal {
        KitchenPlannedMeal(
            dayIndex: day,
            type: type,
            title: title,
            calories: type.defaultCalories,
            protein: nil,
            ingredients: ingredientsFromManualTitle(title, type: type)
        )
    }

    func ingredientsFromManualTitle(_ title: String, type: KitchenMealType) -> [KitchenIngredient] {
        let separators = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ",،+-/|"))
        let stopWords: Set<String> = ["هذا", "هاي", "with", "and", "the", "وجبة", "meal", "مع", "و"]

        let tokens = title
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { token in
                !token.isEmpty && token.count > 1 && !stopWords.contains(token.lowercased())
            }

        let ingredientTokens = Array(tokens.prefix(3))
        if ingredientTokens.isEmpty {
            return [KitchenIngredient(name: type.localizedTitle)]
        }

        return ingredientTokens.map { KitchenIngredient(name: $0) }
    }

    func firstKeywordRange(in text: String, keywords: [String]) -> Range<String.Index>? {
        var bestRange: Range<String.Index>?

        for keyword in keywords {
            guard let range = text.range(of: keyword, options: [.caseInsensitive, .diacriticInsensitive]) else {
                continue
            }

            if let currentBest = bestRange {
                if range.lowerBound < currentBest.lowerBound {
                    bestRange = range
                }
            } else {
                bestRange = range
            }
        }

        return bestRange
    }

    func cleanedMealTitle(_ rawText: String) -> String {
        var cleaned = rawText
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let prefixes = [":", "-", "=", "=>", "هو", "هي", "this is", "this", "is", "هذا", "هاي"]

        var didTrim = true
        while didTrim {
            didTrim = false
            for prefix in prefixes {
                if cleaned.lowercased().hasPrefix(prefix.lowercased()) {
                    cleaned.removeFirst(prefix.count)
                    cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
                    didTrim = true
                }
            }
        }

        while cleaned.contains("  ") {
            cleaned = cleaned.replacingOccurrences(of: "  ", with: " ")
        }

        return cleaned
    }
}

private struct KitchenChatMessage: Identifiable, Equatable {
    let id: UUID
    let text: String
    let isUser: Bool
    let timestamp: Date

    init(id: UUID = UUID(), text: String, isUser: Bool, timestamp: Date = Date()) {
        self.id = id
        self.text = text
        self.isUser = isUser
        self.timestamp = timestamp
    }
}
