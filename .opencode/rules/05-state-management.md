# State Management (Riverpod)

Riverpod covers both **state management** and **dependency injection**.

## Conventions

1. **Codegen first**: use `riverpod_annotation` (`@riverpod`) and run `dart run build_runner build --delete-conflicting-outputs`. Hand-written providers only when codegen does not apply.
2. **Provider families** for parameterized state: e.g. `novelProvider(novelId)` via `@riverpod`.
3. **Async values**: use `FutureProvider` / `AsyncNotifier` for anything async. Expose `AsyncValue` and let the UI handle `loading / error / data`.
4. **Streams**: use `StreamProvider` for drift-backed reactive data (library, chapters, history).
5. **Notifiers**: use `Notifier` / `AsyncNotifier` for complex state machines (downloader, reader). Keep mutation logic inside the notifier, never in widgets.
6. **Dumb widgets**: widgets consume providers; business logic lives in notifiers + `domain/interactors`.
7. **Scoping**: override providers at the router/feature scope where needed (e.g. a per-source instance). Prefer explicit overrides over global singletons.
8. **DI roles**: repositories and interactors are providers. `SourceManager` is a provider that builds the registry from `source_registry.dart`.
9. **No `ChangeNotifier`**: anything beyond trivial widget-local state uses Riverpod. `StatefulWidget` is allowed only for ephemeral state.
10. **AutoDispose**: prefer `autoDispose` for screen-scoped providers (search, browse) to free memory. Keep library/session providers non-disposing.

## Lifecycle

- `autoDispose` is the default for screen-scoped providers (search, browse, reader).
- `keepAlive` only for global / session providers (app preferences, `SourceManager`, library). Never `keepAlive` a parameterized provider without a reason.

## Invalidation (cache)

- After a mutation, refresh with `ref.invalidateSelf()` inside an `AsyncNotifier`, or `ref.invalidate(provider)` from the UI.
- When several providers must refresh together, group them in a named helper (e.g. `invalidateLibraryProviders(ref)`).

## Notifier patterns

- One notifier per concern (per screen/feature), never one giant provider exposing a whole state tree.
- Dependencies (repositories, interactors) are injected via `ref.watch` in `build()`.
- Mutations are public methods on the notifier; pages call `ref.read(provider.notifier).method(...)`.
- Navigation logic never lives in a provider.

## Anti-patterns

- A giant provider exposing an entire feature's state tree — split it.
- A provider modifying another provider's state directly — use `ref.invalidate` or `ref.read(other.notifier).action()`.
- `ref.read` in `build()` where you mean to listen — use `ref.watch`.
- Missing `.autoDispose` on page-scoped providers.
- Hand-writing a provider when `@riverpod` codegen applies (we use codegen, see rule 1).
