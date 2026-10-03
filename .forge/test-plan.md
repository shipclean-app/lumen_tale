---
type: test-plan
status: approved
generated_at: 2026-10-03
derived_from: .forge/plans/*.md section 11
checked_by: .forge/plans/check_plans.py::check_test_plan
---

# Test plan — the register Phase 6 asked for

> **Deliverable `test_plan`, registered 2026-10-03.** Phase 6's
> `current_phase_has_deliverables` gate named this file and it did not exist.
>
> **What this is**: a derived index of the test suites the 38 implementation plans
> already specify. **What this is not**: a test suite, a result, or evidence that
> anything works. Every number below is computed from `.forge/plans/*.md` § 11 by
> `.forge/plans/check_plans.py --test-plan`, not typed — *a register whose counts
> are retyped is a register that will be wrong*.

## 1. The inventory

| Subset | Rows | Plans | Runnable in a Codespace? |
|---|---:|---:|---|
| § 11.1 Tests unitaires | **880** | 38 | ✔ **ici** |
| § 11.2 Tests de composants | **334** | 38 | ✔ **ici** |
| § 11.3 Tests d'intégration | **156** | 37 | ✔ **ici** |
| § 11.3 Vérifications du pipeline | **13** | 1 | ✔ **ici** |
| § 11.4 Tests E2E | **11** | 38 | ✖ **Q-008** |
| § 11.5 Vérifications manuelles | **259** | 38 | ✖ **manuel** |
| **Total** | **1653** | **38/38** | **1383 of 1653** |

## 2. Coverage of the rule corpus

Every live business rule and edge case must be defended by at least one test row
in the plan that owns it. This is a question no existing gate asked.

| Corpus | Live | With at least one test row | Missing |
|---|---:|---:|---|
| Business rules B1–B48 (B35, B42 withdrawn) | 48 | **48** | — none |
| Edge cases E1–E22 | 22 | **21** | **E21** |
| Constraints C1–C14 | 14 | **12** | **C10, C13** |

**The constraints were the one id type this section never counted, and adding the row
found a second hole that a hand-written table would have hidden.** A quick scan of § 11
*prose* reports 13 covered, because C13 is discussed in a plan's § 11 without appearing in
any test cell. Only counting table cells — what a reader would actually run — gives 12.
Both numbers were produced during this pass and the prose one is wrong; the checker
enforces the cell count, so the disagreement cannot recur silently.

**E21, C10 and C13 are three absences, and only one of them is excusable.**

| Id | What it demands | Why no test row | Excusable? |
|---|---|---|---|
| **E21** | Novel Fire does not ship | Verified, but in `2-1.md`'s § 10, not § 11 | Yes — the check exists |
| **C10** | Novel Fire's terms confirmed before any scraper | Blocked on **Q-004** | Yes — nothing to test until the owner answers |
| **C13** | No login, no profiles, no sync, no cross-device migration | Discharged by the absence of such code, and **claimed present by five plans' § 11 preambles** | **No — see below** |

**C13's absence is the actionable one.** It is not blocked on a question; it is blocked on
nobody having written the test. It is also the *most* testable of the three: a row
asserting the schema declares no user, profile or session table, that `pubspec.yaml`
carries no auth or sync dependency, and that no provider reaches the network for identity,
would discharge C13 mechanically.

**And it is worse than an omission — it is masked by a false claim.** Five plans
(`0-5`, `2-6`, `3-4`, `6-5`, `6-7`) each close their § 11 with a preamble checklist
reading *« Chaque ID B\*/E\*/C\* du périmètre apparaît en § 6 »* followed by the ids in
scope — **and C13 is on that list in every one of them.** Not one of those five § 11 tables
contains a row for C13. The checklist asserts coverage that the section it heads does not
deliver, which is why a cell-counting scan is the only thing that found it: the prose says
yes and the table says nothing.

*An earlier draft of this section named `local-store` and `http-client` as C13's owners.
That was my inference and it was wrong* — the plans that scope C13 are the five named
above. Corrected here rather than left to be discovered by the next reader.

