# AiQo Secrets Setup

1. Copy `Secrets.template.xcconfig` to `Secrets.xcconfig`:
   ```
   cp Configuration/Secrets.template.xcconfig Configuration/Secrets.xcconfig
   ```
2. Open `Configuration/Secrets.xcconfig` and fill in your real values for each key.
3. **Never commit `Secrets.xcconfig`** — it is listed in `.gitignore`.
4. Keys required:
   - `CAPTAIN_API_KEY`
   - `COACH_BRAIN_LLM_API_KEY`
   - `COACH_BRAIN_LLM_API_URL`
   - `CAPTAIN_VOICE_API_KEY`
   - `CAPTAIN_VOICE_API_URL`
   - `CAPTAIN_VOICE_MODEL_ID`
   - `CAPTAIN_VOICE_VOICE_ID`
   - `SPOTIFY_CLIENT_ID`
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`

Important:
- In `.xcconfig` files, write URLs with escaped slashes, for example `https:\/\/your-project.supabase.co`. Xcode treats raw `//` as a comment and truncates the value to `https:`.
