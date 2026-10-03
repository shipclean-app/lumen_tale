---
type: implementation-plan
slice: theme-type
module: theme
status: planned
generated_at: 2026-10-02
derived_from:
  - .forge/prd.md
  - .forge/architecture.md
  - .forge/design/design-system.md
  - .forge/design/screens/settings-reader.md
conventions_ref: .forge/conventions.md
---

# Plan d'implémentation — `theme-type`

> **Fondation transverse.** Ce plan est le premier de la série : `0-5` (la coquille
> applicative) et `2-8` (le thème et la taille de texte dans le lecteur) en dépendent.
> Il ne construit **aucun écran**. Sa « Phase 3 — Interface utilisateur » est donc
> vide, et § 9 dit pourquoi.
>
> **F-003** : `coverage-check.js slice` ne lit que `state.slices`, donc les
> `rule_ids` d'une fondation ne sont **jamais** vérifiées mécaniquement
> (`.forge/plans/README.md` § 2). Ce plan est vérifié à la lecture et par
> `.forge/plans/check_plans.py`, qui traite les fondations.

---

## Sources

- **PRD** : `.forge/prd.md` — règles **B26**, **B27** ; edge cases **E13**, **E14** ; contraintes **C3**, **C11**, **C13**
- **Architecture** : `.forge/architecture.md` § 2 (`theme-type`), § 1.1 (versions résolues), ADR-016, ADR-017
- **Design system** : `.forge/design/design-system.md` § 0.0 (classes de couleur), § 0 (les trois choix contestables), § 1.1 (16 jetons de couleur), § 1.2 (deux échelles typographiques), § 1.3–§ 1.8 (spacing, shadows, borders, motion, mapping Flutter)
- **Design écran** : `.forge/design/screens/settings-reader.md` (la seule surface qui *consomme* cette fondation)
- **Règles projet** : `14-design-tokens.md` (**propriétaire unique de l'accessibilité** — lu en entier), `09-widgets-ui.md` §Conventions 1, `08-coding-standards.md`, `05-state-management.md`, `16-i18n.md`

---

## 1. Résumé de la slice

`theme-type` produit **trois choses**, toutes sans interface :

1. `LumenColors`, une `ThemeExtension` portant **les seize jetons de couleur** de
   `design-system.md` § 1.1, avec **deux jeux de valeurs indépendants** — jour et
   nuit. Pas une inversion de l'autre : **ADR-016** le dit, et le § 0 du design system
   l'argumente (champ froid à `#121315`, texte chaud à `#E8E4DD`, sinon l'accent
   ambré se lit comme une erreur).
2. Les **deux échelles typographiques** de § 1.2 — l'échelle UI sur les slots
   Material 3 de `TextTheme`, l'échelle lecteur (`sm`…`xxl`) sur un style unique.
3. **L'override persistant** : `themeMode` (`system` | `day` | `night`) et
   `readerTextScale` (`sm`…`xxl`), écrits dans `shared_preferences`, exposés en
   providers `keepAlive`.

**Cette fondation ne produit aucun écran, aucun composant, aucun texte, aucun
contrat réseau.** Elle ne touche pas `shared_preferences` pour y mettre autre chose
que ces deux réglages : `architecture.md` § 4.7 déclare que les réglages de lecture
vivent là et nulle part ailleurs.

**Elle ne produit pas non plus le texte en soi.** Les six chaînes des écrans de
réglages sont `localisation` (ARB + repli FR, B28) ; cette fondation ne possède que
les **valeurs**, jamais les **libellés**.

**User stories couvertes** : US-14 (mode sombre), US-15 (taille de texte)
**Règles métier couvertes** : B26, B27
**Edge cases couverts** : E13, E14
**Contraintes couvertes** : C3, C11, C13

---

## 2. Contrats de données (code)

> Traduction mécanique de `design-system.md` § 1.1 et § 1.2. **Aucun hexadécimal
> inventé, aucune valeur dupliquée ailleurs** : chaque valeur ci-dessous est celle
> que le design system déclare, et les colonnes `Day`/`Night` sont les deux
> premières colonnes de sa table § 1.1.

### 2.1 Schémas de validation

**Aucun.** Il n'y a pas de base de données ici et il n'y en aura pas : deux clés de
`shared_preferences`, deux chaînes. `architecture.md` § 4.7 fait de `shared_preferences`
le lieu des réglages de lecture, et une table drift pour deux valeurs serait
`06-database.md` violé.

### 2.2 Types et interfaces

