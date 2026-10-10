# Shipping Frigo to Google Play and the App Store

Everything in this file is a real step. Items marked **BLOCKER** will stop a
release — either the store rejects it, or it ships something you will regret.

---

## 1. BLOCKER — get the API key out of the app binary

`lib/core/config/secrets.dart` compiles your Gemini key **into the APK and
IPA**. Anyone can extract it in about a minute with `strings` or `apktool`.
Published that way, your key is public: strangers spend your quota, and Google
may suspend it.

The file is git-ignored, which stops it leaking through source control. It does
**not** stop it leaking through the binary. Those are different problems and
only the first one is solved today.

**Fix before you publish.** The pattern that works:

1. Put the key in a tiny server you control — a Cloudflare Worker, a Supabase
   Edge Function or a Vercel function is enough, and all three have free tiers
   that cover an app of this size.
2. That function forwards the request to Gemini and returns the response.
3. Rate-limit per device so one user cannot drain the quota.
4. In the app, point `GeminiClient`'s endpoint at your function and ship with
   an **empty** `secrets.dart`.

Until that exists, options that are safe to ship today:

- Default the app to **On-device only** (Profile → AI provider). Everything
  works: the receipt parser, freshness, recipes from TheMealDB, shopping
  suggestions. Only the chat assistant is unavailable.
- Or let each user paste their own key, so the only key at risk is theirs.

## 2. BLOCKER — swap in your own AdMob IDs

The build currently serves **Google's test ads**, which earn nothing. Shipping
test IDs is safe but pointless; shipping live IDs you then tap yourself gets the
account banned.

1. Create an AdMob account, add Frigo as an Android app and as an iOS app.
2. Create one **banner** unit per platform.
3. Replace the sample app IDs:
   - `android/app/src/main/AndroidManifest.xml` →
     `com.google.android.gms.ads.APPLICATION_ID`
   - `ios/Runner/Info.plist` → `GADApplicationIdentifier`
4. Pass the unit IDs at build time:

```bash
flutter build appbundle --release \
  --dart-define=ADMOB_ANDROID_BANNER=ca-app-pub-XXXXXXXX/YYYYYYYY
```

Profile shows a **"Test ads"** notice whenever the build is still on test
units, so a forgotten flag is visible rather than silent.

## 3. BLOCKER — smoke-test the release build on a real device

The release build runs R8 minification (`isMinifyEnabled = true`). Keep rules
for ML Kit, AdMob and notifications are in `android/app/proguard-rules.pro`,
but **they have not been verified on a device**. R8 stripping an ML Kit class
is the classic way a release build crashes while debug works perfectly.

```bash
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Then, on the device: scan a receipt, add an item by hand, open Recipes, switch
on both reminders, open the assistant. If anything crashes only in release,
check `adb logcat` for `ClassNotFoundException` and add a keep rule.

## 4. BLOCKER — you need a Mac for the iOS build

You are on Windows. The iOS half of this repo is configured and ready, but
`flutter build ipa` only runs on macOS. Options:

- A Mac, or a rented one (MacStadium, MacinCloud)
- CI that provides macOS runners — **Codemagic** and **GitHub Actions**
  (`macos-latest`) both do, and both have free tiers

## 5. Create the Android signing key

Play requires a real upload key. The debug key will be rejected.

```bash
keytool -genkey -v -keystore frigo-upload.jks -keyalg RSA -keysize 2048 \
  -validity 10000 -alias upload
