# TrainerApp

An offline-first Android fitness and nutrition trainer for India, built with Flutter.
Workout plans, calorie and protein targets and meal plans are derived from published
WHO, ICMR-NIN and FSSAI figures. There is no account and no backend: every health
record stays on the device.

- Material 3, light and dark theme, Riverpod for state
- English and Hindi, switchable in Settings
- SQLite (`sqflite`) for records, `shared_preferences` for settings
- Google Play Billing for a monthly and a yearly subscription
- Builds end to end in GitHub Actions; no local setup needed

---

## Where the numbers come from

Every figure the app shows resolves to one of the publications below, and the app
can show that citation next to the value. Numbers that could not be verified were
not shipped.

| Source | Used for |
| --- | --- |
| [WHO — Healthy diet fact sheet (2026)](https://www.who.int/news-room/fact-sheets/detail/healthy-diet) | Free sugars, salt, saturated and trans fat, macronutrient energy shares, fruit and vegetable, fibre and potassium targets |
| [WHO — Guidelines on physical activity and sedentary behaviour (2020)](https://www.who.int/publications/i/item/9789240015128) | Weekly aerobic minutes and muscle-strengthening days for ages 5–17, 18–64 and 65+ |
| [ICMR-NIN — Dietary Guidelines for Indians (2024)](https://www.nin.res.in/dietaryguidelines/pdfjs/locale/DGI_2024.pdf) | My Plate for the Day, portion sizes, water, added sugar, visible fat, BMI cut-offs, energy factors, safe weight-loss limits |
| [ICMR-NIN — Nutrient Requirements and RDA for Indians (2020)](https://www.nin.res.in/rdabook/brief_note.pdf) | Energy requirements and PAL by activity level, protein EAR and RDA by age and sex |
| [Indian Food Composition Tables (IFCT 2017)](https://www.nin.res.in/ebooks/IFCT2017.pdf) | Per-100 g energy, protein, carbohydrate, fat and fibre for every food |
| [FSSAI — Eat Right India](https://eatrightindia.gov.in/) and the [trans fat guidance note (2022)](https://www.fssai.gov.in/upload/uploadfiles/files/Guidance_Note_TransFat_03_03_2022.pdf) | Industrial trans fat limit of 2% by mass; eat-safe framing |
| [Mifflin-St Jeor (1990)](https://pubmed.ncbi.nlm.nih.gov/2305711/) | Resting energy expenditure equation |
| [ACSM / AND / DC joint position statement (2016)](https://pubmed.ncbi.nlm.nih.gov/26920240/) | Protein range of 1.2–2.0 g/kg/day for training adults |

### Rules the app follows about its own data

- **No invented numbers.** If a value is not in a source it is absent, and the UI
  shows an empty state or says the figure is unavailable.
- **Derived values are labelled.** Two cases exist and both are flagged in the data
  and in the UI:
  - PALs for moderate and heavy work are scaled from ICMR-NIN's published sedentary
    PAL of 1.40 using its own published kcal/kg ratios (`palDerived: true`).
  - IFCT 2017 carries no energy value for edible oils and fats, so energy for those
    six foods is computed from their published fat content using the ICMR-NIN factor
    of 9 kcal per gram (`energyDerived: true`).
- **App policies are not dressed up as citations.** A conservative guard chosen for
  this app carries `"origin": "app_policy"` and no `sourceId`, and renders as
  "App safety rule" rather than a reference.
- **Internally inconsistent source rows are dropped.** `tools/gen_foods.py` rejects
  any IFCT row whose published energy disagrees with its own macronutrients by more
  than 40 kcal. One row currently fails this check (`N001`, chicken leg: 384 kcal
  published against 192 kcal implied) and is therefore not shipped.
- **No prices are bundled.** Food prices differ by city and season, so the user
  enters their own in Diet → My food prices. Budget planning uses only those, and
  says so plainly when a target cannot be met inside the budget.
- **No media is bundled.** Exercise instructions, common mistakes and safety notes
  were written for this app in plain language; no text, image or video is reproduced
  from any book, website or video. The media area is hidden rather than filled with
  a placeholder.
- **Nothing is scraped at runtime.** All data is read from `assets/data/`.

Shipped data: **136 foods** from IFCT 2017 across 14 food groups, and **101 exercises**
covering every major muscle group, with gym, home and bodyweight options for each.

---

## Safety behaviour

| Rule | Behaviour |
| --- | --- |
| Under 13 | App is blocked with a message to use it with a parent and a doctor |
| 13–17 | Activity guidance only; no calorie deficit, no weight-loss target |
| 18–59 | Full features |
| 60+ | Lighter default intensity, low-impact exercise preference, stronger doctor notice |
| BMI below 18.5 | Weight-loss goal disabled (ICMR-NIN lower bound of the normal range) |
| Weekly loss | Capped at 0.5 kg/week (ICMR-NIN), and additionally at 1% of body weight |
| Calorie floor | Never below the user's Mifflin-St Jeor resting energy, and never below the ICMR-NIN 1000 kcal weight-reduction floor |
| Max deficit | 40% of estimated needs (ICMR-NIN) |
| Screening | PAR-Q-style questionnaire at onboarding; any serious yes withholds weight-loss targets and high intensity until the user confirms medical clearance |
| Before every workout | A health check runs on **every** Start Workout tap. There is no route to the workout screen that bypasses it |
| Red flags | Chest pain, fainting or severe breathlessness stop everything and show "Seek medical help now" |
| Weekly check-in | Asks about new health problems or medication changes; a yes pauses automatic diet changes until cleared |

The app never diagnoses anything. The disclaimer appears full screen on first
launch, as a banner on the workout and diet screens, and on the Sources screen.

---

## Project layout

```
assets/data/              Sourced reference data, loaded at startup
  sources.json            Citation registry every value resolves against
  activity_guidelines.json  WHO 2020 activity by age band
  energy_guidelines.json  ICMR-NIN energy and protein tables
  diet_guidelines.json    WHO and ICMR-NIN diet targets and limits
  safety_rules.json       Age gates, screening items, safe limits
  exercises.json          101 exercises
  foods_ifct2017.json     136 foods from IFCT 2017

lib/
  models/                 Plain data types and the parsed guideline container
  services/               Pure logic (calculations, plan builder, progression,
                          meal planner, age rules, health safety) plus platform
                          services (database, prefs, billing, notifications,
                          export)
  providers/              Riverpod wiring
  screens/                One file per screen
  widgets/                Shared widgets, including the disclaimer banner
  l10n/                   app_en.arb and app_hi.arb

test/                     176 unit tests
tools/                    Scripts that regenerate the data assets
.github/workflows/        CI
```

The logic in `lib/services/` that matters for correctness is free of Flutter
imports, so it is tested directly against the real asset files.

---

## Building

### Through GitHub Actions (no local setup)

Push to any branch, or run **Actions → Android build → Run workflow**. The workflow
resolves dependencies, generates localizations, checks formatting, analyses, runs the
tests, then builds both a release APK and a release App Bundle and uploads them as
artifacts.

Artifacts are named `trainerapp-apk-release` / `trainerapp-aab-release` when keystore
secrets are present, and `-debug` when they are not.

### GitHub secrets for a signed build

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | Your keystore, base64 encoded: `base64 -w0 upload-keystore.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password |
| `ANDROID_KEY_ALIAS` | Key alias inside the keystore |
| `ANDROID_KEY_PASSWORD` | Password for that key |

All four must be set. With any missing, `android/key.properties` is not written and
`android/app/build.gradle.kts` falls back to debug signing, so **CI never fails for
want of a key**. A debug-signed build cannot be uploaded to Google Play; the workflow
logs a notice when that happens.

To create a keystore:

```bash
keytool -genkey -v -keystore upload-keystore.jks -storetype JKS \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Never commit the keystore or `android/key.properties`; both are in `.gitignore`.

### Locally (optional)

```bash
flutter pub get
flutter gen-l10n          # generated localizations are not committed
flutter analyze
flutter test
flutter build apk --release
flutter build appbundle --release
```

Needs Flutter 3.35.5 and **JDK 17**. Gradle 8.12 does not support JDK 25, and the
Android Gradle Plugin expects a 17 toolchain, so set `JAVA_HOME` accordingly.

### Configuration

| Setting | Default | How to change |
| --- | --- | --- |
| `applicationId` | `com.trainerapp.app` | `-PtrainerAppApplicationId=...` or `trainerAppApplicationId` in `android/gradle.properties` |
| `minSdk` | `24` | `-PtrainerAppMinSdk=...` |
| Product IDs | `premium_monthly`, `premium_yearly` | `BillingProducts` in `lib/constants.dart` |

> **Deviation from the brief: minSdk is 24, not 23.** Flutter 3.35 stable sets its own
> documented minimum to API 24 and has dropped Android 6.0, and
> `url_launcher_android`, `shared_preferences_android` and `path_provider_android` each
> declare `minSdk 24`. The manifest merger therefore raises the effective minSdk to 24
> whatever the app module asks for — a build declaring 23 still installs as 24.
> Declaring 23 would have been inaccurate, so it is set to 24 and left overridable in
> case those plugins are pinned to older versions.

### Regenerating the data assets

```bash
python3 tools/gen_foods.py       # foods_ifct2017.json from the IFCT 2017 table
python3 tools/gen_exercises.py   # exercises.json
```

`gen_foods.py` needs the IFCT 2017 composition table as CSV; see the header comment
in the script. Both scripts assert their own invariants and fail rather than emit
suspect data.

---

## Google Play subscription setup

1. **Create the app** in the Play Console with package name `com.trainerapp.app`.
2. **Upload a build first.** Products cannot be created until a build signed with the
   upload key exists on a track (internal testing is enough).
3. **Monetise → Subscriptions → Create subscription.** Create two, with product IDs
   exactly:
   - `premium_monthly`
   - `premium_yearly`

   These must match `BillingProducts` in `lib/constants.dart`. Nothing else in the
   code refers to a product ID.
4. **Add a base plan to each** — monthly auto-renewing and yearly auto-renewing — set
   prices per region, and **activate** both the base plan and the subscription.
   Inactive products are returned in `notFoundIDs` and the paywall will correctly show
   "Subscriptions are not available right now".
5. **License testers.** Play Console → Setup → License testing. Testers can purchase
   without being charged, and renewals are accelerated for testing.
6. **Prices are never hardcoded.** Titles, descriptions and localised prices are read
   from the store with `queryProductDetails`. A price change in the Play Console needs
   no app release. A unit test asserts that no price or currency literal exists in
   `lib/`.

### Entitlement handling

`lib/services/entitlement_service.dart` is the only place that turns purchases into
an entitlement, and the only thing the rest of the app reads. It handles purchased,
pending, error, canceled and restored, completes every delivered purchase so Play
does not refund it, and re-checks on every launch. If the store is unreachable the
cached entitlement is kept, so being offline never locks out a paying user; Premium is
revoked only when the store answers and reports no active subscription.

Server-side receipt verification is not implemented. The service documents exactly
where it would go: make `evaluate` async, POST
`purchase.verificationData.serverVerificationData` to your endpoint, and set
`verified` from the response. Nothing downstream needs to change, because every
screen keys off the cached entitlement rather than a purchase object.

---

## Free versus Premium

| | Free | Premium |
| --- | --- | --- |
| 3-day full-body plan | yes | yes |
| 4–6 day splits | — | yes |
| Workout logging, rest timer, health checks | yes | yes |
| Basic progress and weight chart | yes | yes |
| Adaptive progression from feedback | — | yes |
| Diet targets and budget meal plans | — | yes |
| Charts and personal records | — | yes |
| Workout and water reminders | — | yes |

Every safety feature is free. Nothing behind the paywall affects whether the app will
protect the user.

---

## How the plan and diet logic works

**Split by days per week.** 3 days → full body (trains on rotation days 0, 2, 4);
4 → upper/lower; 5–6 → push/pull/legs. Templates rotate across weeks so the same
session is not always first. Rest days are spread rather than bunched.

**Exercise selection** respects the training place (a home plan never includes
gym-only equipment), caps difficulty at the user's effective experience level, and
prefers low-impact movements for 60+ or while a serious screening flag is outstanding.

**Progressive overload** from the feedback collected after every exercise:

| Feedback | Loaded exercise | Bodyweight or timed |
| --- | --- | --- |
| Too easy | +2.5 kg | +1 rep, or +5 s |
| Just right | +1 rep until the top of the range, then +2.5 kg and reset reps | +1 rep |
| Too hard | −5% if all sets were completed, −10% if not | −1 rep, or −5 s |

Nothing is suggested until the exercise has actually been logged once, so the app
never invents a starting weight. A deload week lands every 4th (advanced), 5th
(intermediate) or 6th (beginner) week and drops load to 60% with one set removed.

**Calories.** `maintenance = Mifflin-St Jeor BMR × PAL`, then roughly +300 kcal for
Gain or −400 kcal for Lose, then every safe limit above is applied to the final
integer. The Diet screen lists which limits fired and cites each one. The published
ICMR-NIN reference for the user's group is shown alongside as a cross-check.

**Protein** sits inside the 1.2–2.0 g/kg sports-nutrition range for training adults,
never below the ICMR-NIN adult RDA of 0.83 g/kg, and leans higher in a deficit. Under
18 the ICMR-NIN adolescent RDA is used directly and the sports range is not applied.

**Budget meal planning.** Protein is bought first from the cheapest priced sources,
then remaining calories are filled from the cheapest energy, with a per-food daily cap
so one cheap staple cannot take over the plate. If the cheapest plan that meets the
targets costs more than the budget, the app says so and shows both figures rather than
quietly missing the target. With no prices entered it builds a balanced plate from the
ICMR-NIN My Plate group amounts scaled to the calorie target, and shows no cost at all.

**Stalled progress.** If measured weight has not moved towards the goal across two
weekly check-ins, the target is nudged by 100 kcal and re-clamped by every safe limit.
Reporting a new health problem at a check-in freezes that adjustment.

---

## Tests

```bash
flutter test
```

176 tests covering:

- Mifflin-St Jeor BMR and the maintenance calculation, against worked examples
- Every safe-limit rule, including that rounding cannot breach a limit
- Age gating, and that every age from 0 to 100 matches exactly one rule
- Split selection, rotation, rest-day placement and deload scheduling
- Progressive overload for loaded, bodyweight and timed exercises
- Budget meal logic, including honest reporting of shortfalls and determinism
- Health screening and the pre-workout check, including red-flag override
- Data integrity: that every `sourceId` resolves, every safety value declares its
  origin, published values match the publications, and no placeholder content or
  bundled price exists anywhere in `assets/data/`

---

## Privacy

No account, no server, no analytics. Name, age, sex, height, weight, goal, health
answers, workouts, weigh-ins, measurements, meals, water and food prices are stored
only on the device. The app makes no network request for user data. The only network
use is Google Play Billing when buying or restoring a subscription, which Google Play
handles and which never includes health data.

Settings → My data offers **Export my data** (a JSON file, shared wherever the user
chooses) and **Delete all my data** (an irreversible wipe of the database and the
stored settings). Uninstalling also removes everything.

---

## Disclaimer

This app gives general fitness and nutrition information based on WHO and ICMR-NIN
guidelines. It is not medical advice and does not replace a doctor or dietitian.
Consult a qualified doctor before starting any exercise or diet program, especially if
you have a health condition, are pregnant, are under 18 or over 60. Stop immediately
and seek medical help if you feel chest pain, dizziness, severe breathlessness or
sharp pain.