```dart
// lib/app/theme/lumen_colors.dart
import 'package:flutter/material.dart';

/// `design-system.md` § 1.1 — les seize jetons, deux valeurs par jeton.
///
/// **Une seule classe, deux jeux de valeurs, pas deux classes suffixées
/// `_light`/`_dark`.** Le design system explique pourquoi en § 1.1 : écrit en deux
/// tableaux, chaque nom de jeton apparaît deux fois, `design-check contrast` résout
/// à la *dernière* occurrence et ne mesure donc que la nuit, et `tokens-used`
/// signale le tableau du jour comme dix-huit écrans en désaccord avec le design
/// system — c'est-à-dire le fichier en désaccord avec lui-même.
@immutable
class LumenColors extends ThemeExtension<LumenColors> {
  const LumenColors({
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceSunken,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.textInverse,
    required this.accent,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.border,
    required this.borderField,
    required this.borderFocus,
    required this.borderStrong,
  });

  /// § 1.1, colonne Day. `--color-background` est du papier chaud `#F5F2ED`, et
  /// **jamais** `#FFFFFF` : le blanc pur est un défaut anonyme, pas un choix.
  factory LumenColors.day() => const LumenColors(
        background: Color(0xFFF5F2ED),
        surface: Color(0xFFFBF9F6),
        surfaceRaised: Color(0xFFFEFCF9),
        surfaceSunken: Color(0xFFEBE7E0),
        textPrimary: Color(0xFF1A1714),
        textSecondary: Color(0xFF5A524A),
        textDisabled: Color(0xFF6E665C),
        textInverse: Color(0xFFFDFAF6),
        accent: Color(0xFF8A4B12),
        success: Color(0xFF40713A),
        warning: Color(0xFF8A5A12),
        error: Color(0xFF8A3228),
        info: Color(0xFF426986),
        border: Color(0xFFD9D3C9),
        borderField: Color(0xFF8F8778),
        borderFocus: Color(0xFF8A4B12),
        borderStrong: Color(0xFF6B645E),
      );

  /// § 1.1, colonne Night. Champ **froid**, texte **chaud** — ADR-016.
  factory LumenColors.night() => const LumenColors(
        background: Color(0xFF121315),
        surface: Color(0xFF1A1C1F),
        surfaceRaised: Color(0xFF232629),
        surfaceSunken: Color(0xFF0C0D0F),
        textPrimary: Color(0xFFE8E4DD),
        textSecondary: Color(0xFFA8A29A),
        textDisabled: Color(0xFF948E87),
        textInverse: Color(0xFF17181A),
        accent: Color(0xFFE3A857),
        success: Color(0xFF7FBE72),
        warning: Color(0xFFE0AC47),
        error: Color(0xFFEE8B76),
        info: Color(0xFF7FB3DA),
        border: Color(0xFF2E3237),
        borderField: Color(0xFF6B6560),
        borderFocus: Color(0xFFE3A857),
        borderStrong: Color(0xFF8A8885),
      );

  final Color background;
  final Color surface;
  final Color surfaceRaised;
  final Color surfaceSunken;
  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;
  final Color textInverse;
  final Color accent;
  final Color success;
  final Color warning;
  final Color error;
  final Color info;

  /// `exempt` au sens de § 0.0 : règle décorative entre deux lignes de liste.
  /// Elle ne porte aucune information et n'est pas une frontière de composant,
  /// donc WCAG 1.4.11 ne s'y applique pas. **Ne pas la faire passer en
  /// `nontext`** pour la rendre mesurable : la mesurer exigerait de mentir sur ce
  /// qu'elle est.
  final Color border;

  /// Frontière de composant : WCAG 1.4.11, seuil 3:1.
  final Color borderField;
  final Color borderFocus;
  final Color borderStrong;

  /// Lecture : `Theme.of(context).extension<LumenColors>()!`.
  ///
  /// L'extension est enregistrée sur **les deux** `ThemeData` (§ 2.3). Un
  /// `extension` absent est un bug d'enregistrement, jamais une valeur de repli
  /// acceptable : `!` le rend bruyant au lieu de le laissermuet.
  static LumenColors of(BuildContext context) =>
      Theme.of(context).extension<LumenColors>()!;

  @override
  LumenColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceRaised,
    Color? surfaceSunken,
    Color? textPrimary,
    Color? textSecondary,
    Color? textDisabled,
    Color? textInverse,
    Color? accent,
    Color? success,
    Color? warning,
    Color? error,
    Color? info,
    Color? border,
    Color? borderField,
    Color? borderFocus,
    Color? borderStrong,
  }) {
    return LumenColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceSunken: surfaceSunken ?? this.surfaceSunken,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textDisabled: textDisabled ?? this.textDisabled,
      textInverse: textInverse ?? this.textInverse,
      accent: accent ?? this.accent,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      info: info ?? this.info,
      border: border ?? this.border,
      borderField: borderField ?? this.borderField,
      borderFocus: borderFocus ?? this.borderFocus,
      borderStrong: borderStrong ?? this.borderStrong,
    );
  }

  /// Interpolation requise par `ThemeExtension`.
  ///
  /// Elle sert **un seul** cas réel : la transition de thème de la coquille
  /// (`AnimatedTheme`). Elle interpole dans l'espace ARGB du Flutter, qui n'est
  /// pas perceptuellement uniforme — c'est acceptable ici parce qu'aucune animation
  /// de thème ne dure plus de `--duration-normal`, donc le mélange n'est jamais vu.
  @override
  LumenColors lerp(covariant LumenColors? other, double t) {
    if (other == null) return this;
    return LumenColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      surfaceSunken: Color.lerp(surfaceSunken, other.surfaceSunken, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      textInverse: Color.lerp(textInverse, other.textInverse, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      info: Color.lerp(info, other.info, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderField: Color.lerp(borderField, other.borderField, t)!,
      borderFocus: Color.lerp(borderFocus, other.borderFocus, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LumenColors &&
          runtimeType == other.runtimeType &&
          background == other.background &&
          surface == other.surface &&
          surfaceRaised == other.surfaceRaised &&
          surfaceSunken == other.surfaceSunken &&
          textPrimary == other.textPrimary &&
          textSecondary == other.textSecondary &&
          textDisabled == other.textDisabled &&
          textInverse == other.textInverse &&
          accent == other.accent &&
          success == other.success &&
          warning == other.warning &&
          error == other.error &&
          info == other.info &&
          border == other.border &&
          borderField == other.borderField &&
          borderFocus == other.borderFocus &&
          borderStrong == other.borderStrong;

  @override
  int get hashCode => Object.hash(
        background,
        surface,
        surfaceRaised,
        surfaceSunken,
        textPrimary,
        textSecondary,
        textDisabled,
        textInverse,
        accent,
        success,
        warning,
        error,
        info,
        border,
        borderField,
        borderFocus,
        borderStrong,
      );
}
```

```dart
// lib/app/theme/lumen_spacing.dart
import 'package:flutter/material.dart';

/// `design-system.md` § 1.3 — base 4dp, huit jetons.
@immutable
class LumenSpacing extends ThemeExtension<LumenSpacing> {
  const LumenSpacing({
    required this.xs2, // 2dp  — badge inset
    required this.xs, // 4dp  — inside a chip
    required this.sm, // 8dp  — gap inside a group
    required this.md, // 12dp — standard gap, list row padding
    required this.lg, // 16dp — between groups
    required this.xl, // 24dp — section break
    required this.xl2, // 32dp — major section break
    required this.xl3, // 48dp — page top margin, empty-state block
  });

  factory LumenSpacing.standard() => const LumenSpacing(
        xs2: 2,
        xs: 4,
        sm: 8,
        md: 12,
        lg: 16,
        xl: 24,
        xl2: 32,
        xl3: 48,
      );

  final double xs2;
  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double xl2;
  final double xl3;

  static LumenSpacing of(BuildContext context) =>
      Theme.of(context).extension<LumenSpacing>()!;

  @override
  LumenSpacing copyWith({
    double? xs2,
    double? xs,
    double? sm,
    double? md,
    double? lg,
    double? xl,
    double? xl2,
    double? xl3,
  }) =>
      LumenSpacing(
        xs2: xs2 ?? this.xs2,
        xs: xs ?? this.xs,
        sm: sm ?? this.sm,
        md: md ?? this.md,
        lg: lg ?? this.lg,
        xl: xl ?? this.xl,
        xl2: xl2 ?? this.xl2,
        xl3: xl3 ?? this.xl3,
      );

  @override
  LumenSpacing lerp(covariant LumenSpacing? other, double t) =>
      other == null ? this : copyWith();
}
```

```dart
// lib/app/theme/lumen_radius.dart
import 'package:flutter/material.dart';

/// `design-system.md` § 1.5 — cinq rayons plus les deux épaisseurs de trait.
/// `--radius-none` est `BorderRadius.zero` et n'est **pas** un jeton stocké : c'est
/// l'absence de rayon, et lui donner une constante l'inviterait à être posé.
@immutable
class LumenRadius extends ThemeExtension<LumenRadius> {
  const LumenRadius({
    required this.sm, // 4dp   — chips, small badges
    required this.md, // 8dp   — text fields, buttons
    required this.lg, // 16dp  — sheets, cards, dialogs
    required this.full, // 999dp — pills, the unread count dot
  });

  factory LumenRadius.standard() => const LumenRadius(
        sm: 4,
        md: 8,
        lg: 16,
        full: 999,
      );

  final double sm;
  final double md;
  final double lg;
  final double full;

  /// § 1.5 — un seul trait, 1dp, plus une version renforcée 2dp pour la ligne
  /// sélectionnée et le champ focalisé.
  static const double borderWidth = 1;
  static const double borderWidthStrong = 2;

  /// La colonne de prose du lecteur. `design-system.md` § 1.5 le déclare
  /// explicitement, donc il a une valeur — mais pas une extension : personne ne
  /// doit pouvoir le changer par thème.
  static const BorderRadius none = BorderRadius.zero;

  static LumenRadius of(BuildContext context) =>
      Theme.of(context).extension<LumenRadius>()!;

  BorderRadius get smAll => BorderRadius.circular(sm);
  BorderRadius get mdAll => BorderRadius.circular(md);
  BorderRadius get lgAll => BorderRadius.circular(lg);
  BorderRadius get fullAll => BorderRadius.circular(full);

  @override
  LumenRadius copyWith({double? sm, double? md, double? lg, double? full}) =>
      LumenRadius(
        sm: sm ?? this.sm,
        md: md ?? this.md,
        lg: lg ?? this.lg,
        full: full ?? this.full,
      );

  @override
  LumenRadius lerp(covariant LumenRadius? other, double t) =>
      other == null ? this : copyWith();
}
```

```dart
// lib/app/theme/shadows.dart
import 'package:flutter/material.dart';

/// `design-system.md` § 1.4 — **deux** ombres, pour deux choses qui flottent
/// réellement : une feuille modale et une boîte de dialogue. Tout le reste est
/// `--shadow-none`, et la séparation sur une surface plate est
/// `--color-border`, un pas de fond, ou de l'espace.
@immutable
class LumenShadows extends ThemeExtension<LumenShadows> {
  const LumenShadows({required this.sheet, required this.dialog});

  /// En thème nuit les ombres sont **inchangées** : sur un champ `#121315` une
  /// ombre sombre est presque invisible, et c'est pourquoi la nuit a une surface
  /// relevée. C'est l'exception délibérée que § 1.4 enregistre.
  factory LumenShadows.standard() => const LumenShadows(
        sheet: <BoxShadow>[
          BoxShadow(
            color: Color(0x2E000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
        dialog: <BoxShadow>[
          BoxShadow(
            color: Color(0x3D000000),
            blurRadius: 48,
            offset: Offset(0, 16),
          ),
        ],
      );

  /// `0 8 24 rgba(0,0,0,0.18)` — feuille inférieure, barre de contrôles du lecteur.
  final List<BoxShadow> sheet;

  /// `0 16 48 rgba(0,0,0,0.24)` — boîte de dialogue modale uniquement.
  final List<BoxShadow> dialog;

  static LumenShadows of(BuildContext context) =>
      Theme.of(context).extension<LumenShadows>()!;

  @override
  LumenShadows copyWith({List<BoxShadow>? sheet, List<BoxShadow>? dialog}) =>
      LumenShadows(sheet: sheet ?? this.sheet, dialog: dialog ?? this.dialog);

  @override
  LumenShadows lerp(covariant LumenShadows? other, double t) =>
      other == null ? this : copyWith();
}
```

```dart
// lib/app/theme/motion.dart
import 'package:flutter/material.dart';

/// `design-system.md` § 1.6 — nommées, pas « une jolie transition ».
@immutable
class LumenMotion extends ThemeExtension<LumenMotion> {
  const LumenMotion({
    required this.fast,
    required this.normal,
    required this.slow,
    required this.standard,
    required this.decelerate,
    required this.accelerate,
    required this.reduced,
  });

  factory LumenMotion.standard() => const LumenMotion(
        fast: Duration(milliseconds: 120),
        normal: Duration(milliseconds: 200),
        slow: Duration(milliseconds: 320),
        standard: Cubic(0.2, 0, 0, 1),
        decelerate: Cubic(0, 0, 0, 1),
        accelerate: Cubic(0.3, 0, 1, 1),
        reduced: Duration.zero,
      );

  /// 120ms — retour de pression, sélection de jeton.
  final Duration fast;

  /// 200ms — poussée d'écran, entrée de feuille.
  final Duration normal;

  /// 320ms — révélation du chrome du lecteur, restauration du défilement.
  final Duration slow;

  /// `cubic-bezier(0.2, 0, 0, 1)`
  final Curve standard;

  /// `cubic-bezier(0, 0, 0, 1)` — entrée.
  final Curve decelerate;

  /// `cubic-bezier(0.3, 0, 1, 1)` — sortie.
  final Curve accelerate;

  /// **Zéro, jamais une durée plus courte.** § 1.6 : sous « réduire les
  /// animations » du système, chaque durée devient `0ms` et la révélation du
  /// chrome devient instantanée. Une application de lecture qui anime une
  /// restauration que le lecteur n'a pas demandée est pire que celle qui ne
  /// l'anime pas.
  final Duration reduced;

  /// Le point unique où le réglage système est lu. Tout écran qui anime
  /// appelle `LumenMotion.of(context).duration(context, base)` et n'en compare
  /// jamais `== Duration.zero` lui-même.
  Duration duration(BuildContext context, Duration base) =>
      MediaQuery.disableAnimationsOf(context) ? reduced : base;

  Curve curve(BuildContext context, Curve base) =>
      MediaQuery.disableAnimationsOf(context) ? Curves.linear : base;

  static LumenMotion of(BuildContext context) =>
      Theme.of(context).extension<LumenMotion>()!;

  @override
  LumenMotion copyWith({
    Duration? fast,
    Duration? normal,
    Duration? slow,
    Curve? standard,
    Curve? decelerate,
    Curve? accelerate,
    Duration? reduced,
  }) =>
      LumenMotion(
        fast: fast ?? this.fast,
        normal: normal ?? this.normal,
        slow: slow ?? this.slow,
        standard: standard ?? this.standard,
        decelerate: decelerate ?? this.decelerate,
        accelerate: accelerate ?? this.accelerate,
        reduced: reduced ?? this.reduced,
      );

  @override
  LumenMotion lerp(covariant LumenMotion? other, double t) =>
      other == null ? this : copyWith();
}
```

```dart
// lib/app/theme/reader_scale.dart
import 'package:flutter/material.dart';

/// L'échelle lecteur de `design-system.md` § 1.2 — **cinq pas, un plancher de
/// 16px, un interligne constant de 1.72**.
///
/// B27 expose ces cinq pas au lecteur. Ils ne sont jamais appliqués un par un :
/// voir § 3.2 pour la composition avec l'échelle du téléphone.
enum ReaderTextScale {
  /// 16 / 27 — le plus petit pas lisible. `design-quality.md` § 3 interdit de
  /// descendre sous 16px sur mobile, donc ce pas **est** le plancher : E14
  /// (« pas de texte rogné à la plus grande taille ») et le plancher « jamais
  /// sous 16px » ne peuvent pas être violés en même temps.
  sm(16, 27),

  /// 18 / 31 — **le défaut**.
  md(18, 31),

  /// 20 / 34
  lg(20, 34),

  /// 23 / 39
  xl(23, 39),

  /// 26 / 44 — le plus grand pas.
  xxl(26, 44);

  const ReaderTextScale(this.fontSize, this.lineHeight);

  /// Taille en pixels logiques.
  final double fontSize;

  /// Hauteur de ligne en pixels logiques. **1.72 à chaque pas, tenu constant
  /// exprès** : mettre l'interligne à l'échelle de la taille casserait le rythme
  /// de lecture entre les pas, et un rythme qui change quand le lecteur change la
  /// taille est un rythme auquel il ne peut pas s'habituer.
  final double lineHeight;

  /// L'ordre est l'ordre de la liste ; `index` est donc l'ordre du curseur dans
  /// `SettingsChoiceSheet` et ne doit pas être utilisé pour autre chose.
  int get index => ReaderTextScale.values.indexOf(this);

  static ReaderTextScale fromIndex(int i) =>
      ReaderTextScale.values[i.clamp(0, ReaderTextScale.values.length - 1)];

  /// Lecture depuis la clé persistée.
  ///
  /// **Toute valeur inconnue retombe sur `md`, silencieusement et sans lever.**
  /// La clé vient de `shared_preferences` et peut avoir été écrite par une version
  /// antérieure : une version supprimée ne doit pas rendre l'app incapable de
  /// démarrer. C'est un réglage d'affichage, pas de la donnée.
  static ReaderTextScale fromStorage(String? raw) {
    for (final step in ReaderTextScale.values) {
      if (step.name == raw) return step;
    }
    return ReaderTextScale.md;
  }
}

/// Le style de prose du lecteur — **le seul** style typographique que le chrome
/// n'utilise pas, et le seul qui soit construit à la main plutôt que porté par
/// un slot Material 3 (`design-system.md` § 1.8 : « plus un style `readerProse` »).
///
/// **Chaîne de préférence sérif, rien d'embarqué (ADR-017).** `Noto Serif` puis
/// `Roboto Slab` puis le sérif de la plateforme, avec la sans de la plateforme en
/// repli garanti : une famille manquante se dégrade en texte lisible, jamais en
/// carrés.
@immutable
class LumenReaderProse extends ThemeExtension<LumenReaderProse> {
  const LumenReaderProse({required this.familyFallback});

  factory LumenReaderProse.standard() =>
      const LumenReaderProse(familyFallback: null);

  /// `null` = utiliser `fontFamilyFallback` seul. Réservé au cas où une future
  /// décision d'ADR embarque une face de lecture ; **v1 ne l'embarque pas**.
  final String? familyFallback;

  static const List<String> serifChain = <String>[
    'Noto Serif',
    'Roboto Slab',
  ];

  /// **B27 — la règle de composition.** Le pas choisi donne la taille ; l'échelle
  /// du téléphone la multiplie. Les deux ne s'annulent pas : l'utilisateur qui a
  /// réglé son téléphone à 130 % et choisi `xl` obtient bien plus grand que
  /// quiconque.
  ///
  /// Le plancher et le plafond sont posés **sur le produit**, pas sur le pas :
  /// sans cela, un pas `xxl` à 200 % donne 52px, et le lecteur perd sa mesure.
  static const double minProduct = 16.0;
  static const double maxProduct = 40.0;

  TextStyle styleFor(
    ReaderTextScale step,
    TextScaler platformScaler,
  ) {
    final product = step.fontSize * platformScaler.scale(1);
    final size = product.clamp(minProduct, maxProduct);
    // L'interligne suit la taille **effective**, pas la taille nominale : sinon
    // un texte agrandi garde 1.72 d'une base trop petite et les lignes se
    // chevauchent — ce qu'E14 nomme explicitement.
    final lineHeight = size * (step.lineHeight / step.fontSize);
    return TextStyle(
      fontSize: size,
      height: lineHeight / size,
      fontFamilyFallback: <String>[...serifChain, if (familyFallback != null) familyFallback!],
      color: null, // ←heritée du thème, jamais écrite ici
    );
  }

  static LumenReaderProse of(BuildContext context) =>
      Theme.of(context).extension<LumenReaderProse>()!;

  @override
  LumenReaderProse copyWith({String? familyFallback}) =>
      LumenReaderProse(familyFallback: familyFallback ?? this.familyFallback);

  @override
  LumenReaderProse lerp(covariant LumenReaderProse? other, double t) =>
      other == null ? this : copyWith();
}
```

```dart
// lib/app/theme/theme_override.dart
import 'package:flutter/material.dart';

/// B26 — « suivre le téléphone, ou le surpasser ».
enum ThemeOverride {
  /// Suit `MediaQuery.platformBrightnessOf`. **La valeur par défaut**, et la
  /// seule qui honore le réglage du téléphone sans qu'un état interne le remplace.
  system,

  /// Jour forcé : papier chaud.
  day,

  /// Nuit forcée : encre froide.
  night;

  static ThemeOverride fromStorage(String? raw) {
    for (final value in ThemeOverride.values) {
      if (value.name == raw) return value;
    }
    return ThemeOverride.system;
  }

  /// Le **seul** endroit du projet qui traduit l'override en `ThemeMode`.
  /// `0-5` ne le fera pas lui-même : deux traductions de la même valeur sont deux
  /// réponses à la question « quelle nuit ? ».
  ThemeMode resolve(Brightness platformBrightness) => switch (this) {
        ThemeOverride.system =>
          platformBrightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
        ThemeOverride.day => ThemeMode.light,
        ThemeOverride.night => ThemeMode.dark,
      };
}
```

```dart
// lib/app/theme/app_theme_preferences.dart
import 'package:shared_preferences/shared_preferences.dart';

/// Les deux réglages que cette fondation possède, et rien d'autre.
///
/// `architecture.md` § 4.7 : les réglages de lecture vivent dans
/// `shared_preferences`, pas dans une table drift. Cette classe ne stocke que ces
/// deux clés.
///
/// **Aucune valeur par défaut n'est écrite à la construction.** Le défaut est une
/// *absence* de clé, et l'absence se résout en `system` / `md`. Écrire la
///'default' au premier démarrage créerait une troisième source de vérité : le
/// fichier, l'absence de clé, et l'enum.
abstract interface class AppThemePreferences {
  ThemeOverride readThemeOverride();
  ReaderTextScale readReaderScale();
  Future<void> writeThemeOverride(ThemeOverride value);
  Future<void> writeReaderScale(ReaderTextScale value);
}

final class SharedPrefsThemePreferences implements AppThemePreferences {
  const SharedPrefsThemePreferences(this._prefs);

  final SharedPreferences _prefs;

  static const String themeOverrideKey = 'app.themeOverride';
  static const String readerScaleKey = 'reader.textScale';

  /// `SharedPreferences` est déjà chargé au démarrage (`getInstance()` est un
  /// futur résolu une fois), donc une lecture ici est **synchrone** et ne peut
  /// pas être un `AsyncValue`. `14-design-tokens.md` § `Switch` s'appuie
  /// exactement sur cela pour justifier l'absence d'état de chargement.
  @override
  ThemeOverride readThemeOverride() =>
      ThemeOverride.fromStorage(_prefs.getString(themeOverrideKey));

  @override
  ReaderTextScale readReaderScale() =>
      ReaderTextScale.fromStorage(_prefs.getString(readerScaleKey));

  @override
  Future<void> writeThemeOverride(ThemeOverride value) async {
    // `setString` renvoie un `Future<bool>`. Un `false` est un refus du
    // plateforme, pas une exception : le catcher de `Switch` ne verrait jamais
    // l'échec si on l'ignorait, et l'interface afficherait « nuit » alors que rien
    // n'est écrit. B24 : l'échec doit être **visible**.
    final ok = await _prefs.setString(themeOverrideKey, value.name);
    if (!ok) {
      throw ThemePersistenceException('themeOverride', value.name, null);
    }
  }

  @override
  Future<void> writeReaderScale(ReaderTextScale value) async {
    final ok = await _prefs.setString(readerScaleKey, value.name);
    if (!ok) {
      throw ThemePersistenceException('readerScale', value.name, null);
    }
  }
}

/// Échec d'écriture d'un réglage d'affichage.
///
/// **Distincte d'`AppException`** et c'est délibéré : `13-error-handling.md`
/// impose « une sous-classe seulement quand un appelant a besoin de
/// `on X catch` ». Celui qui l'attrape est exactement un : l'état `failed` du
/// `Switch` de `design-system.md` § 2.9, qui doit **revenir en arrière** et le
/// dire. Aucun autre appelant n'a de branche à écrire.
final class ThemePersistenceException implements Exception {
  const ThemePersistenceException(this.key, this.value, this.cause);

  final String key;

  /// La valeur **essayée**, pas celle qui est en vigueur — c'est ce que le
  /// lecteur vient de choisir et ce qu'il faut lui nommer.
  final String value;

  final Object? cause;

  @override
  String toString() => 'ThemePersistenceException: $key=$value not written';
}
```

### 2.3 Contrats API

**Aucun appel réseau.** Cette fondation est la seule du projet qui n'en fait jamais,
par construction : elle n'importe rien de `core/network` et n'a aucun chemin vers
une source.

```dart
// Signature, pas implémentation : c'est ce que `0-5` consomme.
class AppTheme {
  static ThemeData day();
  static ThemeData night();
}

/// Signature, pas implémentation : c'est ce que `2-8` consomme.
abstract interface class ReaderScaleController {
  ReaderTextScale current();
  Future<void> select(ReaderTextScale step);
}

/// Signature, pas implémentation : c'est ce que `0-5` consomme pour `themeMode`.
abstract interface class ThemeOverrideController {
  ThemeOverride current();
  Future<void> select(ThemeOverride value);
}
```

---

## 3. Algorithmes critiques

### 3.1 Résolution du thème (couvre **B26**, **E13**)

```
resolveTheme(platformBrightness, override):
  # ⚠️ LE DÉFAUT EST `system`, ET IL EST ABSENT DU STOCKAGE.
  # Une clé absente et une clé valant "system" sont le même état ; on n'écrit
  # jamais "system" pour le signifier. Voir § 7.

  case override:                             # la SEULE traduction, ThemeOverride.resolve
    system -> platformBrightness == dark ? ThemeMode.dark : ThemeMode.light
    day    -> ThemeMode.light
    night  -> ThemeMode.dark

  MaterialApp.router(
    theme:        AppTheme.day(),            # toujours présent
    darkTheme:    AppTheme.night(),          # toujours présent
    themeMode:    <la valeur ci-dessus>,     # passe finally SEULEMENT parce que
                                            #   l'override existe (14-design-tokens.md)
  )

  # Flutter choisit alors theme ou darkTheme par MaterialApp, applique les deux
  # extensions (LumenColors, LumenSpacing, LumenRadius, LumenShadows,
  # LumenMotion, LumenReaderProse) et reconstruit.
```

**Les quatre branches, tous explicites :**

| Situation | Ce qui se passe | Pourquoi c'est correct |
|---|---|---|
| Override `system`, téléphone en clair | `ThemeMode.light`, `AppTheme.day()` | B26 : le téléphone décide |
| Override `system`, téléphone en nuit | `ThemeMode.dark`, `AppTheme.night()` | B26 : le téléphone décide |
| Override `day`, téléphone en nuit | `ThemeMode.light` — **le téléphone a tort, l'app non** | B26 : l'override prime, et il ne change rien au réglage du téléphone |
| Override `night`, téléphone en clair | `ThemeMode.dark` | idem |
| Le téléphone bascule clair/nuit **pendant** la lecture (E13) | Aucun code ne s'exécute : `MaterialApp` rebuild, l'override est relu, l'écran se re-thème **au cadre suivant**. **La position de lecture n'est pas touchée** — elle vit dans `reading_positions.offset`, écrit sur chaque arrêt de défilement, et aucun code de thème n'y touche | E13 : « s'applique immédiatement et la position est préservée ». C'est une propriété de la séparation, pas d'une garde à écrire |
| Clé `app.themeOverride` absente au premier lancement | `system` | B26 : suivre le téléphone est le comportement d'une application fraîche |
| Clé présente mais illisible (`"sombre"`, `"dark"` d'une autre version) | `ThemeOverride.system` | Une version antérieure ne doit pas empêcher le démarrage |
| `setString` renvoie `false` | `ThemePersistenceException`, le `Switch` **revient en arrière** et son état `failed` nomme le réglage | B24 : l'échec est visible. `design-system.md` § 2.9 : « un réglage qu'on ne peut pas enregistrer est un défaut que le lecteur doit voir immédiatement, pas un état à concevoir autour » |

### 3.2 Composition de la taille de texte (couvre **B27**, **E14**)

```
resolveProse(platformScaler, step):
  # B27 a DEUX sources et la règle les compose, elle ne les choisit pas l'une
  # contre l'autre.

  product   = step.fontSize * platformScaler.scale(1)     # ex. xl=23 × 1.30 = 29.9
  size      = product.clamp(16, 40)                       # § 2.2 minProduct/maxProduct
  lineHeight = size * (step.lineHeight / step.fontSize)   # ratio 1.72 RECALCULÉ

  style = TextStyle(
    fontSize: size,
    height:   lineHeight / size,       # 1.72 au ratio, mais la ligne suit `size`
    fontFamilyFallback: [Noto Serif, Roboto Slab, <platform sans>],
    color:    < hérité du thème >,
  )
```

**Chaque branche, avec le résultat chiffré :**

| `step` | Téléphone 100 % | Téléphone 130 % | Téléphone 200 % |
|---|---|---|---|
| `sm` | 16 / 27.5 (plancher) | 20.8 / 35.8 | **32 / 54** (plafond non atteint) |
| `md` (défaut) | 18 / 31 | 23.4 / 40.3 | **36 / 62** |
| `lg` | 20 / 34 | 26 / 44.2 | **40 / 68** (plafond atteint) |
| `xl` | 23 / 39.2 | 29.9 / 51 | **40 / 68** (plafond atteint) |
| `xxl` | 26 / 44.7 | 33.8 / 57.2 | **40 / 68** (plafond atteint) |

**Pourquoi le plafond existe, et c'est le point d'E14 :** sans lui, `xxl` à 200 %
donne 52px dans une colonne de 328dp — environ **douze caractères par ligne**, et un
lecteur qui doit suivre le curseur pour suivre la ligne. Le plafond rend le cas
dégradé au lieu de le laisser se dégrader : au-delà de 40px, l'app cesse de grossir
et c'est le défilement qui prend le relais.

**Trois pièges que ce tableau résout, et qu'il faut avoir à l'esprit :**

- **Le plancher à 16px n'est pas négociable** et il est posé sur le **pas**, pas
  sur le produit. `design-quality.md` § 3 interdit de descendre sous 16px sur
  mobile ; E14 interdit le rognage à la plus grande taille. Les deux sont
  satisfaits **simultanément** parce que le pas le plus petit *est* 16px et que le
  plancher ne peut donc jamais mordre en dessous.
- **Le ratio doit être recalculé, pas recopié.** Écrire `height: 1.72` tel quel
  donnerait à `xxl` (26px) un interligne de 44.7px, correct, mais à 40px un
  interligne de 68.8px… ce qui est en fait correct aussi. Le piège réel est
  l'inverse : copier `step.lineHeight` **en pixels** (44) sur une taille
  recalculée de 40donne 1.10 — des lignes **qui se chevauchent**. C'est exactement
  ce qu'E14 interdit. D'où le ratio recalculé ci-dessus.
- **Aucune taille de police n'est écrite dans un widget.** `14-design-tokens.md`
  §Typography : « pas d'override de `fontSize` par widget sauf nécessité réelle ».
  La prose est un style ; les slots Material 3 portent le chrome.

### 3.3 Les deux palettes ne sont pas l'une l'inverse de l'autre (ADR-016)

```
Constat, par jeton, mesuré par le design system § 1.1 :

  jeton               jour        nuit       écart       pourquoi
  background       #F5F2ED     #121315     non inversion   papier chaud → encre froide
  surface          #FBF9F6     #1A1C1F
  textPrimary      #1A1714     #E8E4DD     **inversé en teinte**  noir chaud → blanc chaud
  accent           #8A4B12     #E3A857     **inversé en clarté** brun brûlé → or clair
  error            #8A3228     #EE8B76     **INVERSÉ**      brique désaturée → rouge clair
  warning          #8A5A12     #E0AC47     **INVERSÉ**
  success          #40713A     #7FBE72     **INVERSÉ**
  info             #426986     #7FB3DA     **INVERSÉ**

  Conséquence opérationnelle, et c'est elle qui justifie ADR-016 :
  un seul `error` ne peut pas servir les deux thèmes.
    #8A3228 sur #F5F2ED → 7.32:1
    #8A3228 sur #121315 → 2.27:1          ← illisible
  Chaque couleur sémantique est donc spécifiée DEUX fois. C'est le seul endroit
  du design system où « un jeton, deux valeurs » n'est pas une commodité : c'est
  la différence entre un message d'erreur lisible et un message invisible.
```

**La branche que l'implémentation doit Interpréter littéralement :** `LumenColors.night()` n'est **pas**
`LumenColors.day().lerp(null, 1)` et n'est pas non plus `copyWith(background: …)`
sur les quatre surfaces. Les seize valeurs sont écrites, et `LumenColors.night()`
est une constante comme `day()` l'est. Un test les compare champ par champ contre
les colonnes `Day` / `Night` de § 1.1, parce que la seule façon d'introduire une
troième valeur par accident est d'écrire l'une en fonction de l'autre.

### 3.4 `ColorScheme.fromSeed` : ce qu'on lui laisse faire

`14-design-tokens.md` exige Material 3 avec `ColorScheme.fromSeed`. La nuance, et
elle est structurante :

```
ColorScheme.fromSeed(seedColor: accentDay):
  → fournit   primary, onPrimary, secondary, surface, surfaceContainer…,
              outline, outlineVariant          (les RÔLES Material 3)
  → NE FOURNIT PAS.error, warning, info, success

donc:
  ColorScheme.error           ← DOIT venir de LumenColors, pas du seed
  Les conteneurs de surface   ← DOIVENT venir de LumenColors (surfaceRaised /
                                 surfaceSunken n'existent pas comme rôles Flutter)
  Les couleurs de bordure     ← borderField, borderFocus, borderStrong : ce sont
                                 des composants, pas des rôles
```

`error` est le test décisif : `ColorScheme.fromSeed` le dériverait de l'ambre et
produirait un rouge orangé — précisément la collision avec l'accent que § 0.3 de
`design-system.md` refuse (« il n'entre jamais en collision avec `error` »).

---

## 4. Plan composants

### 4.1 Arbre de composants

```
Aucun composant d'interface. Cette fondation produit des valeurs, pas des widgets.

app/theme/
├── lumen_colors.dart       LumenColors (ThemeExtension) + day() + night()
├── lumen_spacing.dart      LumenSpacing (ThemeExtension)
├── lumen_radius.dart       LumenRadius (ThemeExtension) + borderWidth + none
├── shadows.dart            LumenShadows (ThemeExtension)
├── motion.dart             LumenMotion (ThemeExtension) + reduced-motion
├── reader_scale.dart       ReaderTextScale + LumenReaderProse (ThemeExtension)
├── theme_override.dart     ThemeOverride + resolve(Brightness)
├── app_theme_preferences.dart   AppThemePreferences + SharedPrefsThemePreferences
│                              + ThemePersistenceException
└── app_theme.dart          AppTheme.day() / AppTheme.night()
```

### 4.2 Composants

| Composant | Type | Fichier cible | Props | State | Événements |
|---|---|---|---|---|---|
| `LumenColors` | `ThemeExtension` | `lib/app/theme/lumen_colors.dart` | 16 `Color` requis | aucun | — |
| `LumenSpacing` | `ThemeExtension` | `lib/app/theme/lumen_spacing.dart` | 8 `double` | aucun | — |
| `LumenRadius` | `ThemeExtension` | `lib/app/theme/lumen_radius.dart` | 4 `double` + 2 `const` statiques | aucun | — |
| `LumenShadows` | `ThemeExtension` | `lib/app/theme/shadows.dart` | 2 `List<BoxShadow>` | aucun | — |
| `LumenMotion` | `ThemeExtension` | `lib/app/theme/motion.dart` | 3 `Duration` + 3 `Curve` + `reduced` | aucun | — |
| `ReaderTextScale` | `enum` | `lib/app/theme/reader_scale.dart` | `fontSize`, `lineHeight`, `index` | aucun | — |
| `LumenReaderProse` | `ThemeExtension` | idem | `familyFallback` | aucun | — |
| `ThemeOverride` | `enum` | `lib/app/theme/theme_override.dart` | `resolve(Brightness)` | aucun | — |
| `AppThemePreferences` | interface Dart | `lib/app/theme/app_theme_preferences.dart` | — | aucun | — |
| `SharedPrefsThemePreferences` | implémentation | idem | `SharedPreferences` | aucun | — |
| `ThemePersistenceException` | exception typée | idem | `key`, `value`, `cause` | — | — |
| `AppTheme` | assemblage | `lib/app/theme/app_theme.dart` | — | aucun | — |

**Riverpod** (`05-state-management.md`) : **deux providers, tous deux `keepAlive`**,
et c'est le cas nommé de la règle 10 — « préférences d'application ». Un
préférence qui se détruirait en sortant d'un écran reviendrait à `md` au retour, ce
qui est exactement la régression que B27 interdit.

```dart
// lib/app/theme/theme_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen_tale/app/theme/app_theme_preferences.dart';
import 'package:lumen_tale/app/theme/reader_scale.dart';
import 'package:lumen_tale/app/theme/theme_override.dart';

/// `05-state-management.md` règle 8 : une interface de préférences EST un provider.
/// `SharedPreferences.getInstance()` a déjà été résolu au bootstrap, donc la
/// lecture est synchrone et l'état n'est jamais `loading`.
final appThemePreferencesProvider = Provider<AppThemePreferences>(
  (ref) => throw UnimplementedError('overridé au bootstrap — 0-5'),
);

/// B26. `keepAlive` : une préférence d'application (règle 10).
final themeOverrideProvider =
    NotifierProvider<ThemeOverrideNotifier, ThemeOverride>(
  ThemeOverrideNotifier.new,
);

class ThemeOverrideNotifier extends Notifier<ThemeOverride> {
  @override
  ThemeOverride build() =>
      ref.read(appThemePreferencesProvider).readThemeOverride();

  /// B24 + `design-system.md` § 2.9 : en cas d'échec d'écriture l'état **ne**
  /// change pas et l'exception remonte, pour que l'appelant fasse revenir son
  /// contrôle en arrière et dise pourquoi.
  Future<void> select(ThemeOverride value) async {
    final prefs = ref.read(appThemePreferencesProvider);
    await prefs.writeThemeOverride(value); // lève avant toute mutation d'état
    state = value;
  }
}

/// B27. Même durée de vie, même raison.
final readerTextScaleProvider =
    NotifierProvider<ReaderTextScaleNotifier, ReaderTextScale>(
  ReaderTextScaleNotifier.new,
);

class ReaderTextScaleNotifier extends Notifier<ReaderTextScale> {
  @override
  ReaderTextScale build() =>
      ref.read(appThemePreferencesProvider).readReaderScale();

  Future<void> select(ReaderTextScale step) async {
    final prefs = ref.read(appThemePreferencesProvider);
    await prefs.writeReaderScale(step); // idem : écrire PUIS muter
    state = step;
  }
}
```

> **Note d'implémentation.** Les deux écritures ci-dessus sont écrites à la main
> pour rester lisibles dans ce plan. `05-state-management.md` règle 1 impose
> `@riverpod` **dès que le codegen s'applique**, ce qui est le cas ici : la
> version finale utilise `@Riverpod(keepAlive: true) class ThemeOverrideNotifier
> extends _$ThemeOverrideNotifier`, et `dart run build_runner build` (sans option).
> **La forme exacte de l'annotation est à lire dans `riverpod_generator` 4.0.9
> installé**, pas de mémoire : `AGENTS.md` § Outilchain vérifié l'impose, et la
> signature de `Notifier` a changé entre les versions 2.x et 3.x de Riverpod.

### 4.3 États par écran

**Aucun écran n'est produit, et aucun écran existant n'est modifié.** C'est une
fondation : elle ne dessine rien. `0-5` (la coquille) et `2-8` (les commandes du
lecteur) sont ses seuls consommateurs de code, et `0-5` n'existe pas encore.

Ce qui remplace un tableau d'états, c'est le tableau des **états de résolution**,
parce que c'est ce que chaque écran consomme sans le savoir :

| État de résolution | Ce que produit la fondation | Ce que chaque écran en fait |
|---|---|---|
| Thème jour, `themeMode: ThemeMode.light` | `LumenColors.day()`, `LumenSpacing`, `LumenRadius`, `LumenShadows`, `LumenMotion`, `LumenReaderProse` enregistrés sur `ThemeData` | `AppScaffold` pose son `titleBar`, ses `bottomNav`, `persistentStatus` ; chaque écran lit `LumenColors.of(context)` et rien d'autre |
| Thème nuit | `LumenColors.night()`, les mêmes cinq extensions | **Le même arbre de widgets.** Une différence de rendu entre jour et nuit qui modifierait l'arbre serait un bug : le thème remplace des couleurs, pas des widgets |
| Réduction des animations du système | `LumenMotion.duration(context, base) → Duration.zero` | Une application de lecture qui anime une restauration que le lecteur n'a pas demandée est pire que celle qui ne l'anime pas |
| Pas de lecture `sm` | `styleFor(sm, scaler)` à `16 / 27.5` | La prose est au plancher de `design-quality.md` § 3 |
| Pas de lecture `xxl`, téléphone 200 % | `styleFor(xxl, 2.0)` plafonné à `40 / 68` | La colonne se re-divise ; le défilement prend le relais (§ 3.2) |
| Clé d'override absente | `system` / `md` | Premier lancement : l'app suit le téléphone, qui est le comportement par défaut de toute application |
| Clé d'override illisible | `system` / `md` | Idem, et l'app démarre quand même |
| Écriture refusée par la plateforme | `ThemePersistenceException` | `Switch` (§ 2.9) : retour arrière immédiat, ligne en `--color-error`, **le texte de l'échec à côté du contrôle et jamais en le teintant** |

### 4.4 Formulaires

Aucun. Aucun champ de saisie n'existe ici. Les deux écrans qui modifient ces
réglages (`settings-reader.md`) utilisent `SettingsChoiceSheet`, déclarée au design
system § 2.12 — et **pas** `SettingsSwitchRow`, dont `design-system.md` § 2.12
enregistre honnêtement le statut « déclaré, inutilisé » : B32 et B33 rendent la
suppression par chapitre explicite, donc le commutateur « supprimer après lecture »
a été coupé, et B35 ayant été retiré (ADR-023) il ne reste plus un seul
commutateur à lui porter.

---

## 5. Gestion d'état (state management)

| Donnée | Portée | Stockage | Initialisation | Mise à jour |
|---|---|---|---|---|
| `ThemeOverride` | application | `shared_preferences['app.themeOverride']`, absent = `system` | `ThemeOverrideNotifier.build()` | `select()` : **écrire, puis muter** |
| `ReaderTextScale` | application | `shared_preferences['reader.textScale']`, absent = `md` | `ReaderTextScaleNotifier.build()` | `select()` : **écrire, puis muter** |
| `platformBrightness` | application | le téléphone | `MediaQuery` | **jamais écrit** — c'est la entrée, pas l'état |
| `textScaler` | application | le téléphone | `MediaQuery` | **jamais écrit** |
| `disableAnimations` | application | le téléphone | `MediaQuery` | **jamais écrit** |
| 16 couleurs, 8 espacements, 5 rayons, 2 ombres, 6 durées | application | `const` dans le code | `AppTheme.day()` / `night()` | **jamais écrit** — une valeur de thème modifiée à l'exécution est une valeur de thème qui ment |

**Ce qui n'est délibérément pas de l'état** : la couleur effective d'un widget. Elle
se lit dans le thème à chaque build ; la mettre en cache créerait une seconde
source de vérité qui survit au changement de thème et rendrait la première frame
après le basculement fausse.

**Ordre d'écriture, et il est le même que celui de B6** — c'est le seul endroit où
les deux coïncident, et la coïncidence est le modèle : *validate → écrire → puis
muter*. Une interface qui mute avant d'écrire affiche un réglage qu'elle ne peut pas
garder ; `2-5`'s dialog de suppression et `3-3`'s dialogue de téléchargement ont la
même contrainte et la même raison (C8 : la perte de données est structurellement
acceptée).

---

## 6. Traçabilité des règles

> `state.json` → `foundations['theme-type'].rule_ids` = **`B26`, `B27`**, et
> **aucun `edge_case_ids`** (F-003 : une fondation n'est jamais vérifiée
> mécaniquement, donc ces identifiants sont lus, pas contrôlés). Les edge cases et
> les contraintes listés ci-dessous sont **ce que le design system et les écrans
> imposent** en plus, et ils sont tracés pour ne pas être perdus.

### 6.1 Règles métier (B*)

| ID | Règle (PRD, texte intégral) | Implémentée où | Approche |
|---|---|---|---|
| **B26** | *« The app follows the phone's light/dark setting, and the user may override light/dark inside the app without changing the phone's setting. »* | `ThemeOverride` + `ThemeOverrideNotifier` § 3.1 | Trois valeurs : `system` (défaut, la clé est **absente**), `day`, `night`. `ThemeOverride.resolve(Brightness)` est **le seul** endroit du projet qui traduit l'override en `ThemeMode`. Un override prime sur le téléphone et ne le modifie pas : les deux `ThemeData` sont toujours fournis, donc basculer le téléphone sous un override forcé ne fait rien |
| **B27** | *« The reader follows the phone's font-size setting, and the user may adjust the text size inside the app; the in-app choice survives closing the app. »* | `ReaderTextScale` + `LumenReaderProse.styleFor` § 3.2 | **Deux sources composées, pas choisies** : `step.fontSize × platformScaler`, borné à `[16, 40]`. L'in-app est un `enum` de cinq valeurs persistées dans `shared_preferences` ; « survives closing the app » est une propriété de la clé, pas une fonction de session. `2-7` possède la mesure et le recalcul de la colonne ; `2-8` possède le contrôle qui écrit cet enum — la frontière est nommée pour qu'elle ne soit pas implémentée deux fois |

### 6.2 Edge cases (E*)

| ID | Cas (PRD) | Approche de gestion | Où |
|---|---|---|---|
| **E13** | Le mode clair/sombre change **pendant** la lecture : *« The change applies immediately and the reading position is preserved (B26) »* | **Aucune ligne de code n'est nécessaire, et c'est le but.** `MaterialApp` rebuild sur `MediaQuery` ; l'override est relu ; l'arbre de widgets est **identique** — seul `LumenColors` change. La position vit dans `reading_positions.offset`, écrite à chaque arrêt de défilement ; **aucun code de thème n'y touche**, donc elle ne peut pas bouger | § 3.1 |
| **E14** | La taille de police change **pendant** la lecture : *« The reader's text resizes immediately, no text is clipped or overlapped, and the reading position is preserved (B27) »* | Trois éléments : (1) le `TextScaler` du téléphone est lu à chaque build, donc le redimensionnement est au cadre suivant ; (2) le ratio d'interligne est **recalculé** depuis `size` et non recopié en pixels, sinon deux lignes se chevauchent — ce qu'E14 nomme ; (3) le produit est borné à `[16, 40]`, donc `xxl` à 200 % cesse de grossir au lieu de devenir illisible. La position n'est pas touchée, même raison qu'E13 | § 3.2 |

### 6.3 Contraintes (C*)

| ID | Contrainte (PRD) | Comment elle est respectée |
|---|---|---|
| **C3** | *« Platform — Android phones only. … No iOS, no tablet layout, no desktop, no web. »* | Aucun breakpoint, aucun `MediaQuery.size.width` dans cette fondation. `design-system.md` § 1.7 déclare `< 600dp` **le seul layout que v1 livre** ; cette fondation ne connaît que le téléphone. `ADR-019` : au-delà de 600dp le layout cesse de grossir et se centre — ce qui est le comportement par défaut d'un `Scaffold`, donc il n'y a rien à écrire |
| **C11** | *« Usage context — reading happens one-handed, on a phone, at night or in transit, frequently with poor or no connectivity »* | La raison d'être du thème nuit : `design-system.md` § 0.1 argumente que le texte chaud sur un champ chaud crée de la diffusion à basse luminosité, ce qui est précisément la condition où le lecteur baisse la luminosité — donc la nuit est un champ **froid**. `--reader-md` 18px et un interligne de 1.72 sont la densité « airy » réservée à la seule surface que le lecteur regarde vingt minutes d'affilée |
| **C13** | *« One device, one reader — … no login, no profiles, no sync. »* | Aucune identité n'est lue ni écrite. Un réglage d'affichage est le seul état « de l'utilisateur » que l'application possède, et il est stocké comme une préférence, pas comme un profil — il n'y a rien à migrer entre deux phones parce qu'il n'y a pas de phone précédent |

### 6.4 Ce que cette fondation ne couvre pas, et qui est ailleurs

| Sujet | Propriétaire | Raison |
|---|---|---|
| Les six libellés de `settings-reader.md` | `localisation` | B28 : toute chaîne visible existe en FR et EN. Cette fondation ne produit que des **valeurs** |
| Les trois boutons de `ReaderControls` et la feuille de choix | `2-8` | `design-system.md` § 2.6 et § 2.12 déclarent les composants ; la slice qui les branche est `2-8` |
| La mesure de la colonne et le non-rognage | `2-7` | Une extension de thème ne peut pas contraindre une largeur ; § 4 de ce plan le dit, `2-7` le fait |
| Le texte de la feuille ARB | `localisation` | `architecture.md` § 2 : « mécanisme seul » |

---

## 7. Pièges à éviter

- **⚠️ Ne pas dériver `LumenColors.night()` de `LumenColors.day()`.** Le
  comportement correct (**ADR-016**) est : **seize constantes écrites**, dans deux
  `factory` distinctes. Une nuit dérivée (« tout inversé ») produirait un `error`
  `#8A3228` sur un champ `#121315` — **2.27:1**, donc invisible. C'est la mesure que
  `design-system.md` § 1.1 donne, et elle est la raison pour laquelle chaque couleur
  sémantique est spécifiée deux fois.
- **⚠️ Ne pas passer `themeMode: ThemeMode.system` en dur.** Le comportement
  correct (**B26**, `14-design-tokens.md`) est : ne passer `themeMode` à
  `MaterialApp.router` **que** parce qu'un override existe, et passer la valeur de
  `ThemeOverride.resolve(platformBrightness)`. Un `themeMode` littéral est
  redondant — `avoid_redundant_argument_values` le signale — et il rend l'override
  inerte.
- **⚠️ Ne pas prendre `ColorScheme.error` dans la seed Material 3.** Le
  comportement correct (`design-system.md` § 0.3) est : `ColorScheme.fromSeed` fournit
  les **rôles** Material 3 ; `error`, `warning`, `info`, `success`, `surfaceRaised`,
  `surfaceSunken`, `borderField`, `borderFocus` et `borderStrong` viennent de
  `LumenColors`. La seed dérive `error` de l'ambre et produit un rouge orangé, qui
  est exactement la collision avec l'accent que le design system refuse.
- **⚠️ Ne pas embarquer une face de lecture dans `assets/`.** Le comportement
  correct (**ADR-017**) est : la chaîne de préférence `Noto Serif` → `Roboto Slab` →
  sérif de la plateforme, avec la sans de la plateforme en repli. Embarquer une face
  variable ajoute du poids à l'APK pour une question de marque qu'aucune règle ne
  pose. Une face de lecture est candidate **v2**, et seulement si la chaîne se
  révèle insatisfaisante.
- **⚠️ Ne pas écrire un `fontSize` dans un widget de lecteur.** Le comportement
  correct (**B27**, `14-design-tokens.md` § Typography) est : la prose lit
  `LumenReaderProse.styleFor(step, platformScaler)`. Un `fontSize` par widget est
  exactement ce qui a déjà été supprimé de Mihon, et il rend l'échelle du téléphone
  inopérante sur cet écran.
- **⚠️ Ne pas muter l'état avant d'avoir écrit.** Le comportement correct (**B24**,
  `design-system.md` § 2.9) est : `await prefs.write…()` **puis** `state = …`. Un
  réglage affiché que l'application ne peut pas garder est un mensonge, et
  `shared_preferences` refuse parfois (`setString` renvoie `false` **sans lever**).
  L'état `failed` du `Switch` existe pour ce cas : retour arrière immédiat, et le
  motif **à côté** du contrôle, jamais en le teintant.
- **⚠️ Ne pas écrire un `default` dans `shared_preferences` au premier
  démarrage.** Le comportement correct (**B26**, **B27**) est : la clé est
  **absente**, et l'absence se résout en `system` / `md`. Écrire la valeur par
  défaut crée trois sources de vérité — le fichier, l'absence de clé et l'`enum` —
  et « absent » cesse de signifier « jamais choisi ».
- **⚠️ Ne pas mettre cette fondation dans `core/theme/`.** Le comportement correct
  (`14-design-tokens.md` § *One location*) est : **`lib/app/theme/`**. `app/`
  possède l'assemblage du thème parce que le thème est une préoccupation de
  présentation qu'aucune couche inférieure n'a le droit d'importer. C'est aussi la
  seule raison pour laquelle `0-5` peut câbler `MaterialApp.router` sans que
  `core/` connaisse le thème.
- **⚠️ Ne pas comparer une durée à `Duration.zero` dans un écran.** Le
  comportement correct (**`design-system.md` § 1.6**) est :
  `LumenMotion.of(context).duration(context, LumenMotionDuration.normal)`. La
  comparaison locale oublie le réglage système, et l'effet est une révélation de
  chrome animée malgré « réduire les animations ».

---

## 8. Dépendances

| Dépend de | Nature | Statut | Fallback si absent |
|---|---|---|---|
| — | — | — | **Aucune dépendance.** C'est une fondation de vague 0 (`architecture.md` § 6.1) et son ensemble de prédécesseurs est vide |

**Dépendants** (ne font rien tant que cette slice n'est pas là) :

| Slice | Ce qu'elle attend |
|---|---|
| `0-5` | `AppTheme.day()`, `AppTheme.night()`, les deux providers, et `themeMode` dans `MaterialApp.router` |
| `2-8` | `ReaderTextScale` + le contrôle qui écrit l'`enum`, pour les cinq pas du lecteur |
| `2-7` | `LumenReaderProse.styleFor` — la composition § 3.2, qu'il consomme sans la réimplémenter |
| tous les écrans | `LumenColors.of(context)` et les cinq autres extensions |

---

## 9. Checklist de tâches

### Phase 1 — Couche de données

- [ ] Créer `lib/app/theme/lumen_colors.dart` : `LumenColors`, `day()`, `night()`, `copyWith`, `lerp`, `==`, `hashCode` (§ 2.2)
- [ ] Créer `lib/app/theme/lumen_spacing.dart`, `lumen_radius.dart`, `shadows.dart`, `motion.dart` (§ 2.2)
- [ ] Créer `lib/app/theme/reader_scale.dart` : `ReaderTextScale`, `LumenReaderProse.styleFor` (§ 2.2)
- [ ] Créer `lib/app/theme/theme_override.dart` : `ThemeOverride` + `resolve` (§ 2.2)
- [ ] **Aucun schéma de base** : deux clés de `shared_preferences`, deux chaînes
- [ ] Aucun appel API : cette fondation n'a aucun chemin vers le réseau

### Phase 2 — Logique métier

- [ ] `AppThemePreferences` + `SharedPrefsThemePreferences` + `ThemePersistenceException` (§ 2.2)
- [ ] `ThemeOverride.resolve` — l'unique traduction vers `ThemeMode` (§ 3.1)
- [ ] `ReaderTextScale.fromStorage` + `ThemeOverride.fromStorage` — repli silencieux sur la valeur par défaut
- [ ] `LumenReaderProse.styleFor` — produit borné `[16, 40]`, ratio recalculé (§ 3.2)
- [ ] Les deux providers `keepAlive`, dans `theme_providers.dart` (§ 4.2)
- [ ] Réécrire ces deux providers en `@Riverpod(keepAlive: true)` et lancer `dart run build_runner build` — **sans option** ; `--delete-conflicting-outputs` a été retiré et est ignoré silencieusement

### Phase 3 — Interface utilisateur

- [ ] **Aucun, et c'est délibéré.** Une fondation ne dessine rien : elle produit des valeurs consommées par `0-5` et `2-8`, qui n'existent pas encore. Créer un écran ici serait du travail sans consommateur, et le `settings-reader.md` existe déjà pour porter les contrôles. **Ne pas créer d'« écran de thème » par souci de complétude.**

### Phase 4 — Intégration

- [ ] `AppTheme.day()` / `AppTheme.night()` : `ColorScheme` depuis `ColorScheme.fromSeed`, **`ColorScheme.error` remplacé par `LumenColors.error`**, et les six extensions enregistrées sur **les deux** `ThemeData` (§ 4.2)
- [ ] Vérifier qu'aucun `MediaQuery.size.width` n'apparaît dans `app/theme/` — cette fondation ne connaît pas le breakpoint (ADR-019)
- [ ] `shadowTheme` pour que `LumenShadows.sheet` soit appliqué aux feuilles — `design-system.md` § 1.4 n'autorise **que deux** ombres dans toute l'application
- [ ] Aucun routage : `themeMode` est passé par `0-5`, pas ici

### Phase 5 — Tests et polish

- [ ] Tests unitaires (§ 11.1) — **y compris le test « nuit ≠ inverse de jour »**, qui est la moitié d'ADR-016
- [ ] Tests de composants (§ 11.2) : les deux extrêmes de l'échelle, à 360dp
- [ ] `dart format .`, `flutter analyze` zéro issue, `flutter test` vert

### Vérifications finales

- [ ] `dart format .` — propre
- [ ] `flutter analyze` — **zéro** issue, zéro `info`
- [ ] `flutter test` — tout passe
- [ ] `coverage-check.js slice /workspaces/lumen_tale theme-type` → **ne peut pas s'exécuter** : `theme-type` est une fondation, pas une slice (`README.md` § 2, finding **F-003**). Vérifié par `.forge/plans/check_plans.py theme-type` et par lecture.

---

## 10. Critères d'acceptation

- [ ] **B26** — `ThemeOverride.system` renvoie `ThemeMode.dark` quand la plateforme est en `Brightness.dark` et `ThemeMode.light` quand elle est en `Brightness.light`.
- [ ] **B26** — `ThemeOverride.day` renvoie `ThemeMode.light` **et** `ThemeOverride.night` renvoie `ThemeMode.dark`, quelles que soient les platformBrightness.
- [ ] **B26** — les deux clés sont absentes de `shared_preferences` après un premier lancement complet : rien n'écrit un défaut.
- [ ] **B26** — une clé illisible (`"dark"`, `"sombre"`, chaîne vide) retombe sur `system` **sans lever**.
- [ ] **B26** — les deux `ThemeData` sont toujours fournis à `MaterialApp.router` : un override forcé ne modifie pas le réglage du téléphone.
- [ ] **B26** — les seize valeurs de `LumenColors.night()` sont **écrites littéralement** et ne sont pas dérivées de `day()` : `grep -c 'LumenColors.day' lib/app/theme/lumen_colors.dart` ne trouve **aucune** occurrence dans la factory nuit.
- [ ] **ADR-016** — les quatre couleurs sémantiques (`error`, `warning`, `success`, `info`) ont des valeurs **différentes** en jour et en nuit, et `ColorScheme.error` de la `ThemeData` nuit vaut `#EE8B76` et non la valeur dérivée de la seed.
- [ ] **B27** — `styleFor(ReaderTextScale.md, TextScaler.linear(1.0))` donne `fontSize == 18.0` et `height == 31 / 18`.
- [ ] **B27** — `styleFor(ReaderTextScale.xxl, TextScaler.linear(2.0))` donne `fontSize == 40.0` : **le plafond mord**, et non `52.0`.
- [ ] **B27** — `styleFor(ReaderTextScale.sm, TextScaler.linear(0.5))` donne `fontSize == 16.0` : **le plancher de `design-quality.md` § 3 ne peut pas être franchi**.
- [ ] **B27** — `styleFor(ReaderTextScale.sm, TextScaler.linear(1.0))` donne `fontSize == 16.0` : **aucun des cinq pas n'est sous 16px**, ce qui est ce qui rend E14 et le plancher simultanément satisfiables.
- [ ] **B27** — l'interligne effectif suit toujours `size` : pour les cinq pas et pour trois échelles de téléphone, `height × fontSize == lineHeight × fontSize / step.fontSize` à `1e-9` près. Aucun couple ne produit `height < 1.5`.
- [ ] **B27** — `select()` écrit **puis** mute : injecter un `setString` qui renvoie `false` laisse `readerTextScaleProvider` sur son ancienne valeur **et** lève `ThemePersistenceException`.
- [ ] **E13** — changer `platformBrightness` avec l'override sur `day` ne change pas le `Brightness` résolu ; avec l'override sur `system`, il change.
- [ ] **E14** — `LumenMotion.of(context).duration(context, Duration(milliseconds: 200))` vaut `Duration.zero` sous `MediaQuery.disableAnimations: true`, et `200ms` sinon.
- [ ] **C3** — aucun fichier de `lib/app/theme/` ne référence `MediaQuery.sizeOf`, `MediaQuery.of(context).size` ni un breakpoint de `design-system.md` § 1.7.
- [ ] `flutter analyze` rapporte **zéro** issue, y compris zéro `info` — un `MediaQuery` lu dans un `build` d'extension serait signalé.

---

## 11. Plan de tests

### 11.1 Tests unitaires

Emplacement : `test/app/theme/lumen_colors_test.dart`

| Cible | Scénarios | IDs couverts |
|---|---|---|
| `LumenColors.day()` | les seize valeurs sont celles de la colonne **Day** de `design-system.md` § 1.1, champ par champ | ADR-016 |
| `LumenColors.night()` | les seize valeurs sont celles de la colonne **Night**, champ par champ | ADR-016 |
| **Nuit ≠ inverse du jour** | `night().error != day().error`, `night().warning != day().warning`, `night().success != day().success`, `night().info != day().info` | ADR-016, § 0.3 de `design-system.md` |
| `lerp` | `day().lerp(night(), 0)` est `day()` ; `lerp(…, 1)` est `night()` ; `lerp(null, 0.5)` ne lève pas | — |
| `==` / `hashCode` | deux `day()` sont égaux et ont le même hachage ; un champ différent casse l'égalité | — |

Emplacement : `test/app/theme/theme_override_test.dart`

| Cible | Scénarios | IDs couverts |
|---|---|---|
| `resolve` — `system` | `dark` → `ThemeMode.dark`, `light` → `ThemeMode.light` | **B26** |
| `resolve` — `day` / `night` | les deux_platformBrightness rendent le même résultat pour `day`, et le même pour `night` | **B26** |
| `fromStorage` | `'system'`, `'day'`, `'night'` reconnues ; `null`, `''`, `'dark'`, `'sombre'` → `system` | **B26** |

Emplacement : `test/app/theme/reader_scale_test.dart`

| Cible | Scénarios | IDs couverts |
|---|---|---|
| `fromIndex` | 0 → `sm`, 4 → `xxl`, `-1` → `sm`, `99` → `xxl` | **B27** |
| `fromStorage` | `'xxl'` → `xxl` ; `'largest'`, `''`, `null` → `md` | **B27** |
| `styleFor` — nominal | les cinq pas à l'échelle 1.0 donnent exactement les couples `(16, 27) (18, 31) (20, 34) (23, 39) (26, 44)` | **B27** |
| `styleFor` — plancher | n'importe quel pas × 0.5 → `16.0` exactement | **B27**, `design-quality.md` § 3 |
| `styleFor` — plafond | n'importe quel pas × 2.0 → `40.0` exactement | **B27**, **E14** |
| `styleFor` — interligne | pour 5 pas × 3 échelles, le ratio effectif reste dans `[1.70, 1.74]` | **E14** |
| `styleFor` — famille | `fontFamilyFallback` contient `'Noto Serif'` en premier et **ne** contient aucun nom de fichier d'asset | ADR-017 |
| `styleFor` — couleur | le `TextStyle` produit n'a **pas** de `color` : il hérite du thème | § 3.3 |

Emplacement : `test/app/theme/app_theme_preferences_test.dart`

| Cible | Scénarios | IDs couverts |
|---|---|---|
| lecture par défaut | sur un `SharedPreferences` vide, `readThemeOverride()` → `system` et `readReaderScale()` → `md`, et **aucune clé n'a été créée** | **B26**, **B27** |
| écriture nominale | `writeReaderScale(xxl)` puis relecture → `xxl` ; la clé contient la **chaîne** `'xxl'`, pas l'ordinal `4` | **B27** |
| **écriture refusée** | `setString` renvoie `false` → `ThemePersistenceException` levée, clé inchangée | **B24** |
| valeurs invalides | `'largest'`, `'night'` dans la clé d'échelle, `'system'` dans la clé de thème → repli sur le défaut, **aucune exception** | **B26**, **B27** |

Emplacement : `test/app/theme/theme_providers_test.dart`

| Cible | Scénarios | IDs Couverts |
|---|---|---|
| durée de vie | après `container.read(readerTextScaleProvider)`, le `ProviderContainer` se ferme et se rouvre : la valeur est **toujours** celle écrite, pas `md` | **B27**, `05-state-management.md` règle 10 |
| échec d'écriture | `select()` avec un `setString` en `false` → exception levée **et** état inchangé | **B24** |
| ordre write-then-mutate | le `setString` en `false` laisse `state` à l'ancienne valeur : il n'y a aucun instant où l'interface affiche une valeur non enregistrée | `design-system.md` § 2.9 |

### 11.2 Tests de composants

Emplacement : `test/app/theme/reader_scale_widget_test.dart`

| Cible | Scénarios | IDs couverts |
|---|---|---|
| plancher de rendu | à l'échelle système `0.5`, le texte rendu mesure 16px : **aucun des deux ne peut échouer** | **B27** |
| plafond de rendu | à l'échelle système `2.0` et pas `xxl`, le texte rendu mesure 40px et **ne déborde pas** la largeur disponible | **B27**, **E14** |
| réduction des animations | sous `MediaQuery(disableAnimations: true)`, une révélation de chrome est instantanée | `design-system.md` § 1.6 |
| thème jour / nuit | le **même** arbre de widgets dans les deux thèmes : les deux `Type` sont égaux, seule la couleur diffère | ADR-016 |

### 11.3 Tests d'intégration

| Flow | Scénario | IDs couverts |
|---|---|---|
| `theme-type → 0-5` | l'application démarre, bascule jour/nuit avec le téléphone, et le thème suit | **B26**, E13 |
| `theme-type → 2-8` | choisir `xxl` dans la feuille, fermer l'application, la rouvrir : le pas est `xxl` | **B27** |
| `theme-type → 2-7` | changer la taille du téléphone pendant la lecture : le texte se redimensionne au cadre suivant, sans chevauchement | **E14** |

### 11.4 Tests E2E

Aucun pour cette slice : **Q-008** (un téléphone réel) n'est pas résolu, et un E2E
qui n'a pas pu être exécuté n'est pas un test, c'est un souhait. Ce qui le remplace :
le test d'intégration « `theme-type → 2-8` » ci-dessus, exécuté dans CI.

### 11.5 Vérifications manuelles

**Toutes les vérifications visuelles se font à une seule largeur : 360dp.**
C'est la largeur de conception (`design-system.md` § 1.7 : `< 600dp` est *le seul*
layout que v1 livre) et la seule largeur que les tests de widgets utilisent.

Il n'y a **pas** de « vérifier chaque point de rupture » à faire : `ADR-019` exclut
la tablette, le bureau, le rail et le deux-panne, et `design-system.md` § 1.7 dit ce
qui se passe au-delà de 600dp — la disposition **cesse de grossir et se centre**.
Il n'y a donc rien à vérifier à 600dp, 1024dp ou 1440dp, et les écrire ajouterait une
promesse que le produit ne fait pas.

| Vérification | À 360dp | Résultat attendu |
|---|---|---|
| Débordements horizontaux | `settings-reader.md` à `xxl` + échelle système 200 % | Aucun. Le contrôle est `SettingsChoiceSheet`, les lignes sont un `Wrap`, et le plafond 40px fait le reste |
| Éléments hors écran | idem | Aucun |
| Navigation | sans objet : cette slice ne construit aucun écran | — |
| Lisibilité jour | `--text-primary` sur `--color-background` | 14.48:1 — mesuré par le design system, pas affirme |
| Lisibilité nuit | idem | 12.00:1 |
| Cible tactile | les contrôles que `2-8` branchera dessus | ≥ 48dp — `14-design-tokens.md`, propriétaire unique de l'accessibilité |
| Réduction des animations | « réduire les animations » activé dans les réglages d'accessibilité du système | chrome instantané, squelette sans scintillement |

---

## Checklist de gate

- [x] Sources explicitement référencées (PRD, architecture, design system, écran, rules).
- [x] Chaque ID B*/E*/C* du périmètre apparaît en § 6 — **B26**, **B27**, **E13**, **E14**, **C3**, **C11**, **C13**.
- [x] Les contrats de données (§ 2) sont du **vrai Dart**, avec les imports.
- [x] Les algorithmes (§ 3) sont en pseudocode avec **chaque** branche écrite : les quatre branches de thème, les neuf couples pas × échelle, les deux palettes.
- [x] La checklist de tâches (§ 9) couvre les cinq phases, en signalant explicitement que la Phase 3 est vide et pourquoi.
- [x] Les critères d'acceptation (§ 10) sont **mécaniquement vérifiables**, chacun avec son id.
- [x] Le plan de tests (§ 11) couvre tous les IDs, nomme les fichiers de test, et fixe la largeur à 360dp.
- [x] § 7 énonce chaque piège en **forme contrastive**, avec la règle qu'il viole.
- [x] Vérifié par `.forge/plans/check_plans.py theme-type` — `coverage-check.js slice` **ne peut pas** vérifier une fondation (**F-003**).

**Statut** : `draft` → en attente de validation.