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
- `autoDispose` page-scoped providers (search, browse, reader) to free memory on pop.
- Avoid `ref.read` in `build`; avoid setting providers during `build`.
- Image providers (covers): use `cached_network_image` (`CacheWidth`/`CacheHeight` set to the displayed size to cap decode cost).

## Reader

- The reader renders Markdown from the `.md` on disk; do not re-parse/re-fetch on every page turn — cache parsed content per chapter.
- Background jobs (downloads/updates via `workmanager`) run outside the UI isolate; they must not block the render thread.

## Tooling

- Profile with Flutter DevTools (frames, memory, CPU) when a screen feels slow. Never "optimize" without a measured baseline.
- Watch for `jank`/`slow frame` in release builds on low-end devices during scroll and page turns.
