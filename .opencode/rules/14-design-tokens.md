# Design Tokens & Theming

A single source of truth for visual decisions. ShadCN-based primitives over Material 3 (`ColorScheme.fromSeed`).

## Tokens

- Color, spacing, radius, typography, and elevation live in `core/theme/` as tokens / `ThemeExtension`s. No magic hex values or ad-hoc `EdgeInsets`/radii scattered in widgets — prefer the predefined tokens (`AppSpacing.md`, `AppRadius.md`, ...).
- Theme supports **light + dark**. Build with `ThemeMode.system` by default; a settings toggle may override.
- Semantic colors (error, success, onSurface, surfaceContainer...) rather than raw palette colors in components.
- The seed color + palette are defined once in `core/theme`; features consume theme via `Theme.of(context)` / tokens, never hardcoded colors.

## Typography

- Use the `TextTheme` roles (headline/body/label). No fontSize overrides per-widget except where genuinely needed.
- Reader text sizing (font size, line height) is a **reader preference** driven by a provider, applied on the markdown view — not per-screen constants.

## Accessibility

- **Contrast**: semantic colors must meet WCAG AA against their background in both themes. Verify when introducing new color pairs.
- **Touch targets**: ≥ 48 × 48 logical px for tappable affordances (icon buttons, list actions).
- **Text scale**: layouts must not overflow at large system text scales; use `FittedBox`/`Expanded`/scrollable patterns, not fixed-size boxes.
- **Semantics**: meaningful `Semantics` labels on icon-only buttons and cover thumbnails (title + "cover").
- **Focus/keyboard**: all interactive elements reachable via keyboard navigation on desktop; forms follow the (deferred) focus-navigation rules in `09-widgets-ui.md` when they arrive.
- No color-only state indicators (status badges, downloaded flag): pair color with an icon or label.
