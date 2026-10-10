# Frigo

AI-powered kitchen inventory & meal assistant.
**Scan your receipt. Know what you have. Cook before it goes bad.**

Flutter MVP for iOS + Android. This build delivers the app shell, design system,
data models, navigation, the full offline service layer (mocked OCR + AI), and
every MVP screen — Home, Kitchen, and the Scan → Confirm → Kitchen flow are the
hero paths.

---

## Running

```bash
flutter pub get
flutter run
flutter test
flutter analyze
```

### Windows build notes

- **Keep the project path free of spaces and `&`** (it lives at `D:\pantry_ai`).
  The Android Gradle wrapper fails otherwise (`'Meal' is not recognized…`).
- `android/gradle.properties` sets `kotlin.incremental=false` and
  `kotlin.compiler.execution.strategy=in-process` to dodge a Kotlin Build Tools
  daemon bug that corrupts incremental caches
  (`Could not close incremental caches … is already registered`). If that error
  ever reappears: kill stray `java` / `KotlinCompileDaemon` processes, then
  `flutter clean` and delete `build/`, `android/.gradle/`, `.dart_tool/`.

First launch seeds a realistic demo kitchen (see `core/config/demo_data.dart`).

## Architecture

```
lib/
  main.dart                 # SharedPreferences load + ProviderScope override
  app.dart                  # MaterialApp.router + theme
  core/
    config/                 # demo data
    theme/                  # colors, spacing, typography, ThemeData
    routing/                # go_router config + route names
    models/                 # InventoryItem, Receipt(+Item), Recipe, prefs, enums…
    services/
      ocr/                  # OcrService (interface) + MockOcrService
      ai/                   # AiService (interface) + MockAiService, lexicon, templates
      expiration/           # pure shelf-life fallback
      notifications/        # policy, copy + real local scheduling
      local_store.dart      # SharedPreferences-backed offline cache
    repositories/           # Riverpod Notifiers: inventory, receipts, shopping, prefs, recipes
  features/
    app/                    # splash, bottom-nav shell
    onboarding/ auth/       # 3-slide intro + optional prefs; mock sign-in
    home/ inventory/        # Home, Kitchen, search, item details, manual add
    scan/                   # ScanController state machine + screens
    recipes/                # list, details, cook-update, rescue mode
    receipts/ shopping/ settings/
  shared/widgets/           # InventoryItemTile, ExpirationBadge, ReceiptItemRow,
                            # RecipeCard, IngredientStatusRow, StorageFilter,
                            # KitchenSearchBar, EmptyState, LoadingReceiptState,
                            # AiSuggestionCard, PrimaryButton, AppCard…
```

**State**: `flutter_riverpod`. Each collection is a `Notifier` that reads/writes
`LocalStore` synchronously, so the UI never waits on a network call. Recipe
generation is a `FutureProvider` off inventory + preferences.

**Navigation**: `go_router` with a `StatefulShellRoute` for **Home / Kitchen /
Recipes / Profile** and a prominent centre Scan button that pushes the
full-screen flow. Profile holds preferences, notifications toggles, shopping
list, receipt history, AI status, and the (red) data-deletion actions.

**Kitchen row actions**: swipe a row left for **Edit** (blue) and **Delete**
(red) via `flutter_slidable`. Delete always confirms through
`confirmDestructive` — one shared dialog with a red confirm button, used
everywhere an item / receipt / account is removed. Edit opens the shared
`showEditItemSheet`.

**Smart Manual Add & Edit**: as you type the name (debounced), an instant
offline knowledge-base guess sets category / unit / storage / image, then Gemini
refines it — "chicken" → grams, Meat, Freezer; "potato" → bag, Produce, Pantry —
all before you press Add. The same live inference runs in the **Edit item**
sheet. Manual edits to a field are respected and not overwritten. **Unit is a
dropdown** of common grocery units (`piece`, `g`, `kg`, `L`, `bunch`, `can`, …)
with a **"Custom…"** entry that reveals a free-text field — used in Manual Add,
Edit, and the receipt confirmation editor (`UnitField` widget).

### Recipes: more, real, and diet-aware