*Stated rather than quietly fixed, because the fix would be cosmetic and the fact is
not:* two of the three uncovered items in the entire rule corpus are the same unresolved
legal question (**Q-004**). Closing the table would make the knowledge no easier to find.

## 3. What is written, as opposed to planned

| | Count |
|---|---:|
| Test rows specified across 38 plans | **1653** |
| § 11 `Emplacement` targets that exist on disk | **7 of 55** |
| Test cases actually written | **228** |
| Of those, host (`test/`), on the Dart VM | **222** |
| Of those, **on-device** (`integration_test/`), run on a real phone | **6** |
| Of the host 222, covering the database schema | **27** |
| Of the host 222, covering the app bootstrap | **5** |
| Of the host 222, covering the network foundation | **51** |
| Of the host 222, covering localisation | **27** |
| Of the host 222, covering the theme foundation | **71** |
| Of the host 222, covering the build/delivery foundation | **13** |
| Of the host 222, **fixture-manifest suites** | **28** |
| Of the host 222, **skipped** — FanMTL unreachable | **9** |

**Seven of the 55 declared locations exist, and all six Wave-0 nodes have at least one
test file on disk** — `local-store` (2), `http-client` (2), `localisation` (3),
`theme-type` (4 of 6), `0-1` (1 declared + 1 extra), and `apk-pipeline` (1). The
`0-1` count is 7 because `royalroad_manifest_test.dart` is an **addition**: no plan
declares it, since `0-1` was written for FanMTL alone and could not know the second
site would be capturable. § 3.1 records what it found.

**`0-1` is now PARTIALLY discharged: Royal Road captured, FanMTL not.** See § 3.1.

### 3.1 One site captured, one site blocked — and what the capture changed

**Royal Road yielded a complete `0-1` capture** (9 fixtures, 2 045 855 bytes) after
finding that its URLs had *moved*: the paths ADR-014 recorded as 200 all 404. The live
catalogue is `/fictions/active-popular` with `?page=N`, not `/fictions/ratings`.

Three things the capture **corrected**, none of which was guessed:

| Finding | Detail |
|---|---|
| Chapter URLs are **five** segments | `/fiction/<id>/<slug>/chapter/<n>/<chapter-slug>`. The three-segment form **404s**. |
| The body container class is `chapter-inner chapter-content` | An exact `class="chapter-content"` match finds **nothing** — measured: zero paragraphs on a page that has 106. |
| **B22's third state has no marker on this site** | A zero-row catalogue carries no "nothing here" string. `18-external-contracts.md` planned to rely on one; `2-1` must distinguish by **page shape** instead. |

And one place where the plan's instruction could not be followed: § 3.2 says build the
manufactured fixture from the **detail** page, but that page has **zero** occurrences of
`chapter-content` in 1 000 263 bytes — the text lives on the chapter page. Renaming there
would have substituted nothing and produced a fixture named "broken" that was not broken.
It is built from a chapter page instead, and a row asserts the detail page genuinely has
no container, so the choice cannot rot silently.

**Nine tests are still SKIPPED, and the skip is FanMTL.** `0-1` was written for FanMTL.
Measured 2026-10-03 with the honest `LumenTale/0.1.0 (personal reader)` UA:

| Site | Result |
|---|---|
| FanMTL — `/`, `/robots.txt`, catalogue path, `/browsetags/`, `/browsetags/all.html` | **403**, Cloudflare interstitial |
| Royal Road — `/` → `/home` | **200**, 118 173 bytes, real markup |
| Royal Road — `/fiction/1`, `/fictions/ratings`, `/fiction/best-rated`, `/fiction/updates`, `/fiction/ratings` | **404**, zero novel rows |

ADR-014 measured both sites at 200 on 2026-10-02. **The sites moved; the client did
not.** So `0-1`'s capture rows cannot run, and the manifest API rows run against an
in-memory manifest instead.

