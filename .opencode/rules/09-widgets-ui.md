# UI Conventions

ShadCN (`flutter_shadcn_ui`) + Material 3, adaptive layout.

## Conventions

1. **Design system**: use the theme in `app/theme/`. No hardcoded colors or spacing in widgets — use theme tokens.
2. **ShadCN primitives**: prefer `ShadButton`, `ShadCard`, `ShadSheet`, etc. over hand-rolled Material widgets for standard controls. Material 3 is the fallback where ShadCN lacks a primitive.
3. **Feature layout**: one folder per feature with `screens/`, `widgets/`, `providers/` subfolders.
4. **Widgets**:
   - Stateless by default; `StatefulWidget` only for ephemeral state.
   - No business logic in widgets — read providers, call notifiers.
   - Extract reusable widgets into `features/<f>/widgets/`, or into `core` if shared across features.
5. **Reader UX**:
   - Continuous scroll for chapters (web-novel format), not paged viewers.
   - Persist scroll position (`lastPageRead`) and restore it on reopen.
   - Font size / line height / theme controls in the reader toolbar.
   - Markdown rendering via `flutter_markdown` with a custom stylesheet.
6. **Responsive**: adaptive layout (NavigationRail on wide screens, bottom NavigationBar on narrow). Test on phone + tablet.
7. **Async states**: every async view provides loading, error (with retry), and empty states. No dead space.
8. **Accessibility**: semantic labels, contrast, tap targets ≥ 48px, correct text scaling.
9. **Localization**: the app ships FR + EN. Every user-visible string goes through ARB (`app_fr.arb` + `app_en.arb`) — see `16-i18n.md`. No hardcoded user-visible strings.
10. **Navigation**: all navigation goes through `go_router`; no `Navigator.push` outside the router setup. Route paths are **centralized** (e.g. `app/router/app_routes.dart`) — never write path literals like `'/novel/$id'` in features; use the centralized constants/helpers.

## Overlays & feedback (centralized)

- Action menus and confirmations use centralized ShadCN-based components (sheets / dialogs) — no ad-hoc `showDialog` / `showModalBottomSheet` copies.
- Lightweight feedback uses the app's toast/snackbar wrapper — no scattered `ScaffoldMessenger` calls (see `13-error-handling.md`).
- After any `await` in a callback, guard with `if (!context.mounted)`.
- Never put domain/repository logic inside `core/ui` overlay components.

## Platform behavior

- Mobile-first (Android/iOS). Root pages use `SafeArea`; `SafeArea(bottom: false)` when a bottom nav is present.
- Keep one visual language (ShadCN primitives + Material 3) — no ad-hoc Cupertino components.
- No homebrew `MethodChannel` without a strong reason — prefer existing plugins.
- Flag any `dart:io` import that could break a future web target.

## Deferred rules (do not apply yet)

These conventions are parked until the features that need them exist:

- **Form focus navigation** (Next/Done keyboard chaining) — when text forms arrive.
- **Inline mutation forms** (no full-screen loader while saving) — when create/edit screens arrive.
- **Motion design system** (standardized durations/curves, `AnimationController` lifecycle) — when reader/splash animations are defined.
