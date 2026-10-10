# Frigo — Privacy Policy

**Last updated: 6 October 2026**

Frigo helps you track what is in your kitchen and cook it before it goes to
waste. This policy explains exactly what happens to your data.

> **Before you publish:** replace `support@yourdomain.com` and the company name
> below with your real details, host this page at a public HTTPS URL, and paste
> that URL into both Play Console and App Store Connect. Both stores reject
> apps whose privacy policy link is missing or dead.

---

## The short version

- Your kitchen inventory, receipts, shopping list and preferences are stored
  **on your device**. We do not have a server that holds them.
- There is **no account**, so there is nothing to sign in to and nothing tied
  to your name or email.
- Two things leave your device: **receipt text or images sent to the AI
  provider you choose**, and **advertising requests to Google AdMob**.
- You can erase everything from **Profile → Privacy & data**.

---

## What stays on your device

Stored locally using your device's standard app storage, and removed when you
uninstall Frigo:

- Items in your kitchen, with quantities, storage location and freshness dates
- Scanned receipts, including the photo if you took one
- Your shopping list
- Your preferences: display name, diet, cooking time, excluded ingredients,
  reminder settings, and which AI provider you selected

We cannot read any of this. It is not backed up to us and not shared between
devices.

## What leaves your device

### 1. Receipt understanding (only when you scan)

When you scan a receipt, Frigo first reads it **on your device** using on-device
text recognition. It then sends the recognised text — and, when the text is too
unclear to use, the receipt image itself — to the AI provider selected in
Profile:

| Provider | Operated by | What is sent |
|---|---|---|
| Google Gemini | Google | Receipt text, and the photo when needed |
| Hugging Face | Hugging Face and its inference partners | Receipt text only |
| On-device only | nobody — stays on your device | nothing |

Only the receipt content is sent. No name, email, device identifier or
location accompanies it. Choosing **On-device only** means no receipt data ever
leaves your device; Frigo falls back to its built-in parser.

Those providers process the request under their own terms:
Google ([policy](https://policies.google.com/privacy)),
Hugging Face ([policy](https://huggingface.co/privacy)).

### 2. The AI assistant (only when you use it)

Messages you type in **Ask Frigo**, together with a summary of your current
inventory and preferences, are sent to the selected provider to produce a
reply. Conversations are not stored by us.

### 3. Recipe images and ingredient photos

Frigo fetches food and recipe pictures from TheMealDB and Wikipedia. These are
ordinary image requests and carry nothing about you or your kitchen.

### 4. Advertising

Frigo is free and supported by ads served through **Google AdMob**. AdMob may
collect a device advertising identifier, coarse location and general device
information to select and measure ads. See
[how Google uses data from apps that use its services](https://policies.google.com/technologies/partner-sites).

- **In the EEA, UK and Switzerland** you are shown a consent form before any
  personalised ad is requested. You can change your answer at any time in
  **Profile → Privacy & data → Ad privacy choices**.
- **On iOS**, Frigo asks for App Tracking Transparency permission after
  onboarding. Declining is fine — you will simply see less relevant ads.

## What we never do

- Sell or rent your data
- Build an advertising profile from your groceries or recipes
- Ask for your contacts, precise location, microphone or health data
- Require an account, email address or phone number

## Permissions, and why

| Permission | Why |
|---|---|
| Camera | To photograph a receipt. Only opens when you tap scan. |
| Photo library | To pick a receipt photo you already took. |
| Notifications | For the two reminders you switch on in Profile. |
| Internet | AI requests, food images and ads. |

Each one is optional. Refusing any of them leaves the rest of the app working.

## Children

Frigo is not directed at children under 13 and we do not knowingly collect
their data.

## Your rights

Because everything is local and anonymous, the fastest way to exercise any
right is in the app:

- **Delete receipts** — Profile → Privacy & data → Delete all receipts
- **Delete your kitchen** — Profile → Privacy & data → Clear kitchen inventory
- **Delete everything** — Profile → Privacy & data → Delete account, or simply
  uninstall Frigo

For anything else, contact us at the address below.

## Changes

If this policy changes materially we will update the date at the top and note
it in the app's release notes.

## Contact

**support@yourdomain.com**