**No fixture was fabricated to fill the gap.** Manufacturing HTML and calling it a
capture is precisely what `kind: manufactured` exists to distinguish, and a green `0-1`
built on manufactured fixtures would hand `2-1` a selector contract validated against
nothing — the exact failure Wave 0 was created to prevent. Recorded as **F-012** (FanMTL
403) and **F-013** (Royal Road 404), and measured in
`.opencode/rules/18-external-contracts.md` § Re-measurement 2026-10-03.

**One row of `localisation`'s § 11 is deliberately absent**, and its absence is the
honest entry rather than a gap: *« the error message family resolves in both
languages »* names **41** keys of the `source-unavailable` family. Those strings do not
exist yet — no slice has authored them. Writing a loop over the three keys that *do*
exist would produce a green row covering 3 of 41, which is the "a check reporting
something it did not measure" shape this project has hit repeatedly. The row stays
unwritten until the 41 strings exist, and `localized_strings_test.dart` says so in its
own header.

**`http-client` is the second foundation with its declared tests on disk** — 51 rows in
`http-client_test.dart` and `no_telemetry_test.dart`, against a plan that declares
`test/core/network/http_client_test.dart`. Two of the 55 declared locations now exist,
up from one. That is still a small minority, and § 8's table is the honest measure of
what is left.

**Roughly one row in fifty exists.** A § 11 is a promise the owning slice makes, not
a description of the current tree. No gate can check a promise — this file exists so
the difference is on the record rather than discovered at slice 5.

## 4. The split that Q-008 draws

> **Amended 2026-10-03, against measurement.** The text this replaces was written
> when no phone and no SDK were reachable, and it asserted two things that have since
> been measured false. Both corrections are recorded here rather than by quietly
> rewriting the section, because the original reasoning was sound *given what was
> known* — the error was environmental, not analytical.

**1383 rows can run here; 270 cannot.** The 270 figure is unchanged. What changed is
**why**:

| Cannot run here | Why | What it would take |
|---:|---|---|
| 11 E2E rows | need a real Android phone | a device and a way to install an APK — **both now available**; still unrun because **0 of 32 slices are implemented** |
| 259 manual verifications | visual, a11y, or judgement calls | a human, or a screenshot oracle |

### 4.1 Two claims here that measurement refuted

**"ADR-011 already makes the APK a CI dependency, so the build needs no device."**
Half true, and the reassuring half was the wrong one to lean on. The build needs no
*CI* — it runs here. `flutter build apk --debug` succeeded against a **nubia Z2577,
Android 16 / API 36, arm64-v8a** toolchain, and `lib/arm64-v8a/libsqlite3.so`
(1 732 360 bytes) is inside the APK. **Q-003 closes.** CI is now a second place the
build is verified, not the only one.

**"A device and a way to install an APK" was recorded as unavailable.** A real phone
is connected over USB and `adb install` succeeds. What was actually missing was not the
device but **the mechanism to run a test on it**, which is § 4.2.

### 4.2 `flutter test` cannot run a test on a phone — and says so silently

The most consequential thing measured on 2026-10-03. `flutter test -d <id>` accepts a
device id and **ignores it** for any file under `test/`. Verified three ways, all
returning `os=linux`: a real device id, a **fabricated** device id, and no flag at all.
A fabricated id reported `All tests passed!` after running the whole suite on the
laptop — which is how a false green gets written into a log as a result.

| Location | Fabricated device id | Result |
|---|---|---|
| `test/` | silently ignored | suite runs **on the host**, prints `All tests passed!` |
| `integration_test/` | `No supported devices found` | **refuses to run** |

So `integration_test/` cannot produce a false green and `test/` can. **Any future
device claim must cite a file under `integration_test/`; a `-d` flag on a `flutter
test` invocation is not evidence of anything.** The 6 on-device cases in § 3 live in
`integration_test/device_proof_test.dart` for exactly this reason, and their first
assertion is `Platform.isAndroid` — a suite that cannot tell a phone from a laptop
proves nothing on either.

### 4.3 What is still unproven

