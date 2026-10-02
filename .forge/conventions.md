---
type: conventions
status: approved
generated_at: 2026-10-02
---

# Conventions techniques — Lumen Tale

> Document unique. All Phase 5 implementation plans reference this file rather than restating these rules.
> It starts in Phase 0 with what is known, is enriched in Phase 4, and may be amended at any time.
> Vague rules ("consistent error handling") must be rewritten as concrete rules before validation.
> Sections marked `À DÉCIDER EN PHASE 4` are completed during architecture design.

**Companion documents.** `AGENTS.md` and `.opencode/rules/` hold *what to follow* and are owned by `project-rules-architect`; this file holds *what we build with*. `DECISIONS.md` records why. Where this file and a rule file could both state a rule, the rule file owns it and this file cites it.

---

## Stack technique cible

Resolved versions are read from `pubspec.lock` at implementation time; this table states the choice and the reason, not the current patch.

| Domain | Choice | Version | Justification |
|---|---|---|---|
| Language | Dart | 3.13.5 | Satisfies `sdk: ^3.11.5` (`>=3.11.5 <4.0.0`). ADR-004 |
| Framework | Flutter | 3.47.6 | Current stable at adoption. ADR-004 |
| Identity provider | **None — by design** | — | Personal-use reader. Accounts and cross-device sync are v1 non-goals; ADR-010 |
| Session strategy | **None** | — | No auth means no session, no token storage, no refresh. `17-security.md` rule 8 forbids persisting credentials |
| Database | SQLite via `sqlite3` | 3.7.x | Native library provisioned through Dart build hooks (`native_toolchain_c`), which is why `sqlite3_flutter_libs` is banned. ADR-005 |
| ORM / query builder | drift + drift_dev | 2.35.x | ADR-005. Deliberately diverges from Mihon's SQLDelight — see the divergence table in ADR-008 |
| Background execution | workmanager | 0.10.x | **Scheduled library-update checks only.** The user-initiated download queue is in-process and cancellable (`07-downloads-offline.md`, `15-performance.md` §Background work) |
| State management | Riverpod (`flutter_riverpod` + `riverpod_generator`) | 3.4.x / 4.0.x | Codegen-first. `05-state-management.md` is the authority — this row only names the library |
| Forms | Material 3 `TextFormField` | — | Deferred form rules live in `09-widgets-ui.md` §Deferred and activate when text forms arrive |
| Validation | Dart types + `sealed` hierarchies | — | No validation library. `13-error-handling.md` owns the failure model; `Result<T>` is explicitly rejected |
| HTTP client | dio | 5.11.x | Shared client, interceptors, rate limiting in `core/network/` |
| Styling | Material 3 `ThemeData` + `ColorScheme.fromSeed` | — | ADR-001. Theme assembly in `app/theme/`; `14-design-tokens.md` is the authority |
| UI components | Material 3 built-ins | — | ADR-001. ShadCN / `flutter_shadcn_ui` is **banned** — it was contamination from another project, not a choice |
| Icons | Material Icons (bundled) | — | Ships with Flutter; no icon dependency |
| Unit tests | flutter_test | — | `10-testing.md` |
| Component tests | flutter_test widget tests | — | `10-testing.md` §Priorities P2 |
| E2E tests | À DÉCIDER EN PHASE 4 | — | Blocked on a device or emulator: this environment has no Android SDK and no Xcode (Q-003). Choosing an E2E framework is deferred until the target can actually run |
| Lint | flutter_lints + a project rule set | 6.0.0 | `analysis_options.yaml` adds `strict-casts`, `strict-inference`, `strict-raw-types`. Cite rule names, never counts |
| Format | `dart format` | — | Part of the definition of done in `AGENTS.md` |
| Package manager | pub, via `flutter pub add` / `remove` | — | **Hand-editing `pubspec.yaml` is forbidden.** `08-coding-standards.md` §Dependencies, `17-security.md` rule 12 |

---

## Structure de dossiers cible

The layout is the **target**; most of it does not exist yet. `02-architecture.md` is the authority — this copy exists so plans can reference paths.

```
lib/
├── main.dart              # bootstrap only: localization delegates + theme
├── l10n/                  # ARB sources + generated AppLocalizations
├── app/                   # bootstrap, router, theme assembly
├── core/                  # network, database, storage, ui, utils — no internal deps
├── domain/                # PURE DART — layer-first
│   ├── sources/           # Source contract + models (Novel, Chapter, Filter, …)
│   ├── models/            # freezed domain models
│   ├── repositories/      # abstract repository interfaces
│   └── interactors/       # use cases
├── data/                  # drift repositories, mappers, SourceManager
├── sources/implementations/  # one class per website + source_registry.dart
└── features/              # library, browse, novel_details, reader, updates,
                           # history, downloads, settings
```

