// ===============================================
// File: CausalKnowledgeGraph.swift
// Brain Refactor §43 — Causal Reasoning Spine
//
// Most LLM coaches give isolated suggestions ("eat protein", "hydrate", "rest
// tomorrow"). World-class coaches *explain why* via cause-and-effect chains:
//   "You did heavy compound lifts → micro-tears in your muscle fibers →
//    protein within 30 min repairs them → 8h+ sleep tonight is when growth
//    actually happens → tomorrow needs to be easy or active recovery."
//
// This file encodes the domain knowledge as a directed graph of weighted
// edges. The chain builder traverses the graph from the user's most recent
// activity to produce a 2-3 hop *narrative* the prompt layer renders.
//
// Sources for the relationships are the standard ACSM/NSCA/sports-medicine
// literature — they're conservative and consensus-grade. We don't invent
// novel claims here; we just make the model reason about what it should
// already know.
// ===============================================

import Foundation

// MARK: - Nodes

/// A node in the causal graph. Three categories — activities (the *cause*),
/// states (what the body does in response), and intentions (what the user
/// should do next). Edges flow activity → state → intention.
enum CausalNode: String, Sendable, Hashable {

    // Activities — must be reachable from `RecentActivityFamily`.
    case walkingZone1, walkingZone2
    case runningEasy, runningHard
    case cyclingEasy, cyclingHard
    case swimmingSession
    case strengthCompound, strengthIsolation
    case hiitSession
    case yogaSession, pilatesSession
    case boxingSession

    // Body states — what just happened internally.
    case muscleDamage           // microtears, resistance work
    case glycogenDepleted       // long / hard endurance
    case dehydrated             // sweat-driven loss
    case nervousSystemTaxed     // explosive / max effort
    case fatigued               // accumulated general fatigue
    case mobilityNeed           // tight hips/back/shoulders signal

    // Intentions — what to do in the next minutes/hours/day.
    case proteinWindow          // 0.4g/kg within 30–60 min
    case carbsRefuel            // 1g/kg within 1–2h after endurance
    case hydration              // continuous water intake
    case electrolytes           // post heavy sweat
    case stretching             // 5-10 min mobility
    case foamRolling            // after high impact
    case earlyBedtime           // sleep-as-recovery signal
    case nextDayEasy            // load management
    case recoveryDay            // full passive day
    case zone2Cardio            // base-building easy cardio

    var arabicLabel: String {
        switch self {
        case .walkingZone1:        return "مشي خفيف"
        case .walkingZone2:        return "مشي زون 2"
        case .runningEasy:         return "ركض خفيف"
        case .runningHard:         return "ركض قوي"
        case .cyclingEasy:         return "دراجة خفيفة"
        case .cyclingHard:         return "دراجة قوية"
        case .swimmingSession:     return "سباحة"
        case .strengthCompound:    return "تمارين قوة مركّبة"
        case .strengthIsolation:   return "تمارين قوة معزولة"
        case .hiitSession:         return "HIIT"
        case .yogaSession:         return "يوغا"
        case .pilatesSession:      return "بيلاتس"
        case .boxingSession:       return "ملاكمة"
        case .muscleDamage:        return "تلف بسيط بالعضلات (طبيعي ومفيد)"
        case .glycogenDepleted:    return "استنزاف الجلايكوجين"
        case .dehydrated:          return "فقد ماء وأملاح"
        case .nervousSystemTaxed:  return "ضغط على الجهاز العصبي"
        case .fatigued:            return "إجهاد عام"
        case .mobilityNeed:        return "حاجة لإطالة"
        case .proteinWindow:       return "بروتين خلال 30-60 دقيقة"
        case .carbsRefuel:         return "تعويض كاربوهيدرات"
        case .hydration:           return "ترطيب مستمر"
        case .electrolytes:        return "أملاح/إلكتروليت"
        case .stretching:          return "إطالة 5-10 دقايق"
        case .foamRolling:         return "Foam Roller"
        case .earlyBedtime:        return "نوم مبكر هاي الليلة"
        case .nextDayEasy:         return "بكرة يوم خفيف"
        case .recoveryDay:         return "يوم استشفاء كامل"
        case .zone2Cardio:         return "كارديو زون 2 خفيف"
        }
    }