> **§ 7.1's frame budgets, SC-5, `gate:upgrade-safety` and all 11 E2E rows remain
> specifications — not slow results, not failed results.** A device exists and the
> build is verified; **no product behaviour has been observed on it**, because no slice
> is implemented. The sentence this section used to carry — *"no on-device claim in
> this project was verified, and none could have been"* — was true when written,
> became false about the toolchain, and is true again about the **application**: the
> only thing measured on a phone is the database layer.

## 5. The whole E2E suite, all 11 rows

- **2-4** — Gate Quand Ce qu'il prouve
- **2-4** — **MVP** Wave 4 Une exécution réseau réelle, puis **connectivité physiquement coupée**, u
- **2-4** — **`gate:upgrade-safety`** Wave 4 et Wave 7, **deux fois** Avec une bibliothèque, des cha
- **2-7** — Ce qui est vérifiable ici Ce qui ne l'est pas
- **2-7** — La virtualisation est **en place** (moins de 60 blocs construits) Que le budget de 16 ms
- **2-7** — Aucune image n'est chargée pendant le défilement (compteur réseau à zéro) Qu'aucun cadre
- **2-7** — Le plancher de 16px est tenu au plus petit palier (`14-design-tokens.md`) Que le défilem
- **2-7** — La colonne se centre et cesse de grossir à 1400dp (ADR-019) —
- **apk-pipeline** — Occasion Bibliothèque Ce qu'il prouve
- **apk-pipeline** — **MVP gate** — roadmap Wave 4 petite B31 tient sur un cas simple
- **apk-pipeline** — **V1 gate** — roadmap Wave 7 grande Une migration qui ne casse qu'à l'échelle ne se voit

## 6. What Phase 6 produced

> **Rewritten 2026-10-03.** The previous §6 was a to-do list written *as* Phase 6 ran,
> and two of its three items were already false by the end of the same session. It is
> replaced by the sections below rather than deleted, because "what Phase 6 decided" is
> part of the record.

1. **~~Nothing runs `flutter test` in CI~~ — done.** ADR-011 decided a GitHub Actions
   workflow and no workflow file existed; there is now `.github/workflows/ci.yml`,
   which runs format, analyze, the host suite and the APK build, and uploads the
   artifact. See § 9.
2. **~~`check_plans.py --test-plan` recomputes § 1 and § 2~~ — corrected, and it never
   worked.** There is no `--test-plan` mode: `sys.argv[1:]` is a **slice-name filter**,
   so `python3 .forge/plans/check_plans.py --test-plan` matched no plan and printed
   `no failures` — a green over zero measurements. `check_test_plan()` runs on **every**
   invocation. This register's § 1 and § 2 are recomputed by plain
   `python3 .forge/plans/check_plans.py`, which also now verifies the constraints row.
   The path fix that made it runnable at all is in § 11.3.
3. **~~11 E2E rows, 0 run, 0 devices~~ — corrected.** There is a device (§ 11.1) and the
   6 on-device cases in § 3 have run. The 11 E2E rows remain **0 run**, and the reason
   has changed: not hardware, not tooling, but **0 of 32 slices implemented**. § 4.3
   states what that does and does not license.

The rest of this register: **§ 7** the pyramid, **§ 8** the foundation tests that must
precede every business slice, **§ 9** the regression suite and its commands, **§ 10**
per-screen verification, **§ 11** the environments and their variables.

## 7. The pyramid

Five tiers, and the rule for which tier a given row belongs in is **what has to be
replaced to make it pass** — not how important the feature is. A test that mocks the
database is a unit test even if it exercises a whole screen.

| Tier | Replaced by a fake | Lives in | Command | Count |
|---|---|---|---|---:|
| **1. Unit** | the network, the database, the filesystem | `test/` | `flutter test` | **880** |
| **2. Component** | nothing — real widgets, real theme, real l10n | `test/` | `flutter test` | **334** |
| **3. Integration** | one real boundary (a real file DB, a real `Dio` adapter) | `test/` | `flutter test` | **169** |
| **4. On-device** | nothing — real ARM64, real Android SQLite | `integration_test/` | `flutter test integration_test -d <id>` | **6** |
| **5. E2E** | nothing — the whole app, real connectivity | `integration_test/` | not runnable | **11** |
| **6. Manual** | a human judgement | a checklist | not automatable | **259** |

