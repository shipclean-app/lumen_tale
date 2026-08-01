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
9. **Localization**: wrap user-facing strings in `AppLocalizations` / `intl` (ARB-based if enabled). No hardcoded user-visible strings.
10. **Navigation**: all navigation goes through `go_router`; no `Navigator.push` outside the router setup.
