# Design Tokens & Theming

A single source of truth for visual decisions. Material 3 (`ColorScheme.fromSeed`).

## Tokens

- Color, spacing, radius, typography, and elevation live in `app/theme/` as tokens / `ThemeExtension`s. No magic hex values or ad-hoc `EdgeInsets`/radii scattered in widgets — prefer the predefined tokens (`AppSpacing.md`, `AppRadius.md`, ...).
- The seed color + palette are defined once in `app/theme/`; features consume theme via `Theme.of(context)` / tokens, never hardcoded colors.
- Theme supports **light + dark**. `MaterialApp.themeMode` already defaults to `ThemeMode.system` — do not pass it redundantly (`avoid_redundant_argument_values` will flag it). Set `themeMode` explicitly only once a settings override exists.
- Semantic colors (`error`, `onSurface`, `surfaceContainer`, ...) rather than raw palette colors in components.

> **One location.** The theme lives in `app/theme/` — not `core/theme/`. `app/` owns theme assembly (seed color, `ThemeData`, `ThemeExtension`s) because theme is a presentation concern that no lower layer may import. `02-architecture.md` §Layout is the layout authority.

## Typography

- Use the `TextTheme` roles (headline/body/label). No fontSize overrides per-widget except where genuinely needed.
- Reader text sizing (font size, line height) is a **reader preference** driven by a provider, applied on the markdown view — not per-screen constants.

## Accessibility

**This section is the single owner of accessibility rules for the project.** `09-widgets-ui.md` §Conventions rule 8 points here; do not restate these rules there.

- **Contrast**: semantic colors must meet WCAG AA against their background in both themes. Verify when introducing a new color pair.
- **Touch targets**: ≥ 48 × 48 logical px for tappable affordances (icon buttons, list actions).
- **Text scale**: layouts must not overflow at large system text scales; use `FittedBox`/`Expanded`/scrollable patterns, not fixed-size boxes.
- **Semantics**: meaningful `Semantics` labels on icon-only buttons and cover thumbnails (title + "cover").
- **Screen readers**: every icon-only control has a label; a disabled control is marked disabled rather than merely dimmed.
- **No color-only state indicators** (status badges, downloaded flag): pair color with an icon or label.
- **Focus order on mobile**: the reading order must match the visual order, so TalkBack and switch access follow the screen top-to-bottom. Keyboard-tab traversal is a desktop concern and is out of scope for v1 (`01-project-vision.md` §Non-goals); do not add focus-chain rules until a desktop or form target exists.