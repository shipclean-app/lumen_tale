# UI Conventions

Material 3 primitives through the app's theme, adaptive layout.

## Conventions

1. **Design system**: use the theme in `app/theme/`. No hardcoded colors or spacing in widgets — use theme tokens (see `14-design-tokens.md`).
2. **Material 3 primitives**: build on Material 3 widgets (`FilledButton`, `Card`, `BottomSheet`, `AlertDialog`, `ListTile`, `NavigationBar`) rather than hand-rolling a control that Material already provides. When a primitive is missing, add it once to `core/ui/` and reuse it — never copy a widget into a feature.
3. **Feature layout**: one folder per feature with `screens/`, `widgets/`, `providers/` subfolders.
4. **Widgets**:
   - Stateless by default; `StatefulWidget` only for ephemeral state.
   - No business logic in widgets — read providers, call notifiers.
   - Extract reusable widgets into `features/<f>/widgets/`, or into `core/ui/` if shared across features.
5. **Reader UX**:
   - Continuous scroll for chapters (web-novel format), not paged viewers.
   - Persist scroll position as a **scroll offset** — `reading_positions.offset` — and restore it on reopen. **Not a page index.** ADR-009 chose the offset specifically so a future paged mode can resume without converting every stored position; a `lastPageRead` column would have to be migrated, not reinterpreted.
   - Font size / line height / theme controls in the reader toolbar.
   - Markdown rendering via `flutter_markdown_plus` with a custom stylesheet. (`flutter_markdown` is discontinued — `flutter pub get` warns about it. Use the `_plus` package.)
6. **Responsive**: **one column, capped and centred.** Past `--bp-mobile` the layout *stops growing*; it does not gain a second column, a `NavigationRail`, or a two-pane arrangement. Test on **phone only**.

   > **Amended 2026-10-02 — this rule previously said the opposite.** It read *"adaptive layout (NavigationRail on wide screens, bottom NavigationBar on narrow). Test on phone + tablet."* That was inherited from a cross-platform profile and it contradicted **ADR-019**, under which the owner excluded tablet, desktop, rail and two-pane layouts from the product. Eighteen screen files had implemented ADR-019 while this one rule file still ordered a rail — the exact failure `14-design-tokens.md`'s one-owner rule exists to prevent, and it was invisible because every structural check was green. **The rule, not the screens, was wrong.**
7. **Async states**: every async view provides loading, error (with retry), and empty states. No dead space.
8. **Accessibility**: one owner — `14-design-tokens.md` §Accessibility. Do not restate contrast, tap-target, or text-scale rules here; read them there.
9. **Localization**: one owner — `16-i18n.md`. Every user-visible string goes through `AppLocalizations`; no hardcoded user-visible strings.
10. **Navigation**: all navigation goes through `go_router`; no `Navigator.push` outside the router setup. Route paths are **centralized** (e.g. `app/router/app_routes.dart`) — never write path literals like `'/novel/$id'` in features; use the centralized constants/helpers.

## Overlays & feedback (centralized)

- Action menus and confirmations use the shared components in `core/ui/` (bottom sheets / dialogs) — no ad-hoc `showDialog` / `showModalBottomSheet` copies inside a feature.
- Lightweight feedback uses the app's snackbar wrapper in `core/ui/` — no scattered `ScaffoldMessenger` calls (see `13-error-handling.md` §User-facing mapping).
- After any `await` in a callback, guard with `if (!context.mounted)`.
- Never put domain/repository logic inside `core/ui/` overlay components — they receive already-resolved values and callbacks.

## Platform behavior

- Mobile-first (Android/iOS). Root pages use `SafeArea`; `SafeArea(bottom: false)` when a bottom nav is present.
- Keep one visual language: Material 3 via `app/theme/`. No ad-hoc Cupertino components.
- No homebrew `MethodChannel` without a strong reason — prefer existing plugins.
- Web is not a v1 target (`01-project-vision.md` §Non-goals). Do not add a web-compatibility constraint to a feature; if a change would make web cheap later, prefer it, but never trade mobile correctness for it.

## Deferred rules (do not apply yet)

These conventions are parked until the features that need them exist. They are not dead — do not delete them, and promote each into the body above the moment its trigger fires.

- **Form focus navigation** (Next/Done keyboard chaining) — when text forms arrive (source search filters, per-source settings).
- **Inline mutation forms** (no full-screen loader while saving) — when create/edit screens arrive.
- **Motion design system** (standardized durations/curves, `AnimationController` lifecycle) — when reader/splash animations are defined.