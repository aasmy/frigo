# Frigo — from here to revenue

A sequenced plan. Each phase has a clear "done" test. Do them in order: the
later ones depend on the earlier ones, and phase 0 will get your account banned
if you skip it.

**Time estimates assume part-time work.** The long poles are store review and
AdMob's payment threshold, not coding.

---

## Phase 0 — Accounts and the one security fix (week 1)

Nothing else can start until these exist.

| What | Cost | Notes |
|---|---|---|
| Google Play Developer account | **$25 once** | Personal accounts now need 12 testers for 14 days before production. Start this first — it is the longest lead time in the whole plan. |
| Apple Developer Program | **$99/year** | Needed even to test on your own iPhone beyond 7 days. |
| AdMob account | free | Linked to the Play/App Store listings. |
| A Mac, or macOS CI | $0–30/mo | You are on Windows. Codemagic's free tier covers an app this size. |

### The one thing you must fix first

Your Gemini key compiles into the APK. Extracting it takes about a minute.
Published as-is, strangers spend your quota.

**The fix — roughly 30 lines, ~1 hour:**

1. Create a Cloudflare Worker (free tier: 100k requests/day).
2. The Worker holds the key as a secret and forwards to Gemini.
3. Rate-limit per device ID so one user cannot drain everything.
4. Point `GeminiClient`'s endpoint at the Worker, ship `secrets.dart` empty.

**Interim option if you want to launch sooner:** default the app to
**On-device only** in Profile → AI provider. Receipt parsing, freshness,
recipes, reminders and shopping all still work — you lose only *Ask Frigo* and
the AI's extra receipt accuracy. Ship that, add the proxy, turn AI on in v1.1.

**Done when:** `strings app-release.apk | grep AIza` and `| grep "AQ\."`
return nothing.

---

## Phase 1 — Make the money paths real (week 1–2)

The code is written. These are the console steps that make it live.

### AdMob

1. Create app entries for Android and iOS.
2. Create one **banner** unit and one **rewarded** unit per platform.
3. Replace the sample app IDs:
   - `android/app/src/main/AndroidManifest.xml` → `com.google.android.gms.ads.APPLICATION_ID`
   - `ios/Runner/Info.plist` → `GADApplicationIdentifier`
4. Build with your unit IDs:

```bash
flutter build appbundle --release --dart-define=ADMOB_ANDROID_BANNER=ca-app-pub-XXXX/YYYY --dart-define=ADMOB_ANDROID_REWARDED=ca-app-pub-XXXX/ZZZZ
```

Profile shows a **"Test ads"** notice until you do this, so you cannot ship it
by accident.

> **Never tap your own live ads.** Not once, not "to check it works". It is the
> single most common way solo developers get permanently banned. Use the test
> IDs for every manual check.

### Subscriptions

Create these **exact** product IDs in both consoles — they are hard-coded in
`app_config.dart`:

| ID | Type | Suggested price |
|---|---|---|
| `frigo_pro_monthly` | auto-renewing subscription | $2.99 |
| `frigo_pro_yearly` | auto-renewing subscription | $19.99 (~44% off) |

Both stores need: a subscription group, a base plan, tax category, and a
filled-in listing. Products take a few hours to a day to appear in the API —
an empty paywall right after creating them is normal, and the paywall says so
rather than looking broken.

**Done when:** a test account can buy monthly, the banner disappears, and
"Restore purchases" brings Pro back after a reinstall.

---

## Phase 2 — Server-side receipt validation (week 2)

`BillingService._isEntitled` currently trusts the client. On a rooted phone
that is bypassable.

At launch volumes this costs you very little and is a reasonable thing to defer
— but do not defer it past your first few hundred subscribers. The same Worker
from phase 0 can validate purchase tokens against the Play Developer API and
Apple's `verifyReceipt`.

**Done when:** entitlement is granted by your server, not by the app.

---

## Phase 3 — Closed testing (week 2–4)

Google **requires** 12 testers running your app for 14 consecutive days before
a personal account can publish to production. This is a hard wall and the usual
reason a first launch slips by a month.

