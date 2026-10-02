# Performance

## Builds & rebuilds

- **`const` first**: prefer `const` constructors on widgets where possible (enables canonicalization + subtree skipping). Flag any `const`-eligible widget with a mutable member.
- Keep the widget tree shallow: avoid deep nesting of `Padding`/`Align`/`Column` wrappers; extract `buildX()` methods into private widgets when it helps Flutter skip work.
- Prefer `const` widget boundaries and `RepaintBoundary` for expensive subtrees that repaint (reader page, covers grid item) — but never guess; measure.

## Lists & lazy loading

- Long lists (library, browse, chapter list, search results) use lazy builders (`ListView.builder` / `SliverList.builder`).
- Row items must be cheap: avoid `MediaQuery.of` per item where the value is constant, avoid allocating new listeners each build.
- Pagination is explicit (`hasNextPage` from the source contract); no unbounded scroll auto-loading of thousands of chapters at once.

## State & reactivity

- `ref.watch` only what a widget actually rebuilds for; watch the smallest provider (a field, not the whole feature state). Consider `select` for derived values.
- Provider lifetime (`autoDispose` / `keepAlive`) is owned by `05-state-management.md` §Conventions rule 10 — do not restate it here.
- Avoid `ref.read` in `build`; avoid setting providers during `build`.
- Image providers (covers): use `cached_network_image` with `memCacheWidth` / `memCacheHeight` set to the displayed size in logical pixels, to cap decode cost.

## Reader

- The reader renders Markdown from the `.md` on disk; do not re-parse/re-fetch on every rebuild — cache parsed content per chapter.
- Never do network IO inside `build`. A chapter fetch goes through a provider; the reader shows a loading state.

## Background work

Two mechanisms, two owners — they are not interchangeable:

- **The download queue runs in-process**, owned by `07-downloads-offline.md`. It is cancellable, reports per-chapter progress through a Riverpod provider, and is driven by the user from `features/downloads/`.
- **`workmanager` runs only scheduled library updates** (the periodic "check my novels for new chapters" job). It must not perform a user-initiated download, and a background job must never mutate provider state read by a live screen.

Both must keep heavy work off the UI isolate. Do not describe `workmanager` as "outside the UI isolate" — it is a separate platform callback, and the rule is the constraint (don't block the render thread), not the mechanism.

## Tooling

- Profile with Flutter DevTools (frames, memory, CPU) when a screen feels slow. Never "optimize" without a measured baseline.
- Watch for `jank`/`slow frame` in release builds on low-end devices during scroll and page turns.