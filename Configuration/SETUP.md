# AiQo Secrets Setup

1. Copy `Secrets.template.xcconfig` to `Secrets.xcconfig`:
   ```
   cp Configuration/Secrets.template.xcconfig Configuration/Secrets.xcconfig
   ```
2. Open `Configuration/Secrets.xcconfig` and fill in your real values for each key.
3. **Never commit `Secrets.xcconfig`** — it is listed in `.gitignore`.
