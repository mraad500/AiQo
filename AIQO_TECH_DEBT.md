# AiQo Tech Debt Log

Living log of deferred refactors, architectural cleanups, and known-good-enough
compromises. Each entry should include a concrete trigger to revisit — avoid
open-ended "someday" items.

---

## Foundation Models helper extraction

**Priority**: Low
**Added**: 2026-04-19
**Trigger to revisit**: When Sleep Architecture on-device path lands (4th call site)
**Rationale**: 3 identical 4-line preambles across `CaptainOnDeviceChatEngine`, `FactExtractor`, and `HamoudiVerificationReasoner`. Collapse into `AppleIntelligence.runOnDevice<Output>` helper to prevent future callers from forgetting the availability gate.
**Estimated effort**: 30 minutes + per-subsystem smoke test
**Risk**: Modifies `FactExtractor`'s blueprint-canonical shape

### Current pattern (duplicated 3×)

```swift
#if canImport(FoundationModels)
if #available(iOS 26.0, *) {
    guard SystemLanguageModel.default.availability == .available else { /* fallback */ }
    let session = LanguageModelSession(instructions: instructions)
    let response = try await session.respond(to: payload)
    // parse…
}
#endif
// fallback…
```

### Proposed shape

```swift
enum AppleIntelligence {
    /// Runs a one-shot `LanguageModelSession` on-device. Returns `fallback()` when
    /// Foundation Models is unavailable, the model is not ready, or generation throws.
    static func runOnDevice<Output: Sendable>(
        instructions: String,
        prompt: String,
        fallback: @autoclosure () -> Output,
        parse: (String) -> Output?
    ) async -> Output { … }
}
```

### Call sites to migrate
- [AiQo/Features/Captain/CaptainOnDeviceChatEngine.swift](AiQo/Features/Captain/CaptainOnDeviceChatEngine.swift) — chat path
- [AiQo/Features/Captain/Brain/02_Memory/Intelligence/FactExtractor.swift](AiQo/Features/Captain/Brain/02_Memory/Intelligence/FactExtractor.swift) — memory facts (blueprint-canonical — migrate LAST)
- [AiQo/Features/Challenges/LearningSpark/Verification/HamoudiVerificationReasoner.swift](AiQo/Features/Challenges/LearningSpark/Verification/HamoudiVerificationReasoner.swift) — certificate verification
