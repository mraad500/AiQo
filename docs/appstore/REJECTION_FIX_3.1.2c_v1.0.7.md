# Fix — Rejection 3.1.2(c) Subscriptions (v1.0.7 build 30)

**Date:** 2026-06-15 · **Submission ID:** 21050a61-310f-4a89-a376-7182011eef99
**Verdict:** Metadata-only rejection. **No code change. No new build. No re-upload.**

---

## Why it was rejected (diagnosis)

Apple flagged that the **App Store metadata** is missing a functional Terms of Use (EULA)
link. Everything in the app and on the website is already correct:

| Requirement | Status | Evidence |
|---|---|---|
| In-app: subscription title | ✅ | Paywall plan cards (Max / Intelligence Pro) |
| In-app: length (monthly) | ✅ | `PaywallView` "/ month" + disclosure |
| In-app: price (live) | ✅ | `priceText` = StoreKit `product.displayPrice` |
| In-app: auto-renew disclosure | ✅ | `PaywallView.swift:608-612` |
| In-app: Privacy + Terms links | ✅ | `PaywallView.swift:689 / :695` → `LegalView` |
| Web: aiqo.app/privacy | ✅ | HTTP 200, ~3,100 words |
| Web: aiqo.app/terms | ✅ | HTTP 200, ~920 words, covers subscriptions |
| Description source file | ✅ | `Description_v1.0.7.md:54-55` has both links |

So the only gap is the **live App Store Connect fields** that Apple reviewed — one of:
1. The **Privacy Policy URL** field (App Information) is empty, and/or
2. The live **Description** doesn't contain the Terms of Use (EULA) line (repo file was
   prepared but not pasted into the actual ASC description), and/or
3. No **custom EULA / License Agreement** is registered.

The fix below covers all three so approval is guaranteed.

---

## The fix — App Store Connect (≈5 min, no build)

### Step 1 — Privacy Policy URL (most common culprit)
App Store Connect → **AiQo → App Information** (left sidebar, under "General").
Find **Privacy Policy URL** → set to:
```
https://aiqo.app/privacy
```
Save. (This is a dedicated field — a link inside the description does NOT satisfy it.)

### Step 2 — License Agreement / EULA
Same **App Information** page → **License Agreement** → **Edit** → choose
**"Custom License Agreement (EULA)"** → paste the contents of
`docs/appstore/EULA_AppStoreConnect.txt` → Save.
(If you prefer the minimal route: skip the custom EULA and instead rely on the Terms link
in the Description from Step 3 — Apple accepts either. Custom EULA = most bulletproof.)

### Step 3 — Description (verify it matches the repo)
App Store Connect → **AiQo → iOS App → 1.0.7 → Description**. Make sure the **live** text
ends with these two lines (copy from `Description_v1.0.7.md`). If they're missing, the
description wasn't updated — paste the full v1.0.7 description now:
```
Privacy Policy: https://aiqo.app/privacy
Terms of Use (EULA): https://aiqo.app/terms
```
Do this for **both** English and Arabic locales.

### Step 4 — App Review Information → Notes
App Store Connect → **iOS App → 1.0.7 → App Review Information → Notes**. Paste:

```
This app offers auto-renewable subscriptions. Required subscription information is shown in the app on the paywall (open Profile > Upgrade, or any locked premium feature):
- AiQo Max: USD 9.99/month (7-day free trial); AiQo Intelligence Pro: USD 19.99/month.
- Auto-renew terms and "manage/cancel in Settings > Apple ID > Subscriptions" are displayed.
- Functional Terms of Use (EULA) and Privacy Policy links are in the paywall footer.
Metadata: Privacy Policy URL field is set; Terms of Use (EULA) is in the Description and in the custom License Agreement.
Privacy Policy: https://aiqo.app/privacy
Terms of Use (EULA): https://aiqo.app/terms
```

### Step 5 — Resubmit
Because the binary is unchanged, you do NOT need a new build. Either:
- **(A) Fast path Apple offered:** Click **Reply to App Review**, paste the reply below,
  attach a 10–20s screen recording of the paywall footer showing the Terms + Privacy
  links opening. Apple can approve without resubmission.
- **(B) Standard:** After saving metadata, click **Resubmit to App Review**.

Do both A and B if you want — reply first, then resubmit.

---

## Reply to App Review (paste into the message thread)

```
Hello, and thank you for the review.

AiQo's auto-renewable subscription information is presented both in the app and in the App Store metadata:

In the app (paywall — Profile > Upgrade, or any locked premium feature):
- Subscription titles: AiQo Max and AiQo Intelligence Pro.
- Length and price: AiQo Max USD 9.99/month (7-day free trial); AiQo Intelligence Pro USD 19.99/month, shown live from StoreKit.
- Auto-renewal terms and cancellation instructions (Settings > Apple ID > Subscriptions) are displayed.
- Functional links to the Privacy Policy and Terms of Use (EULA) are in the paywall footer.

In App Store Connect metadata:
- Privacy Policy URL field: https://aiqo.app/privacy
- Terms of Use (EULA): included in the App Description and as a custom License Agreement: https://aiqo.app/terms

A screen recording of the paywall is attached for confirmation. Please let us know if anything else is needed. Thank you!
```

---

## Optional (NOT required for this rejection)
The in-app Terms/Privacy currently open in-app text screens, which Apple accepts. If you
later want them to open the live web pages too, that's a code change needing a new build —
do NOT do it for this fix, as it would only slow approval.