- Recruit 12 real people now — friends, a Discord, r/androidapps.
- Upload to the Closed testing track on day 1 of this phase.
- Use the 14 days to fix what they report.

iOS: TestFlight has no equivalent wait. Up to 100 internal testers, no review.

**Done when:** 14 days elapsed with 12 testers opted in.

---

## Phase 4 — Store listings (parallel with phase 3)

- **Screenshots** — Home, Kitchen, a scan result, Recipes. Frame them, do not
  just dump raw captures.
- **Short description (80 chars):**
  *"Scan receipts, track freshness, cook before food goes to waste."*
- **Full description** — lead with the receipt scan. Nothing else in this
  category does it as well, and it is why someone installs.
- **Keywords (iOS, 100 chars):** pantry, fridge, grocery, expiry, food waste,
  receipt scanner, meal planner
- **Privacy policy** — host `PRIVACY_POLICY.md` publicly, link it in both
  consoles. Fill in your real contact email first.
- **Data Safety / App Privacy** — the exact answers are in `STORE_RELEASE.md`.

---

## Phase 5 — Ship (week 4–6)

```bash
flutter build appbundle --release   # Play
flutter build ipa --release         # App Store, macOS only
```

Review times: Play 1–7 days for a first release, Apple usually 24–48 hours.
Expect one rejection. The common causes for an app like this are a vague
permission string, a missing privacy policy link, or Apple asking you to
demonstrate the subscription.

**Before you upload — the one test I could not run for you:** install the
*release* APK on a real device and exercise every flow. Release builds run R8
minification; the keep rules in `proguard-rules.pro` are written but unverified,
and R8 stripping ML Kit is the classic crash that only appears in release.

---

## Phase 6 — Getting paid

| | Threshold | Timing |
|---|---|---|
| **AdMob** | $100 | Paid ~21st of the following month |
| **Play** | $1 | Monthly, ~15th |
| **App Store** | $10 | Monthly, ~45 days after month end |

Add bank details and tax forms **now** — unverified tax info silently holds
payments, and people discover this months later.

### What to actually expect

Be sceptical of anyone quoting you big numbers. Realistic figures for a new
utility app with no marketing:

- **Banner eCPM:** $0.50–$3 depending on country mix. Tier-1 (US/UK/CA) is
  several times tier-3.
- **Rewarded eCPM:** $5–$20 — far better, which is why Frigo offers it at the
  one moment it genuinely helps.
- **Free → paid conversion:** 1–3% is normal. 5%+ is very good.

So at **1,000 daily active users**: roughly $15–60/month from banners, plus
maybe 10–30 subscribers ≈ $30–90/month. **Subscriptions will out-earn ads for
this kind of app**, which is exactly why the free tier is metered on AI rather
than plastered with banners.

The first version of this that matters is not the revenue — it is retention.
An app people keep on their phone for 30 days can be monetised later. One they
delete in a week cannot.

---

## Phase 7 — What to build next, in priority order

1. **Crash reporting** (Firebase Crashlytics, free). Without it you learn about
   crashes from one-star reviews. Do this before launch if you can.
2. **Analytics on the scan funnel** — opened scan → took photo → confirmed →
   added. Where people drop is where your money leaks.
3. **Cloud sync.** The #1 request once someone has a full kitchen on one phone,
   and a strong reason to pay.
4. **Barcode scanning** — faster than a receipt for a single item, and ML Kit
   already ships in your binary.
5. **Widgets** (home-screen "expiring soon"). Cheap to build, meaningfully
   improves retention.
6. **Localisation.** Spanish and Portuguese roughly double your addressable
   market for an app with very little text.

---

## The honest summary

The code is ready. What stands between you and revenue is almost entirely
**process**: a $25 account, a 14-day testing wall, two console setups, and one
afternoon moving an API key behind a proxy.

Start the Play account and recruit your 12 testers **today** — everything else
can happen in parallel, but that clock only runs once it has started.
