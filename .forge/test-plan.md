---
type: test-plan
status: draft
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

**E21 is the single hole, and it is not an oversight — it is in the wrong section.**
E21 is *« Novel Fire's terms are not confirmed »*, and its verification is
`2-1.md`'s § 10 acceptance criterion: *« `buildSourceRegistry()` renvoie une liste
de longueur **1**, et aucune classe Novel Fire »*. That is a real and correct check.
It is simply not in a § 11 table, so an id-coverage scan misses it.

*Stated rather than quietly fixed, because the fix would be cosmetic and the fact
is not:* **the one rule whose verification lives outside § 11 is the one gated on an
unresolved legal question (Q-004).** Moving the row would complete the table and make
the knowledge no easier to find.

## 3. What is written, as opposed to planned

| | Count |
|---|---:|
| Test rows specified across 38 plans | **1653** |
| § 11 `Emplacement` targets that exist on disk | **1 of 55** |
| Test cases actually written | **38** |
| Of those, host (`test/`), on the Dart VM | **32** |
| Of those, **on-device** (`integration_test/`), run on a real phone | **6** |
| Of the host 32, covering the database schema | **27** |
| Of the host 32, covering the app bootstrap | **5** |

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

## 6. What Phase 6 does next

1. **Cover the tests, not only the build.** ADR-011 makes the APK a CI dependency;
   nothing yet runs `flutter test` in CI or fails a build on a regression.
2. **Keep these numbers derived.** `check_plans.py --test-plan` recomputes § 1 and § 2.
   A hand-edited count here is the defect this project keeps making.
3. **Do not mark the E2E suite green.** 11 rows, 0 run, 0 devices. When Q-008 closes they
   become runnable; until then they are a specification, and the difference belongs here
   rather than in a status field.

---

*Derived from `.forge/plans/*.md` § 11 by `check_plans.py --test-plan`. Counts
regenerate; prose does not. If a number here disagrees with the plans, the plans are
right.*