**Tiers 1–3 and the on-device tier 4 are the falsifiable core: 1389 rows** — every plan
row that a command can decide, plus the 6 that have actually run on hardware. The E2E and
manual tiers are real obligations and neither is automatable today; § 4.3 says why, and
neither may be reported as passing.

**Why the on-device tier exists at all, given only 6 rows.** Because tier 1 runs the host's
SQLite and tier 3's real database is still the host's. B32's only enforcement is a
per-connection `PRAGMA`, and a per-connection pragma is exactly the thing that can differ
between two SQLite builds. Six rows bought the only evidence that Android's SQLite
behaves like the one every other tier is asserting against.

## 8. Foundation tests come before every business slice

**The rule: a slice may not be implemented until the foundations it depends on have real
tests, not declared ones.** This ordering is not stylistic. A foundation's tests are what
turn its contract from a claim into something a later slice can fail against — and
`coverage-check.js` verifies structure, never behaviour, so a plan's § 11 passing proves
nothing about whether the foundation works.

| Foundation | Rows declared | Unit | Component | Integration | E2E | Manual | Test locations declared | On disk |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| `http-client` | **53** | 42 | 0 | 4 | 0 | 7 | 1 | **1** |
| `theme-type` | **39** | 23 | 4 | 4 | 0 | 8 | 6 | **4** |
| `local-store` | **38** | 26 | 0 | 6 | 0 | 6 | 2 | **2** |
| `failure-discriminator` | **37** | 28 | 0 | 4 | 0 | 5 | 1 | 0 |
| `apk-pipeline` | **33** | 10 | 0 | 13 | 3 | 7 | 1 | **1** |
| `localisation` | **29** | 22 | 0 | 0 | 0 | 7 | 3 | **3** |
| **Total** | **229** | **151** | **4** | **31** | **3** | **40** | **14** | **13** |

**Thirteen of the fourteen declared foundation test locations exist.** Only one is
missing: `theme-type`'s fifth file, `theme_override_test.dart`, whose rows are in fact
covered today by `theme_override_test.dart` plus the notifier half of
`app_theme_preferences_test.dart` — so the *plan's* file list understates what exists,
which is recorded rather than corrected by inventing a file. The foundations carrying the most weight are the least built:
`http-client` declares 53 rows and now has its suite; `localisation` and `theme-type`
still declare test files that do not exist. `apk-pipeline` is the only foundation with E2E rows, and they are the three
`apk-pipeline` entries in § 5.

**What each foundation's tests must be able to fail on**, so "implemented" cannot be
claimed from a passing import:

| Foundation | The test that must exist before any dependent slice |
|---|---|
| `http-client` | A timeout that fires, a retry that stops, and a **non-2xx that raises a typed error rather than returning a body** — `13-error-handling.md`'s hierarchy is only real if a bad status cannot be read as data |
| `failure-discriminator` | Two failures with the same message and different codes resolve to **different** codes, and the same failure always resolves to the same code |
| `local-store` | The `RESTRICT` refuses and the `CASCADE` fires — **done**, and now also on device (§ 7, tier 4) |
| `theme-type` | Every colour pair in `14-design-tokens.md` measured for contrast, **failing on a ratio below its WCAG threshold** — a test that cannot fail on a bad colour is decoration |
| `localisation` | Every ARB key present in **both** locales, and no English string reachable under `fr` — the fallback in `main.dart` makes a missing key invisible |
| `apk-pipeline` | A version bump produces a new artifact and an unchanged `applicationId`, and `lib/arm64-v8a/libsqlite3.so` is present in the APK — the last one is now measured (§ 3) |

## 9. The regression suite, and the command for each part

**What must pass before any merge to `master`.** Ordered cheapest-first, because a
failure at tier 1 costs seconds and a failure discovered after a full APK build costs
twelve minutes. **Gates 1, 2, 3, 4 and 6 are implemented in
`.github/workflows/ci.yml`** — ADR-011 decided that workflow on 2026-10-02 and no
workflow file existed until this pass, which is an approved decision with nothing built
on top of it.

