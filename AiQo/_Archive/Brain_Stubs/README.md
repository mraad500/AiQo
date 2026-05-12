# Archived Brain Stubs

24 single-type scaffolding files moved here in v1.0.4 (commit
`release/v1.0.4-memory-v4`).

Each file in this directory contains an empty `public enum/struct/actor/final class`
with a `// TODO: implement per master plan` comment. None had a caller in the
production code path; the `01_Audit` pass at `/tmp/aiqo_reality_check.md` Task 4
verified zero external references for every type.

They are excluded from the AiQo target via the `_Archive` entry in
`AiQo.xcodeproj/project.pbxproj` → `PBXFileSystemSynchronizedBuildFileExceptionSet`,
so the binary does not carry them but the source survives for documentation and
future revival.

## Files

| Original location | Type |
|---|---|
| 02_Memory/Intelligence/MemoryConsolidator.swift | `MemoryConsolidator` |
| 02_Memory/Intelligence/NarrativeBuilder.swift | `NarrativeBuilder` |
| 02_Memory/Intelligence/PatternMiner.swift | `PatternMiner` |
| 02_Memory/Intelligence/RelationshipTracker.swift | `RelationshipTracker` |
| 01_Sensing/CircadianReasoner.swift | `CircadianReasoner` |
| 01_Sensing/SignalBus.swift | `SignalBus` |
| 04_Inference/RoutingPolicy.swift | `RoutingPolicy` |
| 04_Inference/Validation/CulturalValidator.swift | `CulturalValidator` |
| 04_Inference/Validation/ResponseValidator.swift | `ResponseValidator` |
| 05_Privacy/DataClassifier.swift | `DataClassifier` |
| 05_Privacy/DifferentialPrivacy.swift | `DifferentialPrivacy` |
| 06_Proactive/Composition/DynamicPersonalizer.swift | `DynamicPersonalizer` |
| 06_Proactive/Composition/NotificationDelivery.swift | `NotificationDelivery` |
| 06_Proactive/Evaluation/FeedbackTracker.swift | `FeedbackTracker` |
| 06_Proactive/Evaluation/IntentPlanner.swift | `IntentPlanner` |
| 06_Proactive/Evaluation/PriorityRanker.swift | `PriorityRanker` |
| 06_Proactive/Triggers/AchievementTrigger.swift | `AchievementTrigger` |
| 07_Learning/DecayEngine.swift | `DecayEngine` |
| 08_Persona/CulturalContext.swift | `CulturalContext` |
| 08_Persona/MoodModulator.swift | `MoodModulator` |
| 08_Persona/VoiceProfile.swift | `VoiceProfile` |
| 10_Observability/BrainHealthMonitor.swift | `BrainHealthMonitor` |
| 10_Observability/MemoryUsageTracker.swift | `MemoryUsageTracker` |
| 10_Observability/PerformanceMetrics.swift | `PerformanceMetrics` |

## Reviving one

1. `git mv AiQo/_Archive/Brain_Stubs/<File>.swift AiQo/Features/Captain/Brain/<original-folder>/`
2. Implement the type (the stub body is one line — start fresh).
3. Confirm Xcode's synced group picks it up automatically. No project file edit needed.