- **`recipeSuggestionsProvider`** — the "for your kitchen" picks. Gemini when a
  key is set; otherwise `MockAiService.generateRecipes` now pulls **real recipes
  from TheMealDB** (`RecipeApiService.discoverByInventory` — free, no key) built
  around your actual ingredients, with photos, steps and cook times; falls back
  to the built-in templates only if the API is unreachable.
- **"Discover more"** section on the Recipes tab — a browsable feed
  (`discoverMoreProvider` → `RecipeApiService.random`) with a **Load more**
  button that keeps appending fresh recipes.
- **Diet** is honoured end-to-end: a diet chip on the Recipes tab switches it
  inline (writes preferences), the Gemini prompt gets an explicit rule
  (`halal` → no pork / no alcohol; `vegan` → fully plant-based; …), and
  **`RecipeDiet.allows`** is a final keyword filter applied to *every* recipe
  list (Gemini, TheMealDB, templates) plus the `excludedIngredients` allergy
  list — so a preference is never silently ignored.

### AI: a chosen LLM, with the offline pipeline as the floor

`AiService` has two implementations behind one interface:

- **`LlmAiService`** — drives whichever `LlmClient` is selected (Gemini or
  Hugging Face).
  `parseReceipt` sends the **receipt photo itself** plus the OCR text and gets
  back structured, validated JSON — so it understands any store and any food
  without a hand-maintained list. `normalizeName`, `estimateShelfLife` and
  `generateRecipes` (real recipes from your actual inventory, not templates)
  also run on Gemini.
- **`MockAiService`** — the offline pipeline (structural `ReceiptParser` +
  knowledge base + recipe templates). **Every Gemini call falls back to it** on
  a network error, quota error, timeout or bad response, so the app always works.

`aiServiceProvider` picks Gemini when `Secrets.geminiApiKey` is set, else the
mock. `AppConfig.aiEnabled = false` forces mock-only (tests do this).

**Key setup:** `cp lib/core/config/secrets.example.dart lib/core/config/secrets.dart`
and paste your key from <https://aistudio.google.com/apikey>. `secrets.dart` is
git-ignored. For production the key belongs on a server (Supabase Edge Function
proxy), never in the app binary.

### The AI contract

`AiService` exposes the four spec tasks and **only ever returns validated,
structured data** — never free text:

| Method | Spec task |
|---|---|
| `parseReceipt(ocrText, imagePath)` | A + B — parse & normalize |

**Receipt latency.** On-device ML Kit OCR runs first and is free. When it returns
a usable scan (8+ non-empty lines, 4+ of them containing digits, 120+ chars) the
Gemini call is **text-only** — measured at ~10 s. The receipt photo is attached
only when OCR came back too thin to trust, because the same call with the image
costs 60-120 s for no better result on a legible receipt. Text calls use
`AppConfig.aiTimeout` (30 s); the rare vision call uses `aiVisionTimeout` (120 s)
and the photo is downscaled to 1600 px / q72 before upload. `AiHealth` records
every success and fallback, so a silent downgrade is visible in Profile and as a
"Read offline" banner on the confirmation screen.
| `normalizeName(raw)` | B — single-name normalize (Manual Add) |
| `estimateShelfLife(...)` | C — shelf-life estimate |
| `generateRecipes(...)` | D — 3–5 recipes from inventory |

#### Scan → text: real on-device OCR

`MlKitOcrService` runs Google ML Kit text recognition on the captured photo —
free, no key, fully offline. It falls back to `MockOcrService` (canned sample
text) when there's no image (the "Use a sample receipt" button), on web/desktop,
and in tests. Wired in `service_providers.dart`.

> iOS: the ML Kit pod needs `platform :ios, '15.5'` in `ios/Podfile` and a
> matching Xcode deployment target. Android works out of the box.

#### Receipt *understanding* — structure first

[`ReceiptParser`](lib/core/services/ai/receipt_parser.dart) doesn't try to read
every line. It works out the **shape** of the receipt, then classifies lines
inside the item window — which is what lets it survive very different layouts
(Walmart, Costco, Superstore, Save-On, …):