| # | Gate | Command | In CI? | Fails the build? |
|---|---|---|---|---|
| 1 | Format | `dart format --output=none --set-exit-if-changed .` | ✅ | yes |
| 2 | Static analysis | `flutter analyze --fatal-infos` — zero issues, **including zero info** | ✅ | yes |
| 3 | Host suite | `flutter test --reporter expanded` | ✅ | yes |
| 4 | Plan corpus | `python3 .forge/plans/check_plans.py` | ✅ | yes |
| 5 | Forge guards | `forge-guard.js all .` | ❌ | not a CI gate — see below |
| 6 | APK build **+ native-lib assertion** | `flutter build apk --release`, then assert `lib/arm64-v8a/libsqlite3.so` is present | ✅ | yes |
| 7 | On-device suite | `flutter test integration_test -d $DEVICE_ID` | ❌ | **no** — needs hardware CI does not have |
| 8 | E2E | — | ❌ | **no** — 0 of 32 slices implemented |

**Gate 5 is not in CI, and the reason is concrete rather than cautious.**
`forge-guard.js` lives in the Forge skill directory, which is **not vendored into this
repository**; a workflow calling it would fail on a missing path rather than on a real
defect — a red X that means nothing. The guards run locally, where AGENTS.md's Definition
of Done already requires them.

**Gate 6 asserts more than "the build exited 0".** A `.so` that is packaged but fails to
`dlopen` at runtime still produces a successful build, so the workflow greps the finished
APK for `lib/arm64-v8a/libsqlite3.so` and fails the job if it is absent. Verified both
ways against a real APK: it passes on `arm64-v8a` and fails on an ABI that is not there.
It still does not prove the library *loads* — only the on-device suite does that (§ 7,
tier 4), and the two checks are not substitutes for each other.

**Gates 7 and 8 are deliberately absent.** A workflow that requires hardware nobody has
blocks every merge; one that waits on unimplemented features is a red cross nobody can
clear. Both run on demand and their results belong in § 3, not in a failing job.

**`android/gradle.properties` and the JDK are build inputs, not settings.** The SDK's
bundled JDK is **Java 25**, which **Gradle 8.14 cannot run on**; CI pins
`actions/setup-java` to **21** and Flutter to **3.47.6** rather than `stable`, so a toolchain
change arrives as a visible diff in `ci.yml` instead of an unexplained red build. The
local failure mode is a bare `25.0.3` under *"What went wrong"*, which reads like a
project fault and is not.

## 10. Per-screen verification

**The gate item "Chrome MCP checks listed screen by screen" does not apply to this
project, and saying so is the correct answer rather than a gap.** `C3` is explicit: *no
web, no desktop, no tablet*. There is no web build to point a browser at, so a
screen-by-screen Chrome checklist would be 19 rows of *cannot run* — an artefact that looks
like coverage and measures nothing. That is the failure this project has hit repeatedly,
so the checklist is answered with a substitute and the substitution is named.

**The Android equivalents, by capability:**

| Capability | Chrome MCP would have… | Here it is done by |
|---|---|---|
| Renders, no overflow | load a route, screenshot | `flutter test integration_test` + `tester.pumpWidget`, asserting no `RenderFlex overflowed` exception |
| Visual capture | screenshot | `adb exec-out screencap -p > out.png`, then read it |
| Interaction | click | `tester.tap(find.by…))` on device |
| Font scale | viewport resize | `tester.view.physicalSize` / `tester.platformDispatcher.textScaleFactorTestValue` |
| Dark mode | prefers-color-scheme | `tester.platformDispatcher.platformBrightnessTestValue` |