```

Put it somewhere outside the repo, then create `android/key.properties`:

```properties
storePassword=<yours>
keyPassword=<yours>
keyAlias=upload
storeFile=C:/keys/frigo-upload.jks
```

That file and `*.jks` are already git-ignored. **Back the keystore up.** Lose it
and you can never update the app under the same listing.

The Gradle config falls back to the debug key when `key.properties` is absent,
so a fresh clone still builds — but then produces something Play will refuse.

## 6. Identity — settled, and now frozen

| | Value |
|---|---|
| Android `applicationId` | `com.frigo.app` |
| iOS bundle identifier | `com.frigo.app` |
| Display name | Frigo |
| Version | `pubspec.yaml` → `version: 1.0.0+1` |

**Neither ID can be changed after first publish.** Change them now if you want
something different — e.g. `com.yourcompany.frigo`.

Bump `+1` on every upload; Play rejects a build number it has seen.

## 7. Build artefacts

```bash
# Google Play — always the bundle, never a bare APK
flutter build appbundle --release

# App Store (macOS only)
flutter build ipa --release
```

Measured sizes for this app:

| Artefact | Size |
|---|---|
| Universal APK | ~90 MB |
| **AAB (what Play serves)** | ~35 MB per device |
| arm64 APK | 34.8 MB |
| armeabi-v7a APK | 28.4 MB |

The 90 MB universal APK is misleading — Play splits the bundle per ABI, so a
real user downloads ~35 MB. Roughly 20 MB of that is ML Kit's bundled
text-recognition model. If you want it smaller later, the unbundled ML Kit
variant downloads the model from Play Services on first use instead.

## 8. Store listing

Needed for both stores:

- **Icon** — 512×512 (Play), 1024×1024 (App Store), no transparency, no rounded
  corners baked in
- **Screenshots** — at least 2 for Play, and one set per required iPhone size
  for the App Store. Good order: Home, Kitchen, a scan result, Recipes
- **Feature graphic** — 1024×500, Play only
- **Short description** (80 chars) — e.g.
  *"Scan receipts, track freshness, cook before food goes to waste."*
- **Full description** — lead with the receipt scan; it is the thing nothing
  else does as well
- **Privacy policy URL** — host `PRIVACY_POLICY.md` publicly and link it

## 9. Play Data Safety form

Declare, matching `PRIVACY_POLICY.md`:

| Question | Answer |
|---|---|
| Does the app collect or share data? | **Yes** — via AdMob |
| Data types | Device or other IDs; approximate location |
| Purpose | Advertising |
| Collected or shared? | **Shared** (with Google AdMob) |
| Encrypted in transit? | **Yes** |
| Can users request deletion? | **Yes** — Profile → Privacy & data |

Photos are **not** declared as collected: receipt images are processed and kept
on the device. If you later upload them anywhere, this answer must change.

## 10. App Store specifics

- `ios/Runner/PrivacyInfo.xcprivacy` is present and wired into the Runner
  target. Without it, upload fails with **ITMS-91053**.
- Usage strings are in `Info.plist` for camera, photo library and tracking.
  Apple rejects vague ones — the current wording says what Frigo does and why.
- App Review will ask what the AI does. Answer plainly: it reads grocery
  receipts to extract item names.
- If you keep the ATT prompt, be ready to show Review where it appears
  (immediately after onboarding).

## 11. Pre-submission checklist

- [ ] API key moved behind a proxy, or app defaults to On-device only
- [ ] Real AdMob app IDs and unit IDs in place
- [ ] Release build installed and exercised on a physical device
- [ ] Keystore created and **backed up**
- [ ] `version:` bumped
- [ ] Privacy policy hosted, URL in both consoles
- [ ] Data Safety form matches the policy
- [ ] Screenshots on current device sizes
- [ ] Tested with "reduce motion" on — every animation respects it
- [ ] Tested with notifications denied, camera denied, and offline
- [ ] `flutter test` green, `flutter analyze` clean

## 12. Not in this repo yet

Worth adding before or soon after launch:

- **Crash reporting** (Firebase Crashlytics or Sentry) — without it you learn
  about crashes from one-star reviews
- **Analytics** on the scan funnel, which is where users will drop off
- **Remove-ads purchase** via `in_app_purchase` — usually out-earns banners and
  is the reason to keep ad density low now
- **Cloud sync**, the top request once people have a full kitchen on one device