```
raw OCR dump
  → preprocess: fix l/O/S↔1/0/5 inside number tokens, re-join split price lines
  → find the item block: after the first DEPARTMENT header (or first priced
      line) … until SUBTOTAL / TOTAL — everything else (address, card number,
      Ref/Auth, EMV hash, "retain this copy", points blurb) is ignored
  → per line inside the block, classify as:
      • continuation  ("0.275 kg @ $6.59/kg", "3 @ $2.00", Gross/Tare/Net)
                       → merge weight + price onto the item above
      • department header / tax-code-only / junk → skip
      • item → strip PLU/UPC code, prices, "@ x/kg", trailing tax flags (MRJ, F)
  → tokenize + expand abbreviations   (CHKN BRST BNLS → chicken breast boneless,
      TOV → tomato vine, YLW → yellow)
  → fuzzy-match against a food knowledge base   (food_knowledge_base.dart)
  → canonical name + category + unit + storage + confidence
```

Merchant detection uses word boundaries + aliases (RCSS / "REAL CANADIAN" /
SUPERSTORE → *Real Canadian Superstore*; `\bMETRO\b` won't match "METROTOWN").
Date detection tries YY/MM/DD, DD/MM/YYYY and MM/DD/YYYY and picks the reading
closest to today that isn't in the future. Covered by
`test/receipt_understanding_test.dart` (Walmart / Costco / Save-On / Superstore /
garbled-OCR fixtures).

So `BNN ORG` becomes **Bananas** (Produce), `CHK BRST BNLS` becomes
**Chicken Breast** (Meat, Fridge), `DOVE SOAP` is recognised as **non-food** and
kept off the kitchen list. Anything the KB can't place still gets a cleaned,
title-cased name, a category guess, and a low confidence score that the
confirmation screen surfaces as "Best guess — tap to check".

To go live, implement `AiService` / `OcrService` against Supabase Edge Functions
that hold the API keys and enforce JSON schemas, then swap the two lines in
`core/providers/service_providers.dart`. No UI changes required.

### Design system

"Cool & fresh" — a blue-forward palette that reads like a clean fridge:
cool near-white surfaces (`#F4F7FC`), a confident primary blue (`#2E6BF0`) for
actions / active nav / the circular Scan button, frosty blue tints for
containers, a cooler cyan-blue for the Freezer section, and clear-but-soft
freshness colours (green "fresh", amber "3 days left", red "1 day left", blue
"frozen"). Tokens live in `core/theme/` (`app_colors`, `app_typography`,
`app_spacing` incl. `AppMotion`). Cards use a soft cool shadow instead of hard
borders; page and state transitions share one fade-through motion; buttons, nav
and chips have light press/haptic feedback.

### Food & recipe images (free, no key)

- **Item thumbnails** — deterministic by construction. `ImageResolver` resolves
  a name in this order and never guesses:
  1. **`assets/data/ingredients.json`** — a bundled catalog of 892 ingredient
     names, every one verified (HTTP 200) to have an image at
     `themealdb.com/images/ingredients/<Name>-Medium.png`. Matching uses a
     **subset rule**: a catalog entry only wins if *every* one of its tokens
     appears in the query, so "Salmon Fillet" can never resolve to "Anchovy
     Fillet". Where a more specific entry exists ("Basmati Rice", "Ground
     Cinnamon"), it is preferred over the generic one.
  2. **Wikipedia exact page** only (`page/summary/<Title>`) — never Wikipedia
     *search*, which was the source of the same item showing different pictures
     on different runs.
  3. Otherwise **nothing** → a tinted category icon.
  Positive results are written through to `LocalStore.kImageCache`, so an item
  keeps the same picture across app launches; concurrent lookups for one name
  are de-duplicated. The URL is also stored on the item
  (`InventoryItem.imageUrl`) at add time and backfilled by `InventoryNotifier`.
  Covered by `test/image_catalog_test.dart` and `test/image_coverage_test.dart`.
- **Recipe photos** — recipes sourced from TheMealDB carry their own real photo.
  Template/offline recipes deliberately show an illustrated emoji block rather
  than a stock photo looked up by ingredient, which reliably showed a *different*
  dish than the one named on the card.
- Images load through `cached_network_image` (disk cache), so once seen they
  render instantly and work offline.
- `AppConfig.networkImagesEnabled` (default `true`) gates all network image
  loads; widget tests set it `false`. Android `INTERNET` permission is declared
  in the manifest.

### AI providers — and what each one really costs

The LLM sits behind `LlmClient`, so the backend is a setting, not a rewrite.
Pick it in **Profile -> AI provider**.

| Provider | Reads the photo? | Cost | Verdict |
|---|---|---|---|
| **Google Gemini** | yes | free tier, then pay-as-you-go | best receipt accuracy |
| **Hugging Face** | no (OCR text only) | **$0.10/month free**, $2/mo on PRO | fine for dev, not for production |
| **On-device only** | n/a | free forever | everything except the chat assistant |

**The honest numbers on "free" Hugging Face.** A free HF account gets about
**$0.10 of inference credit per month**, shared across every provider on the
router. That is a few hundred receipt scans *in total, across all your users* —
it will not survive a public launch. PRO is $9/month for $2 of credit. Treat the
HF provider as a way to avoid vendor lock-in and to develop cheaply, not as free
production infrastructure.

**What is actually free at scale** is the offline pipeline, and it is not a
stub: `ReceiptParser` understands receipt structure, `FoodKnowledgeBase` infers
category, unit, storage and shelf life, and recipes come from TheMealDB, which
is free and needs no key. Selecting **On-device only** leaves every feature
working except *Ask Frigo*.

To add a provider, implement `LlmClient` and add a case to
`llmClientProvider`. Nothing in the feature code changes.

### Tiers, quotas and the paywall

Free is metered only where a use costs real money. Everything that costs Frigo
nothing - manual items, inventory size, freshness tracking, reminders, shopping
suggestions, and recipes from TheMealDB - is unlimited on both tiers.

| | Free | Pro |
|---|---|---|
| AI receipt scans | **10 / month** (+3 per rewarded ad) | unlimited |
| Ask Frigo replies | **5 / day** | unlimited |
| Ads | banner | none |
| Everything else | unlimited | unlimited |

`Entitlements` holds tier + counters and computes rollover from stored dates in
`rolled()`, so a month that passed while the app was closed resets on the next
read - there is no timer to miss. `EntitlementNotifier` is the only writer, and
spends bonus scans before the monthly allowance so a rewarded ad pays off
immediately. Covered by `test/entitlements_test.dart`.

The paywall opens from three places, and each says *why*: out of scans, out of
assistant replies, or the Profile banner. Running out is framed as a pause, not
a wall - the copy names what still works.

**Receipt verification is local.** `BillingService._isEntitled` trusts the
platform's purchase object, which is bypassable on a rooted device. That is an
acceptable launch position and a documented follow-up in `LAUNCH_PLAN.md`.

### Ads

A single anchored adaptive banner lives in `ScaffoldWithNav`, above the nav
bar. That placement is the whole policy:

- Scan, confirm, item details and cook are **full-screen routes above the
  shell**, so they are ad-free structurally — no rule to remember and no way to
  accidentally put an ad in the middle of a task.
- The banner occupies **zero height until an ad loads**, so a failed fill looks
  like nothing rather than a grey hole, and nothing shifts underneath the user.
- No interstitials. An interstitial after a receipt scan would land exactly
  where the user feels good about the app.

Consent is handled by Google's UMP SDK before the first request (required in
the EEA/UK), and iOS App Tracking Transparency is requested **after
onboarding**, not at cold start. Builds default to Google's *test* ad units and
Profile shows a "Test ads" notice until real IDs are passed via `--dart-define`.
See `STORE_RELEASE.md`.