**19 screen files exist** under `.forge/design/screens/`. None has a test, and none can
have one yet: `browse-catalogue`, `browse-genre`, `browse-sources`, `downloads`,
`history`, `library`, `more`, `novel-details`, `onboarding`, `reader`, `reader-chapter-sheet`,
`settings`, `settings-about`, `settings-reader`, `source-unavailable`, `sources`, `stats`,
`updates` (`_mihon-verdicts.md` is a verdict file, not a screen). **Every one of them is
an unimplemented route** — `main.dart` has no `home`, which is why the app renders black.

Ordered by which becomes runnable first, and each row states the *first* assertion that
would make it real:

| Order | Screen | First assertion |
|---:|---|---|
| 1 | `onboarding` | First route after launch; proves `home` exists at all |
| 2 | `library` | Empty state, then one row after a novel is kept — proves the drift read path |
| 3 | `reader` | A stored chapter opens with **no network**, which is `C14` and SC-2 |
| 4 | `novel-details`, `reader-chapter-sheet` | Chapter list is complete, whatever its length (`B9`) |
| 5 | `sources`, `browse-sources`, `source-unavailable` | The typed-error surface reaches the UI (`C6`, `C12`) |
| 6 | `browse-catalogue`, `browse-genre` | Popular + latest, and the pagination contract |
| 7 | `downloads` | Queue order is the reader's, never the chapter number's (`B18`) |
| 8 | `history`, `stats` | `B17` ordering, `B47` time-bounded retention |
| 9 | `updates` | A null `lastCheckedAt` reads as *"never checked"*, never as a count (`B49`) |
| 10 | `settings`, `settings-reader`, `settings-about`, `more` | Config reads and writes persist |

## 11. Environments, and their variables

### 11.1 The device

| | |
|---|---|
| Model | **nubia Z2577** |
| Android | **16 (API 36)** |
| ABI | **arm64-v8a** |
| Serial | `YBZ2577ALDAC000899` |
| Required device property | **`persist.log.tag=I`** — it ships `S`, which silences logcat and makes `flutter run` hang after `✓ Built …apk` with no VM Service URL |

### 11.2 Variables and commands

| Variable | Value | Why |
|---|---|---|
| `ANDROID_HOME` | `/home/tleguede/Android/Sdk` | Not auto-detected on this machine |
| `ANDROID_SDK_ROOT` | same value | `flutter doctor` reads both |
| `flutter config --jdk-dir` | `~/tools/jdk/jdk-21.0.12.1+1` | The SDK's JDK is **Java 25**; **Gradle 8.14 cannot run on it** |
| `DEVICE_ID` | `YBZ2577ALDAC000899` | Passed to `adb -s` and to `flutter test -d` |
| `$FORGE` | `~/.agents/skills/forge` | `forge-guard.js`, `consistency-check.js`, `state.js` |
| `persist.log.tag` | `I` | Device-side; see § 11.1 |

**There is no `.env`, no `--dart-define`, and no environment-conditional code**, and that
is deliberate: `C2` forbids telemetry and remote configuration, so a build that behaves
differently depending on a variable is a build whose behaviour cannot be reproduced from
the repository. `flutter test` reads no variables at all.

### 11.3 Two tool defects Phase 6 had to fix to make any of this checkable

1. **`check_plans.py` could not run outside the Codespace it was written in.**
   `ROOT = Path('/workspaces/lumen_tale')` and `FORGE = Path('/home/codespace/.agents/skills/forge')`
   were hardcoded, so the tool this register depends on to keep its counts **derived** died
   with `FileNotFoundError`. A regenerator that cannot run is an invitation to hand-edit,
   which is the defect this project keeps making. Both paths now resolve from `__file__`
   and `$FORGE`.
2. **`check_plans.py --test-plan` is not a mode.** `sys.argv[1:]` is a slice-name filter,
   so the documented command matched nothing and printed `no failures` — **a green over
   zero measurements**. `check_test_plan()` runs on every invocation. Corrected in § 6.

---

*Counts in § 1, § 2, § 3, § 7 and § 8 are recomputed from `.forge/plans/*.md` § 11 by
`python3 .forge/plans/check_plans.py` — no flag. Counts regenerate; prose does not. If a
number here disagrees with the plans, the plans are right.*