    var englishLabel: String {
        switch self {
        case .walkingZone1:        return "easy walking"
        case .walkingZone2:        return "zone-2 walking"
        case .runningEasy:         return "easy running"
        case .runningHard:         return "hard running"
        case .cyclingEasy:         return "easy cycling"
        case .cyclingHard:         return "hard cycling"
        case .swimmingSession:     return "swimming"
        case .strengthCompound:    return "compound strength"
        case .strengthIsolation:   return "isolation strength"
        case .hiitSession:         return "HIIT"
        case .yogaSession:         return "yoga"
        case .pilatesSession:      return "pilates"
        case .boxingSession:       return "boxing"
        case .muscleDamage:        return "minor muscle micro-damage (normal, productive)"
        case .glycogenDepleted:    return "glycogen depletion"
        case .dehydrated:          return "fluid + electrolyte loss"
        case .nervousSystemTaxed:  return "CNS load"
        case .fatigued:            return "general fatigue"
        case .mobilityNeed:        return "mobility need"
        case .proteinWindow:       return "protein within 30–60 min"
        case .carbsRefuel:         return "carb refuel"
        case .hydration:           return "continuous hydration"
        case .electrolytes:        return "electrolytes"
        case .stretching:          return "5–10 min stretching"
        case .foamRolling:         return "foam rolling"
        case .earlyBedtime:        return "early bedtime tonight"
        case .nextDayEasy:         return "easy day tomorrow"
        case .recoveryDay:         return "full recovery day"
        case .zone2Cardio:         return "easy zone-2 cardio"
        }
    }

    /// Maps the user-facing activity family to a graph activity node, using
    /// duration as the easy/hard discriminator for endurance work.
    static func from(family: RecentActivityFamily, durationMinutes: Int) -> CausalNode? {
        switch family {
        case .walking:      return durationMinutes >= 35 ? .walkingZone2 : .walkingZone1
        case .running:      return durationMinutes >= 35 ? .runningHard  : .runningEasy
        case .cycling:      return durationMinutes >= 45 ? .cyclingHard  : .cyclingEasy
        case .swimming:     return .swimmingSession
        case .strength:     return durationMinutes >= 35 ? .strengthCompound : .strengthIsolation
        case .hiit:         return .hiitSession
        case .yoga:         return .yogaSession
        case .pilates:      return .pilatesSession
        case .boxing:       return .boxingSession
        case .calisthenics: return .strengthCompound   // body-weight ≈ compound
        case .martialArts:  return .boxingSession
        case .cinematic:    return .runningEasy        // cardio-with-Captain
        case .gratitude, .stairs, .elliptical, .equestrian,
             .sport, .jumpRope, .other:
            return nil
        }
    }
}

// MARK: - Edges

struct CausalEdge: Sendable {
    let from: CausalNode
    let to: CausalNode
    /// Strength of the relationship in [0,1]. Used to rank chains when
    /// multiple paths exist from the same source.
    let weight: Double
}

// MARK: - Graph

@MainActor
enum CausalKnowledgeGraph {