### Motion

`lib/shared/motion/` holds the whole vocabulary: `FadeSlideIn` (staggered list
entrances), `PressFeedback` (press-scale that coexists with the ink ripple),
`AnimatedCounter`, `SwapFade`, `FreshnessRing` and `SuccessCheck`. Three rules:
motion explains a change rather than decorating one; entrances are short and
come from where the content belongs; and **every animation checks
`reduceMotion(context)`**, so the app is fully usable with the platform's
reduce-motion setting on.

### Illustrations

`assets/illustrations/` — eight scenes drawn for Frigo, composed the way
editorial illustration is: a **full-bleed muted colour block with the character
cropped by the frame**, not a small figure floating on white. One character
system across the set, varied hair, skin tones and clothing, and a desaturated
earthy palette (sage, clay, dusty blue, sand) rather than saturated UI colours.

Line work matters to the style — hair strands and fabric folds are drawn as
thin strokes over the flat shapes, which is what stops it reading as clip art.

**Grain:** `flutter_svg` cannot render SVG filters, so the paper texture is a
128px tileable PNG composited over the SVG in `FrigoIllustration`, inside a
`RepaintBoundary`. `test/motion_and_art_test.dart` asserts no scene uses a
filter or a remote `xlink:href`, so the set stays renderable and offline-safe.

