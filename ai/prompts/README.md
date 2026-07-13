# AiQo — Reusable Prompts

Ready-to-use system prompts for AiQo AI experiences.

| File | Use |
|---|---|
| [custom_gpt_system_prompt.md](custom_gpt_system_prompt.md) | The "AiQo Guide" Custom GPT — answers questions *about* AiQo using the knowledge Actions. Knowledge-only, no user data. |
| [captain_hamoudi_roleplay_prompt.md](captain_hamoudi_roleplay_prompt.md) | A persona prompt for an agent that speaks *as* Captain Hamoudi (demos/roleplay). **Not** the production in-app prompt. |

**Guidelines**
- The Guide prompt is safe to ship publicly; pair it with `ai/actions/OPENAI_ACTIONS_SCHEMA.json`.
- The roleplay prompt must carry a disclaimer and must never present output as real medical advice or as having read real health data (unless wired to the consented personal API).
- Keep the dialect and banned-phrase rules in sync with [../knowledge/CAPTAIN_HAMMOUDI_PROFILE.md](../knowledge/CAPTAIN_HAMMOUDI_PROFILE.md).