    /// Static edge set. Conservative — every edge corresponds to a widely
    /// accepted ACSM/NSCA/sports-medicine relationship. Weights reflect
    /// *clinical priority*, not raw probability.
    static let edges: [CausalEdge] = [
        // --- Strength → states ---
        CausalEdge(from: .strengthCompound,  to: .muscleDamage,         weight: 0.95),
        CausalEdge(from: .strengthCompound,  to: .nervousSystemTaxed,   weight: 0.70),
        CausalEdge(from: .strengthCompound,  to: .fatigued,             weight: 0.40),
        CausalEdge(from: .strengthIsolation, to: .muscleDamage,         weight: 0.70),

        // --- Endurance → states ---
        CausalEdge(from: .runningHard,    to: .glycogenDepleted,    weight: 0.90),
        CausalEdge(from: .runningHard,    to: .dehydrated,          weight: 0.75),
        CausalEdge(from: .runningHard,    to: .nervousSystemTaxed,  weight: 0.50),
        CausalEdge(from: .runningHard,    to: .muscleDamage,        weight: 0.45),
        CausalEdge(from: .runningEasy,    to: .glycogenDepleted,    weight: 0.45),
        CausalEdge(from: .runningEasy,    to: .dehydrated,          weight: 0.55),
        CausalEdge(from: .cyclingHard,    to: .glycogenDepleted,    weight: 0.80),
        CausalEdge(from: .cyclingHard,    to: .dehydrated,          weight: 0.55),
        CausalEdge(from: .cyclingEasy,    to: .glycogenDepleted,    weight: 0.35),
        CausalEdge(from: .swimmingSession, to: .fatigued,           weight: 0.60),
        CausalEdge(from: .swimmingSession, to: .dehydrated,         weight: 0.30),

        // --- Walking → states (mild) ---
        CausalEdge(from: .walkingZone2,   to: .glycogenDepleted,    weight: 0.30),
        CausalEdge(from: .walkingZone2,   to: .dehydrated,          weight: 0.40),
        CausalEdge(from: .walkingZone1,   to: .dehydrated,          weight: 0.20),

        // --- HIIT → states (broad load) ---
        CausalEdge(from: .hiitSession,    to: .glycogenDepleted,    weight: 0.85),
        CausalEdge(from: .hiitSession,    to: .nervousSystemTaxed,  weight: 0.85),
        CausalEdge(from: .hiitSession,    to: .muscleDamage,        weight: 0.55),
        CausalEdge(from: .hiitSession,    to: .dehydrated,          weight: 0.65),

        // --- Boxing/martial — explosive + endurance ---
        CausalEdge(from: .boxingSession,  to: .nervousSystemTaxed,  weight: 0.70),
        CausalEdge(from: .boxingSession,  to: .glycogenDepleted,    weight: 0.55),
        CausalEdge(from: .boxingSession,  to: .dehydrated,          weight: 0.50),

        // --- Yoga/Pilates → mobility benefit, low load ---
        CausalEdge(from: .yogaSession,    to: .mobilityNeed,        weight: 0.10),
        CausalEdge(from: .pilatesSession, to: .mobilityNeed,        weight: 0.15),

        // --- States → intentions ---
        CausalEdge(from: .muscleDamage,       to: .proteinWindow,    weight: 0.95),
        CausalEdge(from: .muscleDamage,       to: .earlyBedtime,     weight: 0.80),
        CausalEdge(from: .muscleDamage,       to: .foamRolling,      weight: 0.55),
        CausalEdge(from: .muscleDamage,       to: .nextDayEasy,      weight: 0.65),
        CausalEdge(from: .glycogenDepleted,   to: .carbsRefuel,      weight: 0.95),
        CausalEdge(from: .glycogenDepleted,   to: .proteinWindow,    weight: 0.55),
        CausalEdge(from: .dehydrated,         to: .hydration,        weight: 1.00),
        CausalEdge(from: .dehydrated,         to: .electrolytes,     weight: 0.65),
        CausalEdge(from: .nervousSystemTaxed, to: .earlyBedtime,     weight: 0.85),
        CausalEdge(from: .nervousSystemTaxed, to: .nextDayEasy,      weight: 0.90),
        CausalEdge(from: .nervousSystemTaxed, to: .recoveryDay,      weight: 0.55),
        CausalEdge(from: .fatigued,           to: .earlyBedtime,     weight: 0.75),
        CausalEdge(from: .fatigued,           to: .recoveryDay,      weight: 0.65),
        CausalEdge(from: .fatigued,           to: .zone2Cardio,      weight: 0.40),
        CausalEdge(from: .mobilityNeed,       to: .stretching,       weight: 0.95)
    ]

    /// Outgoing edges from a node, ranked by weight (highest first).
    static func neighbors(of node: CausalNode) -> [(CausalNode, Double)] {
        edges
            .filter { $0.from == node }
            .map { ($0.to, $0.weight) }
            .sorted { $0.1 > $1.1 }
    }
}

// MARK: - Chain

/// A 2-3 node chain through the graph, paired with the cumulative weight.
/// Rendered into a one-line narrative for the prompt.
struct CausalChain: Sendable {
    let nodes: [CausalNode]
    let cumulativeWeight: Double