### Reminders

Two scheduled local notifications, no more: an **expiry summary at 5:30pm** and a
**"what to cook" idea at 6:00pm** — early evening, while there is still time to
act. `LocalNotificationService` (flutter_local_notifications + timezone) does the
scheduling; `NotificationScheduler` re-writes the body whenever inventory or
preferences change, because the text is baked in at schedule time. Permission is
requested the moment a switch is turned on, never at launch, and the switch
reverts with an explanation if the user declines. Scheduling is inexact on
purpose (`AndroidScheduleMode.inexactAllowWhileIdle`) to stay off Android 14's
`SCHEDULE_EXACT_ALARM` settings gate. `AppConfig.notificationsEnabled` gates it
for tests.

### AI assistant (chat)

**Ask Frigo** — a chat screen (`/assistant`) backed by `GeminiClient.generateText`
with a `systemInstruction` and multi-turn history. Every message rebuilds a fresh
context string from the **current inventory** (item · qty · freshness),
**preferences** (diet, allergies, max cook time), the **shopping list** and
**recently cooked** recipes, so answers reflect reality and respect the diet.
Suggested prompt chips ("What can I cook tonight?", "What's expiring?", "What
should I buy?", "3-day dinner plan"). Reached from the Home header ✨ button and
Profile → Ask Frigo. Needs a Gemini key; without one the screen explains how to
add it.

### Shopping list

- Reachable from the **Kitchen header cart icon** (with a to-buy badge) and a
  **Home card** — not just buried in Profile.
- **Smart "Suggested for you"** section (`ShoppingSuggestionEngine` via
  `shoppingSuggestionsProvider`): staples you've run out of, staples running low,
  and perishables that are past their best — each with a one-line reason and a
  one-tap Add. Recipe-missing ingredients still land in a separate "From recipes"
  section.

### Persistence

Everything the user adds (inventory, receipts, shopping list, preferences,
cooked-recipe history) is written to `SharedPreferences` via `LocalStore` on
every mutation and reloaded on launch. The demo kitchen seeds **once** (a
`demo_data_seeded` flag); after that the app never overwrites the user's data —
clearing the kitchen and adding your own is permanent.

## Shipping

`STORE_RELEASE.md` is the release runbook: signing, store identity, the Data
Safety form, the privacy manifest, and the blockers that will stop a submission.
`PRIVACY_POLICY.md` is the policy both stores require you to host.

The one thing to read first: **the API key in `secrets.dart` compiles into the
binary.** Git-ignoring it stops it leaking through source control, not through
the APK. It needs to move behind a proxy before you publish.

## Not yet wired (intentional MVP cuts)

- Real Supabase auth/DB/storage — models & repos are shaped for the schema in
  the brief; persistence is local-only for now. There is no sign-in: the app is
  deliberately account-free.
- Crash reporting and analytics.
- An ad-free in-app purchase, which usually out-earns banners.
- Camera capture uses `image_picker`; the mock pipeline runs even without a
  camera so the flow is always demoable ("Use a sample receipt").

## Previewing without a device

`flutter run -d chrome` runs the whole
UI in a browser, which is the fastest way to review layout and motion from a
Windows machine. Ads, on-device OCR and notifications are all platform-guarded
and simply no-op there; everything else, including the AI calls and the image
resolver, works. The web target is a development convenience — Frigo ships to
Android and iOS only.