**Domain layout is layer-first by owner decision**, diverging from Mihon's feature-first `domain/<feature>/{model,repository,interactor}`. See ADR-008 — do not "fix" this back toward Mihon.

---

## Conventions de nommage

| Element | Rule | Example |
|---|---|---|
| Widget / screen file | `snake_case` matching the public type | `library_screen.dart` → `LibraryScreen` |
| Service / utility file | `snake_case` matching the public type | `source_manager.dart` → `SourceManager` |
| Validation file | none — no validation library | — |
| Type file | `snake_case` matching the public type | `novel.dart` → `Novel` |
| Test file | mirrors the tested path, `_test.dart` suffix | `test/core/pipeline/converter_test.dart` |
| Routes / URLs | centralised constants in `app/router/`; never write a path literal in a feature | `AppRoutes.readerFor(novelId, chapterId)` |
| Component props | `final` named parameters, required when non-nullable | `NovelCard({required this.novel, this.onTap})` |
| Functions / methods | `camelCase`, verbs for actions | `fetchChapterContent`, `sanitizeSlug` |
| Constants | `lowerCamelCase`; `UPPER_SNAKE_CASE` only for compile-time consts | `chapterCount` |
| Enum values | `lowerCamelCase` | `NovelStatus.ongoing` |
| Folders | `snake_case` | `novel_details/` |

---

## Conventions de code

### Typage

- `strict-casts`, `strict-inference`, `strict-raw-types` are on. No `dynamic` where a type is known; no unchecked `as`.
- Domain models are `freezed` classes — immutable, generated `==`/`hashCode`/`copyWith`, `final` fields only, no setters.
- Never expose mutable collections; return `List.unmodifiable` or copy.
- `const` constructors wherever possible.

### Composants

- Stateless by default. `StatefulWidget` only for ephemeral state; anything durable goes through Riverpod.
- No business logic in widgets — read providers, call notifier methods.
- Shared presentation components live in `core/ui/`; feature-specific ones in `features/<f>/widgets/`.
- Material 3 built-ins over hand-rolled equivalents. `09-widgets-ui.md` is the authority.
- Every async view provides loading, error-with-retry, and empty states.
- Accessibility rules have a single owner: `14-design-tokens.md` §Accessibility (contrast AA, ≥48×48 touch targets, no colour-only state, semantics labels).

### State management

- Riverpod codegen-first: `@riverpod` + `dart run build_runner build --delete-conflicting-outputs`.
- `autoDispose` for screen-scoped providers; `keepAlive` only for global/session providers. Owned by `05-state-management.md` §Conventions rule 10.
- Repositories and interactors are providers; `SourceManager` is a provider built from `source_registry.dart`.
- Invalidate after mutation; group related invalidations into a named helper.
- Never modify another provider's state directly.

### Formulaires

- Deferred — no text form exists yet. `09-widgets-ui.md` §Deferred holds the parked rules (focus chaining, inline mutation). Do not implement them early.

### Data fetching

- UI → Riverpod provider → interactor → repository interface (`domain/`) → drift / dio.
- Reactive reads use drift query streams behind `StreamProvider`; no manual refresh.
- Domain never imports drift; DB rows never cross into features. Mapping lives in `data/mappers/`.
- Never `await` inside `build`; no network IO on the UI thread outside a provider.
- Aggregate queries over N+1 (`06-database.md` rule 8).

---

## Gestion d'erreur standard

Typed exceptions. `Result<T>` / `Either` is **rejected** — Riverpod `AsyncValue` already models async failure in the UI layer, and adding it would be noise. `13-error-handling.md` is the authority; this section states the pattern, not the rules.

### Erreurs réseau

```dart
// core/network — catch the primitive, rethrow a typed one carrying `cause`.
try {
  response = await dio.get<String>(path, options: opts);
} on DioException catch (e, st) {
  throw NetworkException('GET $path failed', cause: e);
}
```

### Erreurs de validation