    /// "تمارين قوة مركّبة → تلف بسيط → بروتين خلال 30-60 دقيقة"
    func arabicNarrative() -> String {
        nodes.map(\.arabicLabel).joined(separator: " ← ")
    }

    func englishNarrative() -> String {
        nodes.map(\.englishLabel).joined(separator: " ← ")
    }

    func narrative(language: AppLanguage) -> String {
        language == .arabic ? arabicNarrative() : englishNarrative()
    }
}

// MARK: - Builder

@MainActor
enum CausalChainBuilder {

    /// Builds the most relevant 2- or 3-hop chain from the user's most recent
    /// activity. When auxiliary signals (low sleep, late hour) are present
    /// the builder boosts edges that lean toward `earlyBedtime` /
    /// `recoveryDay` so the chain reflects the *whole* current state, not
    /// just the workout in isolation.
    ///
    /// Returns `nil` when there is no recent activity or it's stale enough
    /// that a causal chain would feel forced.
    ///
    /// §50 Round 4 Fix δ — `behavioralStage` constrains chain depth. A
    /// returning user (relapse stage) gets a 1-hop chain at most so we
    /// don't over-prescribe ("you walked → glycogen depleted → eat
    /// carbs") for someone who's just glad to be active again. Action /
    /// maintenance / preparation users get the full 2- or 3-hop chain.
    static func derive(
        recentActivity: RecentActivitySnapshot?,
        sleepHoursLastNight: Double,
        hour: Int,
        behavioralStage: BehavioralStageReading? = nil
    ) -> CausalChain? {
        guard let activity = recentActivity, activity.freshness != .stale else {
            return nil
        }

        guard let activityNode = CausalNode.from(
            family: activity.family,
            durationMinutes: activity.durationMinutes
        ) else { return nil }

        // 1) Pick the strongest *state* from the activity.
        let stateNeighbors = CausalKnowledgeGraph.neighbors(of: activityNode)
        guard let topState = stateNeighbors.first else { return nil }

        // §50 Round 4 — stage-aware depth control. Relapse and
        // contemplation users get a shorter chain to avoid prescriptive
        // overreach. Confidence threshold guards against false-positive
        // stage detections shrinking chains for users who'd benefit
        // from full reasoning.
        if let stage = behavioralStage, stage.confidence >= 0.6,
           stage.stage == .relapse || stage.stage == .contemplation {
            return CausalChain(
                nodes: [activityNode, topState.0],
                cumulativeWeight: topState.1
            )
        }

        // 2) Pick the strongest *intention* from that state, with auxiliary
        //    boosts when the broader context favours rest/recovery.
        let intentionNeighbors = CausalKnowledgeGraph.neighbors(of: topState.0)
            .map { node, weight -> (CausalNode, Double) in
                let boost = boost(for: node, sleepHoursLastNight: sleepHoursLastNight, hour: hour)
                return (node, min(1.0, weight + boost))
            }
            .sorted { $0.1 > $1.1 }

        guard let topIntention = intentionNeighbors.first else {
            // Activity → state only (no intention edge yet defined).
            return CausalChain(
                nodes: [activityNode, topState.0],
                cumulativeWeight: topState.1
            )
        }

        return CausalChain(
            nodes: [activityNode, topState.0, topIntention.0],
            cumulativeWeight: topState.1 * topIntention.1
        )
    }

    /// Adds bias toward sleep/recovery intentions when context warrants it.
    /// Conservative — max +0.25 boost so we never invert a strong edge.
    private static func boost(
        for intention: CausalNode,
        sleepHoursLastNight: Double,
        hour: Int
    ) -> Double {
        var boost = 0.0
        let isLate = hour >= 20
        let sleptShort = sleepHoursLastNight > 0 && sleepHoursLastNight < 6.5

        switch intention {
        case .earlyBedtime:
            if isLate { boost += 0.15 }
            if sleptShort { boost += 0.10 }
        case .recoveryDay, .nextDayEasy:
            if sleptShort { boost += 0.10 }
        case .proteinWindow, .carbsRefuel:
            // Protein/carb windows close fast — boost early in the day.
            if hour < 18 { boost += 0.05 }
        default:
            break
        }
        return boost
    }
}
