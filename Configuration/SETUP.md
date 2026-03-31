# AiQo Secrets Setup

1. Copy `Secrets.xcconfig.template` to `Secrets.xcconfig`:
   ```
   cp Configuration/Secrets.xcconfig.template Configuration/Secrets.xcconfig
   ```
2. Open `Configuration/Secrets.xcconfig` and fill in your real values for each key.
3. **Never commit `Secrets.xcconfig`** — it is listed in `.gitignore`.
