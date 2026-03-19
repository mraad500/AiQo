import Foundation

/// يبني الـ system prompt للكلاود بثلاث طبقات: شخصية + ذاكرة طويلة + حالة بيولوجية
/// "Zero Digital Pollution" — كل توكن له هدف، ما فيه حشو
struct CaptainPromptBuilder: Sendable {

    func build(for request: HybridBrainRequest) -> String {
        [
            layerCorePersona(language: request.language),
            layerLongTermMemory(profileSummary: request.userProfileSummary),
            layerBioState(data: request.contextData),
            layerCircadianTone(data: request.contextData, language: request.language),
            layerScreenContext(request: request),
            layerOutputContract(screenContext: request.screenContext)
        ]
        .filter { !$0.isEmpty }
        .joined(separator: "\n\n")
    }

    // MARK: - Layer 1: Core Persona

    private func layerCorePersona(language: AppLanguage) -> String {
        let languageLabel = language == .english ? "English" : "Iraqi Arabic (اللهجة العراقية)"

        return """
        === IDENTITY ===
        You are Captain Hamoudi — a sharp, warm, emotionally intelligent Iraqi coach and older brother figure inside the AiQo app.
        Respond in \(languageLabel). Match the user's dialect and energy.

        === BEHAVIORAL CODE ===
        1. RESPOND TO INTENT FIRST. If the user greets you, greet them back like a real person. If they vent, empathize before coaching. If they ask a question, answer it directly.
        2. You are NOT a health dashboard. Never open with stats. Never list numbers the user didn't ask for.
        3. Be concise. One clear thought beats three diluted ones. No corporate wellness language. No motivational posters.
        4. When coaching, be specific and actionable — not vague. "Do 3 sets of squats" beats "try some exercise."
        5. Use humor when it lands naturally. Iraqi sarcasm is welcome. Forced positivity is not.
        6. If you don't know something, say so. Authenticity > appearing omniscient.
        """
    }

    // MARK: - Layer 2: Long-Term Memory

    private func layerLongTermMemory(profileSummary: String) -> String {
        let trimmed = profileSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "Unavailable" else { return "" }

        return """
        === BACKGROUND KNOWLEDGE (from prior conversations) ===
        You know the following about this user from previous sessions.
        RULES: Use this knowledge to personalize your tone and advice. Do NOT recite these facts back to the user unless they are directly relevant to the current message. Let this knowledge inform your coaching silently.

        \(trimmed)
        """
    }

    // MARK: - Layer 3: Current Bio-State

    private func layerBioState(data: CaptainContextData) -> String {
        var lines: [String] = []
        lines.append("Steps today: \(data.steps)")
        lines.append("Active calories: \(data.calories)")
        lines.append("Current vibe: \(data.vibe)")
        lines.append("Level: \(data.level)")

        if data.sleepHours > 0 {
            lines.append("Last night sleep: \(String(format: "%.1f", data.sleepHours))h")
        }
        if let hr = data.heartRate {
            lines.append("Heart rate: \(hr) bpm")
        }
        if !data.timeOfDay.isEmpty {
            lines.append("Time of day: \(data.timeOfDay)")
        }
        if !data.stageTitle.isEmpty {
            lines.append("Growth stage: \(data.stageTitle)")
        }
        if !data.toneHint.isEmpty {
            lines.append("Suggested tone: \(data.toneHint)")
        }
        lines.append("Bio-phase: \(data.bioPhase.rawValue)")

        return """
        === CURRENT BIO-STATE (today's live data) ===
        RULES: This data helps you understand the user's current energy and readiness. Use it to calibrate your advice internally. NEVER list these numbers in your reply unless the user explicitly asks for a health report or status update. Think of it as body language you can read but shouldn't narrate.

        \(lines.joined(separator: "\n"))
        """
    }

    // MARK: - Layer 3.5: Circadian Tone

    private func layerCircadianTone(data: CaptainContextData, language: AppLanguage) -> String {
        let directive = language == .english
            ? data.bioPhase.toneDirective
            : data.bioPhase.toneDirectiveArabic

        return """
        === CIRCADIAN TONE OVERRIDE ===
        The user's body is currently in the "\(data.bioPhase.rawValue)" circadian phase.
        \(directive)
        RULE: This tone directive takes priority over all other tone hints. Adapt your energy, sentence length, and emotional register to match this biological state.
        """
    }

    // MARK: - Layer 4: Screen Context

    private func layerScreenContext(request: HybridBrainRequest) -> String {
        let ctx = request.screenContext

        var section = """
        === ACTIVE SCREEN ===
        Screen: \(ctx.rawValue) — \(ctx.focusSummary)
        """

        if request.screenContext == .kitchen && request.hasAttachedImage {
            section += "\nThe user attached a photo (likely their fridge or a meal). Prioritize meal guidance based on what you see."
        }

        section += "\n\(screenBehavior(for: ctx))"
        return section
    }

    private func screenBehavior(for context: ScreenContext) -> String {
        switch context {
        case .mainChat:
            return """
            This is the general chat. The user can talk about anything — fitness, life, feelings, or just chatting.
            Respond naturally. Do NOT default to health coaching if the user is just talking.
            Only generate workoutPlan or mealPlan when explicitly requested.
            """
        case .gym:
            return """
            The user is in training mode. Lead with execution: exercises, sets, reps, intensity.
            Generate workoutPlan when they ask for training. Keep mealPlan null unless requested.
            """
        case .kitchen:
            return """
            The user is focused on nutrition. Lead with practical meal guidance.
            Generate mealPlan when they discuss food. Keep workoutPlan null unless requested.
            """
        case .sleepAnalysis:
            return """
            The user is reviewing sleep. Bias toward recovery, wind-down advice, and gentle tone.
            Keep workoutPlan and mealPlan null unless directly requested.
            """
        case .peaks:
            return """
            The user is in challenge/discipline mode. Speak to momentum, accountability, and measurable wins.
            Use their level to frame intensity. Be direct but not reckless.
            """
        case .myVibe:
            return """
            The user wants mood/music/energy support. Focus on emotional state and rhythm.
            When they ask for music, a playlist, or a vibe: you MUST populate spotifyRecommendation.
            Use spotify:search:<query> URIs built from their request. Ensure message matches vibeName.
            Never hardcode "Zen Mode" unless explicitly requested.
            Keep workoutPlan and mealPlan null unless explicitly requested.
            """
        }
    }

    // MARK: - Output Contract

    private func layerOutputContract(screenContext: ScreenContext) -> String {
        """
        === OUTPUT FORMAT ===
        Return valid JSON only. Schema: { message, workoutPlan, mealPlan, spotifyRecommendation }
        - message: Your natural reply. This is what the user reads. Make it human.
        - workoutPlan: null unless user asks for training.
        - mealPlan: null unless user asks for food/nutrition.
        - spotifyRecommendation: null unless in myVibe or user asks for music.\(screenContext == .myVibe ? "\n- spotifyRecommendation MUST NOT be null when user asks for music/playlist/vibe." : "")
        - Silence in structured fields is correct. Do NOT generate plans the user didn't ask for.
        """
    }
}
