# AiQo v1.0.7 (build 30) — App Store Submission Pack

One-stop guide for shipping 1.0.7 to App Review. Everything Claude can produce is done and
checked below; the **You do** section lists the GUI-only steps in Xcode / App Store Connect
that require your Apple ID.

**Headline:** النواة (Kernel) — a personal digital-wellbeing app lock (AiQo Max). Everything
else is a localization + trust polish pass. No new SDKs, no new data types vs. 1.0.6.

---

## Pre-flight status (verified in repo)

| Item | State | Notes |
|---|---|---|
| Marketing version | ✅ 1.0.7 | `MARKETING_VERSION` across all targets |
| Build number | ✅ 30 | `CURRENT_PROJECT_VERSION` across all targets |
| Kernel enabled | ✅ `KERNEL_ENABLED = true` | Info.plist |
| Dev unlock OFF | ✅ `AIQO_DEV_UNLOCK_ALL = false` | Info.plist — must stay false |
| Export compliance | ✅ `ITSAppUsesNonExemptEncryption = NO` | Pre-answers the ASC prompt (standard HTTPS only) |
| Camera string | ✅ Present | Covers Kernel PPG: "never recorded or uploaded" |
| Health read/write | ✅ Present | `NSHealthShare` / `NSHealthUpdate` |
| Motion / Location / Alarm | ✅ Present | All usage strings truthful |
| Metadata accuracy | ✅ Fixed | Removed the false "Apple Intelligence" claim (was a 2.3.1 risk) |
| Release build | ✅ green | `xcodebuild` Release, fresh DerivedData — **BUILD SUCCEEDED** + passed `-validate-for-store` |

---

## 1. What's New (release notes) — paste into ASC

Source: [WhatsNew_v1.0.7.md](WhatsNew_v1.0.7.md) — both locales + the App Review **Notes**
(Family Controls / privacy / how-to-review). The reviewer Notes are important: Kernel uses
Family Controls and the reviewer will scrutinize it.

## 2. Description — paste into ASC

Source: [Description_v1.0.7.md](Description_v1.0.7.md) — English + Arabic, plain text
(no Markdown). Pricing/tier order verified against code + `.storekit`.

## 3. Promotional Text (≤170 chars, editable anytime without review)

**English:**
```
New — Kernel: lock the apps that pull you in and open them with movement. Your real steps lift the shield while Captain Hamoudi coaches you live, on-device.
```

**العربية:**
```
جديد — النواة: درّع التطبيقات اللي تسحبك، وافتحها بحركتك. خطواتك الحقيقية ترفع الدرع وكابتن حمودي يدرّبك مباشرة، على جهازك.
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
> Verify each is ≤100 chars in ASC (the editor shows a live counter). Trim the last term if over.

## 5. URLs

| Field | Value | Status |
|---|---|---|
| Privacy Policy | https://aiqo.app/privacy | ✅ required, live |
| Terms (EULA) | https://aiqo.app/terms | ✅ in description |
| Support URL | https://aiqo.app/support *(or a contact page)* | ⚠️ **required** — confirm this page exists/resolves |
| Marketing URL | https://aiqo.app | optional |

---

## You do (GUI-only — needs your Apple ID)

**In Xcode**
1. Select the **AiQo** scheme → **Any iOS Device (arm64)**.
2. Confirm **Release** signing (Automatic, your distribution team).
3. **Product → Archive**. When done, **Distribute App → App Store Connect → Upload**.
4. Wait for the build to finish processing in ASC (a few minutes to ~1 hour).

**In App Store Connect → your app → "+ Version or Platform" → 1.0.7**
5. **What's New** — paste from §1 (ar + en).
6. **Description / Promotional Text / Keywords** — paste from §2–4 (per locale).
7. **Build** — select the 1.0.7 (30) build once processed.
8. **Screenshots** — add **Kernel** shots (the headline feature): shield-up state, a
   steps→unlock challenge, the live Captain coaching, and the calm-hold/breathing disable.
   Required sizes: 6.9" and 6.5" iPhone (others optional/inherited).
9. **App Review Information**
   - **Notes:** paste the reviewer Notes from [WhatsNew_v1.0.7.md](WhatsNew_v1.0.7.md).
   - **Demo account:** provide one with **AiQo Max enabled** (Kernel is Max-gated and not
     reachable otherwise) + sign-in steps. Add a note that Family Controls is `.individual`
     (self-control), on-device only, and the user can always disable via the calm-hold/breathing.
10. **Export compliance** — should auto-skip (plist says NO). If asked: "uses standard
    encryption only (HTTPS), exempt."
11. **Privacy "nutrition" labels** — no change vs 1.0.6 (no new data types). Confirm they
    still match; no edit needed if 1.0.6 was accurate.
12. **Age rating** — confirm (12+; the QuickStart age gate blocks under-18).
13. **Submit for Review.**

---

## Final gotchas

- **Kernel is the review risk.** Make §9's demo-account + Notes airtight — most Family
  Controls rejections are "couldn't reach / understand the feature." The how-to-review steps
  in the WhatsNew file walk the reviewer through it end to end.
- **Don't re-introduce "Apple Intelligence"** anywhere in metadata — the AI is Google Gemini
  (cloud, consent-gated). Vendor disclosure lives in the Privacy Policy + in-app consent.
- **Pro free trial:** `.storekit` shows Intelligence Pro also has a 7-day trial. If ASC has
  it configured, add "with 7-day free trial" to the Pro line in the Description + §metadata.
</content>