```dart
// domain — no validation library; a sealed type per failure mode.
sealed class AppException implements Exception {
  const AppException(this.message, {this.cause});
  final String message; // developer-facing, NOT user-facing
  final Object? cause;
}
final class SourceException extends AppException { /* parsing */ }
final class NetworkException extends AppException { /* dio */ }
final class DatabaseException extends AppException { /* drift */ }
final class ChapterNotAvailableException extends AppException { /* body absent */ }
final class CancelledException extends AppException { /* user-cancelled */ }
```

### Erreurs serveur / du site distant

```dart
// A source returning nothing is a SUSPECTED layout change, not "no results".
// See 18-external-contracts.md §Cross-site rules rule 4.
if (nodes.isEmpty) {
  throw SourceException('$name: selector matched nothing — suspected layout drift');
}
```

---

## Stratégie de tests

### Tests unitaires

- Framework : `flutter_test`
- Pattern : fixture-driven; each source owns `test/fixtures/sources/<name>/`. The HTML→Markdown converter has its **own** suite at `test/fixtures/converter/` independent of any source — it is first-party code (ADR-003), so it carries first-party risk.
- Emplacement : `test/` mirroring `lib/`
- Commande : `flutter test`

### Tests de composants

- Framework : `flutter_test` widget tests
- Pattern : providers overridden; assert loading / error-with-retry / empty states, not implementation
- Mocking : `mocktail` for network and storage boundaries; in-memory drift for the database — never the real network (`10-testing.md` rule 7)
- Emplacement : `test/`
- Commande : `flutter test`

### Tests E2E

- Framework : À DÉCIDER EN PHASE 4 — blocked on a runnable target (Q-003)
- Pattern : À DÉCIDER EN PHASE 4
- Emplacement : À DÉCIDER EN PHASE 4
- Commande : À DÉCIDER EN PHASE 4

**Priorities.** P0: the converter, source parsing, chapter recognition, repository round-trips, domain value objects, route constants. P1: notifier state transitions via `ProviderContainer`. P2: shared component widget tests. `10-testing.md` is the authority.

---

## Patterns retenus

| Pattern | When to use it | Example |
|---|---|---|
| Provider family | parameterised state | `novelProvider(novelId)` |
| `StreamProvider` | drift-backed reactive data | library grid, chapter list, history |
| `AsyncNotifier` | async state machine with mutations | downloader, reader position |
| Injected repository interface | any data access from UI | `abstract class NovelRepository` in `domain/`, drift impl in `data/` |
| Named invalidation helper | several providers refresh together | `invalidateLibraryProviders(ref)` |
| Typed exception at the boundary | anything crossing a layer | dio → `NetworkException` |
| Sanitised slug for any source-provided path component | filesystem writes from scraped data | `17-security.md` rule 1 |
| Per-source selector + mapper override | a site deviates from the shared cleaner | `04-html-to-markdown.md` §Rules 2 |

---

## Commandes

```bash
flutter pub get                                   # resolve dependencies
flutter pub add <pkg>                             # add (dev:<pkg> for dev) — NEVER hand-edit pubspec.yaml
flutter pub remove <pkg>
dart format .                                     # format
flutter analyze                                   # must report zero issues, including info
flutter test                                      # must pass
flutter gen-l10n                                  # after editing any ARB file
dart run build_runner build --delete-conflicting-outputs   # riverpod / freezed / json_serializable / drift
dart run drift_dev schema dump lib/core/database   # after a table change
```

Flutter 3.47.6 is installed at `/home/codespace/flutter/bin`. `flutter build apk` is documented but **unvalidated here** — no Android SDK (Q-003).

**Definition of done** is defined once, in `AGENTS.md` §Definition of Done. Do not restate it.

---

## Ce qui n'appartient PAS à ce document

Any rule specific to a single slice goes in that slice's implementation plan, declared as a deviation. Anything that is a *rule to follow* rather than a *choice we made* belongs in `.opencode/rules/`, which `project-rules-architect` owns — this document cites those rules, never restates them.

---

## Checklist de gate

- [x] Every decision (naming, structure, error handling, testing) is actionable.
- [x] The target stack is fully specified; the only remaining `À DÉCIDER` is E2E, and it is blocked on a runnable target with the reason recorded (Q-003).
- [x] No `À DÉCIDER AVANT LA PHASE 1` box remains — auth and session are resolved as *none by design* (ADR-010).
- [x] No rule specific to a single slice.
- [x] Commands are documented and functional — `flutter analyze` reports zero issues and `flutter test` passes on the current tree.
- [x] Divergences from the Mihon reference are declared, not silent (ADR-008).

**Statut** : `draft` → enriched at each phase, locked in Phase 4.