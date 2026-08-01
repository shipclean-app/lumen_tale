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
