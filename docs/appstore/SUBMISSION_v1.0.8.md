# AiQo v1.0.8 (build 31) — App Store Submission Pack

One-stop guide for shipping 1.0.8 to App Review. Everything that can be done in the repo is
done and checked below; the **You do** section lists the GUI-only steps in Xcode / App Store
Connect that require your Apple ID.

**Headline:** Captain Hamoudi is now **free for everyone** — runs on-device, remembers the
conversation, knows your name + tone, keeps health numbers honest, and the avatar is now
"living". Paid tiers add cloud memory + depth. Kernel is unchanged from 1.0.7.

**No new SDKs, no new privacy-label data types vs. 1.0.7.**

---

## Pre-flight status (verified in repo)

| Item | State | Notes |
|---|---|---|
| Marketing version | ✅ 1.0.8 | `MARKETING_VERSION` across all 24 target/config slots |
| Build number | ✅ 31 | `CURRENT_PROJECT_VERSION` across all 24 slots |
| Kernel enabled | ✅ `KERNEL_ENABLED = true` | Info.plist (unchanged) |
| Real streaming | ✅ `CAPTAIN_REAL_STREAMING = false` | Dormant behind flag — shipped path is the proven blocking reply |
| Dev unlock OFF | ✅ `AIQO_DEV_UNLOCK_ALL = false` | Info.plist; also hard-forced `false` in Release by `DevOverride` |
| Force-free toggle | ✅ DEBUG-only | `debug.forceFreeTier` UI is inside `#if DEBUG`; default false, only ever downgrades to free |
| Free Captain | ✅ on-device | `CaptainOnDeviceChatEngine` (Foundation Models); no network, no account, uncapped |
| Health fact-guard | ✅ on free + cloud | `CaptainFactGuard` rewrites any number that contradicts HealthKit |
| Export compliance | ✅ `ITSAppUsesNonExemptEncryption = NO` | Standard HTTPS only |
| Usage strings | ✅ Present | Health / Motion / Camera (Kernel PPG) / etc. — unchanged, truthful |
| Build | ✅ green | `xcodebuild` Debug + Release, fresh DerivedData — BUILD SUCCEEDED; Captain tests green |

---

## 1. What's New (release notes) — paste into ASC

Source: [WhatsNew_v1.0.8.md](WhatsNew_v1.0.8.md) — both locales + the App Review **Notes**.
The reviewer Notes explain the on-device (free) vs Gemini (paid) split precisely — important
because the headline is an AI feature and accuracy (2.3.1) was a prior flag.

## 2. Description — paste into ASC

Source: [Description_v1.0.8.md](Description_v1.0.8.md) — English + Arabic, plain text.
Updated so the tier + privacy copy reflect the now-free on-device Captain.

## 3. Promotional Text (≤170 chars, editable anytime without review)

**English:**
```
Captain Hamoudi is now free — your Iraqi AI coach runs right on your iPhone, remembers your chat, and keeps every health number honest. No account, no limits.
```

**العربية:**
```
كابتن حمودي صار مجاني — مدرّبك العراقي يشتغل على جهازك مباشرة، يتذكّر حچيك ويبقي أرقامك الصحية أمينة. بدون حساب، بدون حدود.
```

## 4. Keywords (≤100 chars per locale, comma-separated, no spaces after commas)

**English:**
```
AI coach,fitness,workout,nutrition,calorie,sleep,steps,habit,focus,screen time,discipline,tracker
```

**العربية:**
```
مدرب ذكي,لياقة,تمرين,جيم,تغذية,سعرات,رجيم,نوم,خطوات,عادات,تركيز,صحة,تحفيز
```
> Keywords unchanged from 1.0.7; verify each locale is ≤100 chars in ASC (live counter).

## 5. URLs

| Field | Value | Status |
|---|---|---|
| Privacy Policy | https://aiqo.app/privacy | ✅ required, live (the 1.0.7 rejection was a 404 here — confirm it still resolves) |
| Terms (EULA) | https://aiqo.app/terms | ✅ in description |
| Support URL | https://aiqo.app/support *(or contact page)* | ⚠️ confirm it resolves |
| Marketing URL | https://aiqo.app | optional |

---

## You do (GUI-only — needs your Apple ID)

**In Xcode**
1. Select the **AiQo** scheme → **Any iOS Device (arm64)**.
2. Confirm **Release** signing (Automatic, your distribution team).
3. **Product → Archive**. When done, **Distribute App → App Store Connect → Upload**.
4. Wait for the build to finish processing in ASC (a few minutes to ~1 hour).

**In App Store Connect → your app → "+ Version or Platform" → 1.0.8**
5. **What's New** — paste from §1 (ar + en).
6. **Description / Promotional Text / Keywords** — paste from §2–4 (per locale).
7. **Build** — select the 1.0.8 (31) build once processed.
8. **Screenshots** — the previous Kernel-led set still works. Optional but recommended: add
   one or two **Captain** shots that sell the headline (the living avatar + a chat that names
   the user). Not required to ship.
9. **App Review Information**
   - **Notes:** paste the reviewer Notes from [WhatsNew_v1.0.8.md](WhatsNew_v1.0.8.md)
     (on-device free Captain vs Gemini paid; no new data types; Kernel unchanged).
   - **Demo account:** same as 1.0.7 — one with **AiQo Max enabled** (Kernel is still
     Max-gated). The free Captain needs no account, but the reviewer needs Max for Kernel.
10. **Export compliance** — auto-skips (plist says NO). If asked: "standard encryption (HTTPS), exempt."
11. **Privacy "nutrition" labels** — no change vs 1.0.7 (no new data types). No edit needed.
12. **Age rating** — confirm (unchanged).
13. **Submit for Review.**

---

## Final gotchas

- **Don't brand the free Captain "Apple Intelligence"** in any metadata field. On-device, yes;
  Apple's trademark, no. The reviewer Notes carry the exact framework names — that's the right
  place for them.
- **Privacy Policy URL must resolve** — the 1.0.7 rejection (3.1.2c) was a 404 at `/privacy`.
  Open https://aiqo.app/privacy in a browser before submitting.
- **Streaming stays OFF.** `CAPTAIN_REAL_STREAMING = false` is correct for this submission; the
  edge-function streaming branch needs a device test before it's ever flipped on (a later,
  metadata-free update — no resubmission needed to enable it).
- **Free Captain needs iOS 26+ with the on-device model.** On older/unsupported devices the
  chat shows an honest "unavailable / try again" line rather than failing — by design.
