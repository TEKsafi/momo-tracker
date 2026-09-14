# Budgeta — MoMo Tracker (Flutter)

Tracks and manages your MoMo money: parses MoMo SMS to auto-log transactions
(Android), lets you paste/share MoMo messages to log them (iOS), computes
balances, and supports "virtual envelopes" so money from one pooled MoMo
balance can be allocated across multiple budgets.

## ⚠️ Before you run this

**This code was written and organized by hand — it has not been compiled.**
The sandbox this was built in has no Flutter/Dart SDK and no access to
pub.dev, so `flutter pub get` / `flutter run` could not be executed here.
The MoMo SMS parsing logic *was* verified (its regex patterns were tested
against 5 realistic MoMo message samples, all passed — see
`test/momo_sms_parser_test.dart` for the same cases as Flutter tests), but
Flutter/Dart-specific issues (a typo, an API signature drift in a plugin
version, etc.) can only surface once you actually build it. Budget time for
a first-build debugging pass — that's normal for any handed-off Flutter
project, not a sign something is fundamentally wrong.

## Setup

```bash
# 1. Turn this folder into a full Flutter project (generates android/ios
#    native scaffolding that can't be created without the Flutter SDK):
flutter create . --org com.yourcompany --project-name momo_tracker

# 2. Install dependencies
flutter pub get

# 3. Merge the permissions from android/app/src/main/AndroidManifest.xml
#    (the reference snippet in this repo) into the one flutter create
#    just generated in the same path.

# 4. Run
flutter run
```

For iOS's Share Extension (optional but recommended), follow
`ios/README-share-extension.md` — it requires one manual step in Xcode that
can't be scripted.

## What's new: professional polish + features

**Copy pass** — every screen's text was rewritten to match how top consumer
finance apps (Monzo, Revolut, Cleo) write: plain words, verb-first buttons,
sentence case, no exclamation marks, empty states that tell you what to do
next instead of just saying "nothing here". If you add screens later, keep
that voice — see the tone examples throughout `lib/screens/`.

**New features:**
- **Onboarding** (`screens/onboarding_screen.dart`) — a 3-slide intro shown
  once on first launch, explaining the value prop (auto-read, unmixing,
  insights) before dropping the user into the app. Skippable.
- **Insights tab** (`screens/insights_screen.dart` +
  `services/insights_service.dart`) — month-over-month spending comparison
  with a trend badge, a top-categories breakdown with progress bars, and
  **recurring payment detection**: flags expenses that repeat at a similar
  amount roughly every month (e.g. rent, a subscription) so the user notices
  fixed costs without any bank-level subscription API.
- **Savings goals** (`screens/savings_goals_screen.dart`) — set a named
  target (e.g. "Emergency fund: 200,000 RWF"), add contributions manually,
  track progress with a bar. Separate from the envelope/allocation system —
  a goal is a target to reach, an envelope is money already assigned.
- **Search + filter on Transactions** — search by note or category text, on
  top of the existing income/expense filter chips, with a proper
  "nothing matches" vs "no transactions yet" empty state distinction.
- **Category icons and colors** (`theme/category_icons.dart`) — every
  category (Food, Transport, Rent, etc.) now has a consistent icon and color
  used across the dashboard, transaction list, and insights — the kind of
  visual consistency that makes an app feel designed rather than assembled.
- **Home screen greeting** — "Good morning, [name]" based on the saved
  profile name and time of day, a small touch borrowed from most modern
  banking apps' home screens.
- **Editable profile** in Settings, presented as a proper tappable
  avatar row rather than a bare form.

None of this touches the SMS parsing or allocation math from the previous
version — those are unchanged and still local-only (see below).

## What works on each platform

| Feature | Android | iOS |
|---|---|---|
| Auto-read incoming MoMo SMS | ✅ (with permission) | ❌ Not possible — Apple blocks all third-party SMS access, no exceptions |
| Paste a MoMo message to log it | ✅ | ✅ |
| Share a MoMo message from Messages app | ✅ | ✅ (needs the Share Extension setup) |
| Manual transaction entry | ✅ | ✅ |
| Multiple budgets | ✅ | ✅ |
| "Unmix" pooled money into budgets (allocations) | ✅ | ✅ |
| Weekly/monthly reports | Not yet built in this pass — see "Next steps" | |

Don't market or promise "automatic" tracking for iOS users — be upfront in
your own app copy that iOS requires one tap (paste or share) per message.
That's an Apple platform rule, not a bug in this app.

## Architecture

```
lib/
  models/transaction.dart       Transaction, Budget, Allocation data classes
  services/
    momo_sms_parser.dart        Core regex parser — pure Dart, no I/O, easy to unit test
    sms_service_android.dart    Android-only: telephony plugin, permission flow, dedup
    share_intent_service.dart   iOS+Android: Share Sheet text capture
    local_store.dart            SharedPreferences persistence (local-first demo mode)
    allocation_service.dart     "Unmix" — envelope balance math
    api_service.dart            Stub for your Flask backend — same method shapes as LocalStore
  screens/
    onboarding_screen.dart      First-launch 3-slide intro
    dashboard_screen.dart       Greeting, balances, envelope total, recent transactions
    add_transaction_screen.dart Manual entry + "paste a MoMo message" quick-parse
    allocate_screen.dart        Assign pooled money to a budget (the "unmix" UI)
    transactions_screen.dart    Search, filter, delete
    insights_screen.dart        Month-over-month trend, top categories, recurring payments
    savings_goals_screen.dart   Set targets, track progress, add contributions
    settings_screen.dart        Profile, savings goals link, SMS toggle, allocation explainer
  theme/
    app_theme.dart               Dark indigo theme matching the web prototype
    category_icons.dart          Icon + color per spending category
  main.dart                     Onboarding gate, starts SMS/share listeners, 4-tab bottom nav
test/momo_sms_parser_test.dart  Parser unit tests
```

## How the "unmix" feature actually works

MoMo itself only ever reports **one balance** for your SIM/account — it has
no concept of "this portion is rent money, this portion is savings." This
app can't change that (no app can, without MoMo itself adding the feature).
What it does instead: every time money comes in, you assign ("allocate") it
to a budget. Each budget's spendable total = money allocated to it + income
logged against it − expenses logged against it. That's `AllocationService`
in `lib/services/allocation_service.dart`. It's bookkeeping on your side,
not a change to your real MoMo account — say this plainly in your own UI
copy too, so users don't think the app is physically splitting their money.

## Wiring to the Flask backend

Everything currently runs against `LocalStore` (on-device only, like the web
prototype's `localStorage`). `ApiService` in
`lib/services/api_service.dart` mirrors the same method signatures — once
your Flask app (from the earlier `budgetapp.zip`) exposes matching JSON
routes, swap the `LocalStore.xxx()` calls in the screens for
`apiService.xxx()` calls. Consider also adding a `POST /api/sms` route on
the Flask side so parsing can optionally happen server-side too (useful if
you ever add a non-Flutter SMS source, like a dedicated Android forwarding
service).

## Next steps not built in this pass
- Weekly/monthly report screens with charts (same data the web version's
  reports use — `budgetTransactions` + date bucketing — just needs a Flutter
  charting package like `fl_chart`)
- Wiring `ApiService` into the screens instead of `LocalStore`
- Real auth (login/register) instead of a single local profile
- Background (not just foreground) SMS listening on Android via
  `listenInBackground: true` in `SmsService` plus a background isolate
  handler, if you want capture even while the app is fully closed
