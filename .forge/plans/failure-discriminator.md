---
type: implementation-plan
slice: failure-discriminator
module: core
status: identified
generated_at: 2026-10-02
derived_from:
  - .forge/prd.md
  - .forge/architecture.md
  - .forge/design/design-system.md
  - .forge/design/screens/
conventions_ref: .forge/conventions.md
---

# Plan d'implémentation — failure-discriminator

> Fondation, pas slice de feature. `state.json` ne la range pas dans `slices`,
> donc `coverage-check.js slice` **ne vérifie pas ses `rule_ids`** — c'est le
> finding **F-003**. Les trois règles sont donc tracées à la main en § 6, et
> une relecture humaine les vérifie.
>
> **Ce document décrit *comment implémenter* cette fondation**, de façon qu'un
> implémentateur n'ait rien à décider et n'ait pas à lire le PRD.

---

## Sources

- **PRD** : `.forge/prd.md` — règles **B22**, **B23**, **B24** ; edge cases **E4**, **E5**, **E8**, **E9**, **E18**, **E19**
- **Architecture** : `.forge/architecture.md` — § 2.2 (le contrat à trois états), § 3.1b (la fixture de layout cassé), § 5.1 (le contrat `Source`), § 5.2 (la taxonomie des échecs), ADR-013, ADR-014, ADR-015
- **Design** : `.forge/design/screens/source-unavailable.md` § 2.1 (les sept différences mécaniques), § 4 (les neuf états, dont l'invariant de routage), § 4.1 (le bannissement de chaînes), § 5, § 8 (`causeClass`, `causeEvidence`), `.forge/design/screens/browse-genre.md` § 4 (Load error), `.forge/design/screens/browse-catalogue.md` § 8
- **Design system** : `.forge/design/design-system.md` § 2.7 (`ErrorState` ne doit jamais se lire comme « no results »), § 2.5 (`StatusChip` porte les verdicts)
- **Conventions** : `.forge/conventions.md`
- **Règles projet** : `13-error-handling.md`, `02-architecture.md` (table des dépendances entre couches), `03-source-system.md` règle 5a, `18-external-contracts.md` § FanMTL point 7, `10-testing.md`

---

## 1. Résumé de la slice

`failure-discriminator` produit **un vocabulaire et une fonction pure** qui
tiennent quatre issues séparées, et qui les tiennent séparées *par construction*
plutôt par convention :

| Issue | Type | Ce que le lecteur voit |
|---|---|---|
| **Lu, et il y a des résultats** | `BrowseSucceeded<T>` | la liste |
| **Lu, et le site dit lui-même qu'il n'y a rien** | `BrowseEmpty<T>` | *Aucun résultat* — **pas** une erreur |
| **Le site n'a pas pu être lu** | `BrowseFailed<T>` | *Ce site n'a pas pu être lu*, avec une preuve et un réessai |
| **La page s'est chargée et ne contenait rien de ce qu'on cherche** | `BrowseFailed<T>` — cause `SourceLayoutChanged` | la même chose, avec la preuve `HTTP 200 · 0 élément attendu trouvé` |

C'est **B22**, et B22 est **SC-6** : *« un site cassé est signalé, jamais présenté
comme vide »*. Le PRD qualifie SC-6 de « the single most likely way the app fails
in real use ». Cette fondation est donc la plus porteuse du projet, et
`architecture.md` § 3.1b ajoute le fait qui la rend testable à vie : la fixture
`fanmtl-broken-layout.html` est **fabriquée** par `0-1` — une copie conforme d'une
vraie page capturée dont le conteneur de contenu a été renommé. Elle répond 200,
elle est bien formée, elle n'est pas vide, et le parseur n'y trouve rien.

**Rien de tout cela n'est un écran.** La fondation produit **quatre** fichiers Dart purs —
 `SourceFailure`, `BrowseOutcome`, `ReadAttempt`, `OutcomeDiscriminator` — sans un seul
 import de `package:flutter`, testables sans binding de widget. `FetchResult` n'en est
 pas un : il appartient à `http-client` (vague 0) et cette fondation l'importe
 (§ 2.2, § 8). `source-unavailable.md` — l'écran qui consomme ces quatre issues — est
construit par `3-1`, et **SC-6 ne se démontre qu'à travers cet écran**, jamais à
travers cette fondation.

**User stories couvertes** : US-16, et US-01 / US-03 par leurs chemin d'échec
**Règles métier couvertes** : B22, B23, B24
**Contraintes couvertes** : C6, C7
**Edge cases couverts** : E4, E5, E8, E9, E18, E19

---

## 2. Contrats de données (code)

> Traduction mécanique de `architecture.md` § 2.2 et § 5.2. **Aucun champ
> inventé** : chaque champ d'une classe de cause est celui que la troisième
> colonne de § 5.2 nomme.

### 2.1 Schémas de validation

**Aucun nouveau schéma.** Cette fondation ne touche pas la base : `local-store`
est livrée et `schemaVersion` reste à 1. Les colonnes qu'elle lit
(`novels.lastCheckedAt`, `sources.lastErrorCode`, `sources.lastCheckedAt`,
`queue_items.error_code`) existent déjà.

Le point à noter : `sources.lastErrorCode` est le **seul** endroit où une cause
déjà vue est conservée, et `queue_items.error_code` le second. Ce sont des
`TEXT` qui stockent **le nom du cas** (`source_layout_changed`), jamais une
phrase — parce que la plateforme n'interprète jamais les valeurs d'une source
(B41), et cela vaut aussi pour les échecs (`architecture.md` § 5.2, ligne
« Prohibited »).

### 2.2 Types et interfaces

**Ordre des couches, et pourquoi il est celui-là.** `core/error` et
`core/network` **n'importent rien** de `lib/`. Le classifieur vit dans
`domain/sources`, qui a le droit d'importer `core`. Aucun cycle, aucune
exception à la table des dépendances de `02-architecture.md`.

```dart
// lib/core/error/source_failure.dart
//
// architecture.md § 5.2 : « core/error — one type per cause, each with its
// recovery. B22 needs causes distinguished, not collapsed. »
//
// Une cause ne porte JAMAIS de phrase. Elle porte les faits dont l'écran a
// besoin pour écrire la ligne de preuve (source-unavailable.md § 8,
// `causeEvidence`), et c'est l'écran qui la traduit (B28). Un `String` de
// diagnostic ici serait exactement le « errorCode free-text field the platform
// interprets » qu'§ 5.2 interdit.

/// A typed cause of a read failure.
///
/// B22 needs causes distinguished, not collapsed: three of the four have no
/// retry worth offering, one has nothing wrong with it at all.
sealed class SourceFailure {
  const SourceFailure();

  /// Whether a second identical request is worth making.
///
/// **Derives from the type, and the type is the only place it is written.**
/// `BrowseFailed` carries a `retriable` field as well, and the two must agree —
/// see § 3.4 and the test `retriable is always the cause's own answer`.
  bool get isRetriable;
}

/// `architecture.md` § 5.2 : « NoConnection | — | later, on its own ».
/// E5. Carries the host only — **never** a full URL, which would put a
/// reader-supplied path in an error surface (C5, 17-security.md).
final class NoConnection extends SourceFailure {
  const NoConnection({required this.host});

  /// The hostname the transport failed against, e.g. `www.fanmtl.com`.
  /// Never a path, never a query, never a query string the reader typed.
  final String host;

  @override
  bool get isRetriable => true;
}

/// `architecture.md` § 5.2 : « RateLimited(retryAfter) | duration |
/// after Retry-After | wait ». `17-security.md` règle 6.
final class RateLimited extends SourceFailure {
  const RateLimited({required this.retryAfter});

  final Duration retryAfter;

  @override
  bool get isRetriable => true;
}

/// `architecture.md` § 5.2 : « SourceLayoutChanged | selector that failed |
/// no | nothing — report the bug ». **E4, E8, SC-6.**
///
/// This is the cause that exists because of `0-1`'s manufactured fixture: a
/// page that returned 200, parsed cleanly, and held none of the elements the
/// app looks for.
final class SourceLayoutChanged extends SourceFailure {
  const SourceLayoutChanged({
    required this.failedSelector,
    required this.status,
    this.siteSuppliedSignal,
  });

  /// The source's own selector, verbatim, so the owner can read the fixture and
  /// see which one came back empty. Never an exception string.
  final String failedSelector;

  /// The HTTP status of the response that was read. Always present here: this
  /// cause requires a response that actually arrived.
  final int status;

  /// The site's own explicit empty-result marker, **when the page carried one
  /// and it was not the selector the source expected to match**. This is how
  /// SC-6 becomes *demonstrable* rather than asserted: the reason the page was
  /// read as broken is that the site said so in its own words, and that string
  /// is kept instead of being discarded.
  final String? siteSuppliedSignal;

  @override
  bool get isRetriable => false;
}

/// `architecture.md` § 5.2 : « SourceUnavailable | status | later | back off ».
/// Also the class an anti-bot challenge is reported as — ADR-014: this app does
/// not attempt to get past one, and `source-unavailable.md` § 5 requires the
/// challenge to be named rather than hidden.
final class SourceUnavailable extends SourceFailure {
  const SourceUnavailable({required this.status, this.isChallenge = false});

  final int status;

  /// True when the body was an interactive anti-bot challenge rather than a
  /// refusal or an outage.
  final bool isChallenge;

  @override
  bool get isRetriable => true;
}

/// `architecture.md` § 5.2 : « ItemRemovedAtSource | which item | no |
/// go back; the rest is unaffected ». **E9.**
///
/// `source-unavailable.md` § 2.1: for this cause there is **no retry button at
/// all**, because the site answered and confirmed the title is gone.
final class ItemRemovedAtSource extends SourceFailure {
  const ItemRemovedAtSource({required this.itemId, required this.status});

  /// The app's own id for the item — a novel id, never a site URL.
  final String itemId;

  final int status;

  @override
  bool get isRetriable => false;
}

/// `architecture.md` § 5.2 : « ParseFailed | file path | no | report the bug ».
/// B22's third arm: "a parse error … → the site could not be read".
final class ParseFailed extends SourceFailure {
  const ParseFailed({required this.path});

  /// The path the parse failed on: a site-relative request path while reading
  /// a source, a support-relative file path while reading a stored chapter.
  /// Never an absolute path, never a content string.
  final String path;

  @override
  bool get isRetriable => false;
}
```

```dart
// ⚠️ `lib/core/network/fetch_result.dart` n'est **PAS** écrit par cette
//    fondation, et le fichier n'est pas créé.
//
// Il appartient à `http-client` — vague **0** — qui le définit en § 2.2 avec
// exactement les mêmes trois cas : `FetchSucceeded(status)`,
// `FetchTransportFailed(host)`, `FetchRateLimited(retryAfter, status)` sur la
// base scellée `FetchResult`.
//
// ⚠️ Un 4xx ou un 5xx n'y est TOUJOURS PAS un cas distinct : il arrive en
//    `FetchSucceeded` avec son statut, et c'est le classifieur qui décide.
//    Décider « ceci est un refus » au transport mettrait la taxonomie en deux
//    endroits.
//
// Cette fondation **l'importe** — `import
// 'package:lumen_tale/core/network/fetch_result.dart';` — et n'y ajoute aucun
// champ. C'est la seule façon que la dépendance tourne dans le bon sens :
// `state.json` déclare `failure-discriminator.depends_on = ['0-1', '0-2',
// 'http-client']`, donc le producteur est vague 0 et le consommateur vague 2. Un
// producteur qui importerait son propre consommateur aurait un cycle.
```

```dart
// lib/domain/sources/browse_outcome.dart
//
// architecture.md § 2.2, verbatim. **Nothing in this project returns a bare
// list from a read, and nothing returns null.** B22 is the rule; this type is
// its expression in the type system, so an empty result and a failure cannot be
// written the same way.

/// The outcome of reading a page from a site. Three states, never two.
sealed class BrowseOutcome<T> {
  const BrowseOutcome();
}

/// The site was read successfully. `items` may legitimately be empty.
final class BrowseSucceeded<T> extends BrowseOutcome<T> {
  const BrowseSucceeded(this.items);

  /// Unmodifiable by contract: an outcome is a value, and a caller that
  /// mutates one has turned a read into an edit. `List.unmodifiable` at every
  /// construction site.
  final List<T> items;
}

/// The site could not be read. `reason` is typed, never a bare string (B24).
final class BrowseFailed<T> extends BrowseOutcome<T> {
  const BrowseFailed(this.reason, {required this.retriable});

  final SourceFailure reason;

  /// B24 — "together with a way to try again". **Never free**: § 3.4 pins it
  /// to `reason.isRetriable`, and one test asserts they never disagree.
  final bool retriable;
}

/// Read, but there is genuinely nothing — distinct from failure, and only
/// available where the site supplies its own empty-result signal.
final class BrowseEmpty<T> extends BrowseOutcome<T> {
  const BrowseEmpty({required this.siteSuppliedSignal});

  /// **Non-nullable, deliberately.** `BrowseEmpty` exists *only* where the site
  /// provides the signal, so an empty outcome with no signal is not a fourth
  /// state to represent — it is a bug in the caller, and `architecture.md` § 2.2
  /// says so in as many words.
  final String siteSuppliedSignal;
}
```

```dart
// lib/domain/sources/read_attempt.dart
import 'package:lumen_tale/core/network/fetch_result.dart';

/// What was being read when the read failed. `source-unavailable.md` § 8 names
/// this field `whatWasBeingRead`, and its four values are the four it lists.
/// `searchResults` is a fifth, required by B50: a source that declares search
/// and then returns nothing is a broken source, and it needs its own evidence.
enum ReadStage {
  catalogue,
  genreListing,
  novelDetails,
  chapterList,
  chapterContent,
  searchResults,
}

/// What zero items means for a given stage. **Declared by the source that made
/// the request** — B41: the platform never interprets a source's values, and a
/// stage's legitimate zero is a property of the site, not of the app.
enum ZeroItemsPolicy {
  /// The site can legitimately publish nothing here. `browse-genre.md` § 4
  /// "Empty — no data" is this case: FanMTL's tag index read cleanly and held
  /// no tag.
  zeroIsGenuine,

  /// Zero here is a suspected break, never an answer. B22's second arm, E8.
  zeroIsBroken,
}

/// The default policy per stage. **The source overrides it per call**, by
/// passing a [ReadAttempt] with its own `zeroItemsPolicy`; this table is the
/// default a stage gets if a caller forgets, and it is the conservative
/// direction on every stage where the two differ.
const Map<ReadStage, ZeroItemsPolicy> kZeroItemsPolicyByStage =
    <ReadStage, ZeroItemsPolicy>{
      // "Empty — no data" in browse-genre.md: a real state, rendered as
      // EmptyState, explicitly "not an error, and not a broken source".
      ReadStage.genreListing: ZeroItemsPolicy.zeroIsGenuine,
      // Every remaining stage. B22: the discriminator is the site's own signal,
      // "never the absence of a match" — so with no signal, zero cannot be
      // shown to mean "genuinely nothing" and is reported instead.
      ReadStage.catalogue: ZeroItemsPolicy.zeroIsBroken,
      ReadStage.novelDetails: ZeroItemsPolicy.zeroIsBroken,
      ReadStage.chapterList: ZeroItemsPolicy.zeroIsBroken,
      ReadStage.chapterContent: ZeroItemsPolicy.zeroIsBroken,
      ReadStage.searchResults: ZeroItemsPolicy.zeroIsBroken,
    };

/// What the source's own selectors found in the body.
///
/// Produced by a source (`03-source-system.md` rule 12: parsing unit tests
/// ship with fixture HTML), never by this foundation: the foundation has no
/// selector and must not grow one.
sealed class ContentProbe {
  const ContentProbe();
}

/// The elements the source expected were present. [itemCount] is how many were
/// found; for a single article node the probe reports `1`, because the container
/// *is* the element being looked for.
final class ExpectedContentFound extends ContentProbe {
  const ExpectedContentFound(this.itemCount);

  final int itemCount;
}

/// The body parsed, and none of the expected elements were in it.
///
/// **E4, E8, SC-6.** This is the shape `fanmtl-broken-layout.html` produces: a
/// well-formed page, HTTP 200, non-empty, and nothing the app looks for.
final class ExpectedContentAbsent extends ContentProbe {
  const ExpectedContentAbsent();
}

/// The body could not be turned into elements at all. B22's "a parse error".
final class ParseBroke extends ContentProbe {
  const ParseBroke();
}

/// Everything the classifieur is allowed to look at, and nothing else.
///
/// One object, four fields, each one documented. A classifieur that needed a
/// fifth fact would need a fifth field here, which is the point: the inputs are
/// enumerable.
final class ReadAttempt {
  const ReadAttempt({
    required this.stage,
    required this.fetch,
    required this.content,
    this.siteEmptySignal,
    this.zeroItemsPolicy,
    this.expectedSelector,
    this.requestPath,
  });

  final ReadStage stage;

  /// What the transport did — **the discriminator, not the response**.
  ///
  /// `http-client` § 2.2 hands the caller an `HttpResponse` whose `.outcome` is
  /// this value and whose `.body` is the page. The classifieur is given **only**
  /// the first: what it judges is never the body, and the body never reaches it.
  /// A source reads the body itself, probes it with its own selectors, and puts
  /// the verdict in [content].
  final FetchResult fetch;

  /// What the source's selectors found. `null` only when the transport produced
  /// no body to parse — which never happens on a 2xx, and which § 3.1 treats as
  /// a parse failure rather than as an absence.
  final ContentProbe? content;

  /// **The site's own explicit empty-result marker, verbatim, or `null`.**
  ///
  /// The single most important field in this file. B22: "The discriminator is
  /// the site's own empty-result signal, never the absence of a match."
  /// `18-external-contracts.md` § FanMTL point 7 records the marker for FanMTL
  /// (`No relevant content found`) **and** records that it lives on the search
  /// failure page, so it discriminates for search calls only.
  ///
  /// The *source* decides whether a marker is present, because only the source
  /// knows its own site's wording — B41 again.
  final String? siteEmptySignal;

  /// Overrides [kZeroItemsPolicyByStage] for this call. `null` = use the table.
  final ZeroItemsPolicy? zeroItemsPolicy;

  /// The selector the source used, echoed into the failure's evidence so the
  /// owner can read it against the fixture. Required by `SourceLayoutChanged`.
  final String? expectedSelector;

  /// The site-relative request path, for `ParseFailed`. Never absolute, never
  /// carrying a reader-supplied query (C5, and the log rule in § 4.4 below).
  final String? requestPath;
}
```

```dart
// lib/domain/sources/outcome_discriminator.dart
import 'package:lumen_tale/core/error/source_failure.dart';
import 'package:lumen_tale/core/network/fetch_result.dart';
import 'package:lumen_tale/domain/sources/browse_outcome.dart';
import 'package:lumen_tale/domain/sources/read_attempt.dart';

/// Keeps four outcomes apart. `architecture.md` § 2.2: "The single most
/// load-bearing foundation, and the one that cannot be built from a library."
///
/// **A pure function.** No cache, no clock, no I/O, no field. Two calls for two
/// different sites share nothing, which is B23's first clause expressed as a
/// property of the code rather than as a promise.
final class OutcomeDiscriminator {
  const OutcomeDiscriminator();

  /// The single decision. Every branch is in § 3; there are nine, and all nine
  /// return — none of them falls through, and none of them throws.
  BrowseOutcome<T> classify<T>(ReadAttempt attempt) {
    final policy = attempt.zeroItemsPolicy ??
        kZeroItemsPolicyByStage[attempt.stage] ??
        ZeroItemsPolicy.zeroIsBroken;
    ...
  }
}
```

### 2.3 Contrats API

**Aucun appel sortant.** Cette fondation ne parle à aucun site : elle classe ce
qu'une couche de transport lui a déjà remis. Le premier producteur réel de
`FetchResult` est `core/network`, et cette couche **a un propriétaire** :
`http-client`, vague **0** (voir § 8).

Ce qui est promis à l'appelant :

```dart
// Signatures, pas implémentation. Une source les implémente (§ 2.2 de 2-1).
Future<BrowseOutcome<NovelsPage>> getPopularNovels(int page);
Future<BrowseOutcome<List<Chapter>>> getChapterList(Novel novel);
Future<BrowseOutcome<String>> fetchChapterContent(Chapter chapter);
```

---

## 3. Algorithmes critiques

### 3.1 Le classifieur, les quatre bras (couvre **B22**, **E4**, **E5**, **E8**, **E19**)

```
classify(attempt) -> BrowseOutcome<T>:

  # ── BRAS 1 : aucun transport ───────────────────────────────────────────
  switch attempt.fetch:
    FetchTransportFailed(host):
      # E5. « No connection » est une CAUSE, pas une page vide.
      # ⚠️ Ce n'est PAS BrowseSucceeded(items: []) : une liste vide affirme
      #    « le site n'a rien », une exception affirme « on n'a pas su ».
      return BrowseFailed(NoConnection(host: host), retriable: true)

    FetchRateLimited(retryAfter, status):
      # 17-security.md règle 6. Retry-After est honoré, jamais deviné.
      return BrowseFailed(RateLimited(retryAfter: retryAfter), retriable: true)

    FetchSucceeded(status):
      pass    # le statut est examiné plus bas, dans le même bras

  # ── BRAS 2 : un statut qui n'est pas un succès ──────────────────────────
  status = attempt.fetch.status
  if status < 200 or status >= 300:
    # B22 : « a non-success status → the site could not be read ».
    # source-unavailable.md : cause `site_unavailable`, preuve « {source}
    # answered HTTP {status}. », et un compte à rebours de 60 s avant le
    # réessai — c'est la seule cause qui en porte un.
    return BrowseFailed(
      SourceUnavailable(status: status),
      retriable: true,
    )

  # ── BRAS 3 : la réponse est un succès, mais le corps n'a pas survécu ───
  if attempt.content is ParseBroke:
    # B22 : « a parse error → the site could not be read ».
    return BrowseFailed(
      ParseFailed(path: attempt.requestPath ?? ''),
      retriable: false,       # architecture.md § 5.2 : « no | report the bug »
    )

  if attempt.content is null:
    # Un 2xx sans corps analysable. Inatteignable en pratique, et traité comme
    # une panne de lecture plutôt que comme une absence : un `null` ici ne
    # doit JAMAIS se dégénérer en « aucun résultat ».
    return BrowseFailed(
      ParseFailed(path: attempt.requestPath ?? ''),
      retriable: false,
    )

  # ── BRAS 4 : le corps est exploitable ───────────────────────────────────
  if attempt.content is ExpectedContentAbsent:
    # E4 / E8 / SC-6. La page a répondu 200, s'est analysée, et ne contient
    # aucun des éléments attendus. Le signal du site est CONSERVÉ s'il y en
    # avait un — c'est lui qui explique au lecteur pourquoi la page est vide.
    return BrowseFailed(
      SourceLayoutChanged(
        failedSelector: attempt.expectedSelector ?? '(non déclaré)',
        status: status,
        siteSuppliedSignal: attempt.siteEmptySignal,
      ),
      retriable: false,
    )

  # Attempt.content is ExpectedContentFound(itemCount: N)
  count = attempt.content.itemCount

  # ── ORDRE DES TROIS VERDITS, et il est fixe ────────────────────────────
  # 1. le signal du site d'abord. B22, texte exact : « the response parsed
  #    successfully AND carries the site's own explicit empty-result signal →
  #    genuine nothing ».
  if attempt.siteEmptySignal != null:
    return BrowseEmpty(siteSuppliedSignal: attempt.siteEmptySignal!)

  # 2. ensuite le compte. Un site intact avec des entrées est un succès.
  if count > 0:
    return BrowseSucceeded(items)          # `items` est fourni par l'appelant

  # 3. enfin, et seulement enfin, zéro.
  if policy == ZeroItemsPolicy.zeroIsGenuine:
    # La seule façon d'obtenir un BrowseSucceeded(items: []) : le site a été
    # lu, il est intact, et il n'a rien. C'est l'état à deux issues que
    # architecture.md § 2.2 décrit pour une source sans signal.
    return BrowseSucceeded(List<T>.unmodifiable(const []))

  return BrowseFailed(
    SourceLayoutChanged(
      failedSelector: attempt.expectedSelector ?? '(non déclaré)',
      status: status,
      siteSuppliedSignal: null,
    ),
    retriable: false,
  )
```

**Les neuf branches, toutes explicites :**

| # | Situation | Issue | Type | Cause | Rejouable |
|---|---|---|---|---|---|
| 1 | Aucune connexion (E5) | `BrowseFailed` | — | `NoConnection(host)` | oui |
| 2 | 429 / `Retry-After` | `BrowseFailed` | — | `RateLimited(retryAfter)` | oui |
| 3 | statut ∉ [200, 300) | `BrowseFailed` | — | `SourceUnavailable(status)` | oui |
| 4 | 2xx + `ParseBroke` | `BrowseFailed` | — | `ParseFailed(path)` | **non** |
| 5 | 2xx + `content == null` | `BrowseFailed` | — | `ParseFailed(path)` | **non** |
| 6 | 2xx + `ExpectedContentAbsent` (E4, E8, SC-6) | `BrowseFailed` | — | `SourceLayoutChanged(selector, status, signal?)` | **non** |
| 7 | 2xx + trouvé + **signal du site** (E19) | **`BrowseEmpty`** | — | — | — |
| 8 | 2xx + trouvé + `count > 0` | **`BrowseSucceeded`** | — | — | — |
| 9a | 2xx + trouvé + `count == 0` + politique « zéro authentique » | **`BrowseSucceeded([])`** | — | — | — |
| 9b | 2xx + trouvé + `count == 0` + politique « zéro cassé » | `BrowseFailed` | — | `SourceLayoutChanged(...)` | **non** |

### 3.2 Pourquoi l'ordre des trois verdits est fixe (couvre **B22**)

Le signal du site l'emporte sur le compte, et le compte l'emporte sur zéro. Deux
conséquences qu'un test doit épingler :

```
signal présent ET count = 12   -> BrowseEmpty   (pas BrowseSucceeded)
count = 12 ET signal absent    -> BrowseSucceeded(12)
count = 0  ET signal absent    -> 9a ou 9b, selon la politique
```

Le premier cas est celui qu'un implémentateur intuitive écrirait à l'envers. Un
site peut porter son propre marqueur « rien trouvé » **sur une page qui contient
des résultats** — c'est un pied de page, pas un verdict. Traiter la présence de
la chaîne comme une preuve d'emptiness produirait un « aucun résultat » sur une
page pleine, ce qui est le défaut miroir de SC-6.

### 3.3 La politique de zéro, et d'où vient la valeur (couvre **B50**, **E8**)

```
kZeroItemsPolicyByStage (défaut, § 2.2) :
  genreListing  -> zeroIsGenuine
  tout le reste -> zeroIsBroken

une source peut surcharger par appel :
  attempt.zeroItemsPolicy != null  ->  celui-là gagne
```

La table par défaut est conservatrice (`zeroIsBroken`) partout où les deux
diffèrent, parce que le coût d'une erreur est asymétrique : rapporter une page
vraiment vide comme cassée fait perdre au lecteur une liste, alors que l'inverse
lui fait croire qu'un site mort n'a rien — ce que B22 et SC-6 interdisent
expressément.

**Le seul `zeroIsGenuine` par défaut est `genreListing`**, parce que
`browse-genre.md` § 4 le spécifie : *« The source declares no genres at all —
`filterList` is empty. A real state, not an error, and not a broken source »*.

### 3.4 `retriable` n'est jamais libre (couvre **B24**)

```
BrowseFailed(reason, retriable: …)

# ⚠️ Le champ existe parce que architecture.md § 2.2 le déclare. Il n'est
#    PAS une seconde source de vérité. Règle : retriable == reason.isRetriable,
#    toujours. Un test l'affirme sur les six causes.

isRetriable :
  NoConnection          -> true
  RateLimited           -> true
  SourceUnavailable     -> true
  SourceLayoutChanged   -> false
  ParseFailed           -> false
  ItemRemovedAtSource   -> false
```

Et le corollaire côté écran, qui appartient à `3-1` mais que cette fondation
rend possible : `source-unavailable.md` § 2.1 — *« a cause whose correct action
is "nothing" gets no retry button »*. `ItemRemovedAtSource` et
`SourceLayoutChanged` n'ont donc **aucun** bouton `Réessayer`, et non un bouton
désactivé.

### 3.5 Piège de cohérence : la fixture fabriquée (couvre **E4**, **E8**, SC-6)

`0-1` produit `<fixtures>/fanmtl-broken-layout.html`. Cette fondation le consomme
**sans sélecteur** — elle n'en a pas, et c'est `2-1` qui en a un. Ce que la
fondation peut et doit vérifier sur le fichier lui-même :

```
le test lit test/fixtures/sources/fanmtl/fanmtl-broken-layout.html :
  1. le fichier existe                              # sinon 0-1 n'a pas été fait
  2. il s'analyse : package:html le parse sans erreur
  3. son texte n'est pas vide — c'est une page, pas un trou
  4. il NE CONTIENT PAS la chaîne "No relevant content found"
       # 18-external-contracts.md point 7 : le signal du site est ailleurs.
       # Donc quelle que soit la sonde de la source, cette page ne peut
       # JAMAIS atteindre BrowseEmpty.
  5. avec une sonde ExpectedContentAbsent  -> branche 6, SourceLayoutChanged
  6. avec une sonde ExpectedContentFound(0) -> branche 9b, SourceLayoutChanged
  7. avec une sonde ExpectedContentFound(0) ET un signal forgé
       -> branche 7, BrowseEmpty
       # … et c'est la seule façon d'obtenir BrowseEmpty sur cette page.
       # Les 7 états sont donc distincts sur la MÊME fixture, sans réseau.
```

Les points 5, 6 et 7 sont le cœur du test : **trois issues différentes à partir
d'une seule page**, ce qui est exactement ce que SC-6 exige.

### 3.6 Ce que la fondation ne fait pas, et pourquoi

```
NE FAIT PAS                          POURQUOI
──────────────                       ────────
aucune écriture en base              § 2.1 : rien n'est stocké. Les causes déjà
                                     vues vivent dans sources.last_error_code et
                                     queue_items.error_code, écrits par 6-4 et 5-3
aucune translation de cause en texte l'écran écrit (B28) ; une cause est un
                                     fait, pas une phrase
aucun sélecteur CSS                  une source en a ; la fondation n'en a pas,
                                     et lui en donner un la ferait dépendre
                                     d'un site
aucun cache, aucun champ             B23 : deux sites ne doivent rien partager
aucun jeton, aucun logger            B29 / C2 : rien ne sort, rien ne se
                                     journalise ; 17-security.md règle 8
aucune horloge                        B48/B49 : un « dernier passage » se lit
                                     dans la colonne, il ne se calcule pas ici
```

---

## 4. Plan composants

### 4.1 Arbre de composants

```
Aucun composant d'interface. Cette fondation produit **quatre** fichiers Dart purs
et leurs tests — `FetchResult` n'en fait pas partie, il est écrit par
`http-client` (§ 2.2, § 8). Le premier écran qui les consomme est `3-1`
(`/browse/:sourceId/unavailable`).

SourceFailure (sealed)                    lib/core/error/source_failure.dart
├── NoConnection          { host, isRetriable }
├── RateLimited           { retryAfter, isRetriable }
├── SourceLayoutChanged   { failedSelector, status, siteEmptySignal, isRetriable }
├── SourceUnavailable     { status, isChallenge, isRetriable }
├── ItemRemovedAtSource   { itemId, status, isRetriable }
└── ParseFailed           { path, isRetriable }

FetchResult (sealed)                      lib/core/network/fetch_result.dart
                                          ⚠️ DÉFINI PAR http-client (vague 0) —
                                          cette fondation l'importe et n'y
                                          ajoute rien (§ 2.2, § 8)
├── FetchSucceeded        { status }
├── FetchTransportFailed  { host }
└── FetchRateLimited      { retryAfter, status }

BrowseOutcome<T> (sealed)                 lib/domain/sources/browse_outcome.dart
├── BrowseSucceeded<T>    { items }              liste non modifiable
├── BrowseFailed<T>       { reason, retriable }  retriable == reason.isRetriable
└── BrowseEmpty<T>        { siteSuppliedSignal } jamais null

ContentProbe (sealed) + ReadAttempt        lib/domain/sources/read_attempt.dart
└── ReadStage · ZeroItemsPolicy · kZeroItemsPolicyByStage

OutcomeDiscriminator                       lib/domain/sources/outcome_discriminator.dart
└── classify<T>(ReadAttempt) -> BrowseOutcome<T>
```

### 4.2 Composants

| Composant | Type | Fichier cible | Props | State | Événements |
|---|---|---|---|---|---|
| `SourceFailure` + 6 | hiérarchie `sealed` | `lib/core/error/source_failure.dart` | — | aucun | — |
| `FetchResult` + 3 | hiérarchie `sealed` — **écrite par `http-client`**, importée ici | `lib/core/network/fetch_result.dart` | — | aucun | — |
| `BrowseOutcome` + 3 | hiérarchie `sealed` | `lib/domain/sources/browse_outcome.dart` | — | aucun | — |
| `ContentProbe` + 3 | hiérarchie `sealed` | `lib/domain/sources/read_attempt.dart` | — | aucun | — |
| `ReadStage`, `ZeroItemsPolicy` | `enum` | idem | — | aucun | — |
| `kZeroItemsPolicyByStage` | `const Map` | idem | — | aucun | — |
| `ReadAttempt` | valeur immuable | idem | 7 champs nommés | aucun | — |
| `OutcomeDiscriminator` | classe finale, `const` | `lib/domain/sources/outcome_discriminator.dart` | — | aucun | — |

**Riverpod** (`05-state-management.md`) : cette fondation n'expose **aucun
provider**, et c'est délibéré. Une fonction pure ne possède rien à reconstruire
quand un provider change, et un provider de classification serait un singleton
sans état observable — le même motif que `2-3` § 4.2 pour le stockage. La
persistance d'une cause déjà vue (`sources.lastErrorCode`) appartient à `6-4`,
et sa lecture à `3-1`.

### 4.3 États par écran

**Aucun.** Aucun écran n'est produit ni modifié. `source-unavailable.md` est
entièrement le fait de `3-1` ; cette fondation lui fournit la grille de décision
que § 4 de cet écran décrit ligne par ligne.

### 4.4 Formulaires

Aucun. Aucun champ, aucun bouton, aucune permission.

---

## 5. Gestion d'état (state management)

| Donnée | Portée | Stockage | Initialisation | Mise à jour |
|---|---|---|---|---|
| Issue d'une lecture | appel | `BrowseOutcome<T>` en mémoire,Returned | le `classify` | jamais |
| Cause d'un échec | appel | `SourceFailure` en mémoire | le `classify` | jamais |
| Signal du site d'un vide | appel | `ReadAttempt.siteEmptySignal` | la source | jamais |
| Cause déjà vue par source | base | `sources.last_error_code` (`TEXT`, nom du cas) | **par `6-4`** | **par `6-4`** |
| Cause déjà vue par élément de file | base | `queue_items.error_code` | **par `5-3`** | **par `5-3`** |

**Ce qui n'est délibérément pas de l'état** : un historique des échecs. La
question « ce site a-t-il déjà cassé ? » a déjà une réponse dans
`sources.last_error_code` et dans `lastCheckedAt`, tous deux posés par `6-4`. Une
liste d'échecs dans la fondation serait une deuxième source de vérité, libre de
diverger de la ligne qu'elle décrit — le même défaut que la colonne
`unreadCount` que B48 a interdite.

**Ce qui n'est pas de l'état non plus** : le statut de la connexion. `classify`
n'en prend pas, et § 3.1 n'en a pas besoin : une absence de connexion arrive
déjà sous la forme `FetchTransportFailed`, parce que c'est le transport qui la
constate, pas la fondation.

---

## 6. Traçabilité des règles

### 6.1 Règles métier (B*)

| ID | Règle (PRD) | Implémentée où | Approche |
|---|---|---|---|
| **B22** | When a site cannot be read the app states that it could not read it, and never presents an empty list as an answer. **"Could not read" and "genuinely nothing" are distinguished like this:** the response parsed successfully AND carries the site's own explicit empty-result signal → genuine nothing, shown as a clear "no results". A successful response whose expected content elements are simply absent, a parse error, or a non-success status → the site could not be read, reported as a failure with a retry. **The discriminator is the site's own empty-result signal, never the absence of a match.** | `OutcomeDiscriminator.classify` § 3.1, § 3.2, § 3.3 | Trois types, jamais deux : `BrowseSucceeded` / `BrowseEmpty` / `BrowseFailed`. Le discriminant est `ReadAttempt.siteEmptySignal` **et rien d'autre** ; l'absence d'éléments est la branche 6, jamais une liste vide. L'ordre des trois verdits est fixé par § 3.2 et épinglé par un test |
| **B23** | A failure on one site never blocks the other sites, and never makes stored chapters unreadable. If a site becomes unreachable, changes, or is removed from the app entirely, the chapters already downloaded stay readable on the phone, and the other sites carry on working. | § 3.1 (retourner et non lever), § 3.6 (aucun état partagé), § 4.1 | `classify` est une fonction **pure** : ni cache, ni champ, ni horloge, ni I/O. Deux sites ne partagent donc rien, et les fichiers de chapitres restent hors de ce fichier. Un test appelle `classify` deux fois sur deux `ReadAttempt` distincts et affirme l'absence de contamination |
| **B24** | Any action that can fail shows an error the user can read and act on, together with a way to try again. No action fails silently to a blank screen or a silent spinner. | `BrowseFailed.reason` typé + `retriable` (§ 3.4) | `reason` est un `SourceFailure`, jamais un `String` (`architecture.md` § 5.2). `retriable` est **épinglé** à `reason.isRetriable` par un test, donc un écran ne peut pas inventer un réessai pour une cause qui n'en a pas. Aucune branche de `classify` ne retourne sans issue — un `switch` à neuf bras dont aucun ne tombe |

### 6.2 Edge cases (E*)

| ID | Cas (PRD) | Approche de gestion | Où |
|---|---|---|---|
| **E4** | Site layout changed between releases → l'app détecte et rapporte « this site could not be read » ; jamais un catalogue vide | Branche 6 : `ExpectedContentAbsent` sur un 2xx → `SourceLayoutChanged`, `retriable: false`. Testé contre `fanmtl-broken-layout.html` (§ 3.5) | § 3.1 branche 6 ; `2-1` § 3 pour la sonde |
| **E5** | No connection while browsing or searching → un message « no connection » avec un réessai ; bibliothèque et chapitres stockés restent utilisables | Branche 1 : `FetchTransportFailed` → `NoConnection(host)`, `retriable: true`. **Ce n'est pas une page vide** : la cause existe pour que l'écran puisse dire « le téléphone n'a pas de connexion », pas « le site n'a rien » | § 3.1 branche 1 ; `source-unavailable.md` § 5 |
| **E8** | A site returns nothing where content is expected → traité comme une rupture suspecte, **pas** comme « no results », rapporté comme un échec | Branches 6 et 9b. La branche 9b existe précisément pour le cas « le conteneur est trouvé mais il est vide » : sans signal du site, B22 interdit d'en déduire « genuinely nothing » | § 3.1 branches 6 et 9b ; § 3.3 |
| **E9** | A followed novel disappears from its site → en ligne, l'app dit que le roman n'est plus disponible ; **hors ligne, elle ne prétend rien du site**, seulement ce qui est stocké ; les chapitres restent lisibles | La cause existe (`ItemRemovedAtSource`, `retriable: false`) mais **elle n'est produite que par `6-4`**, qui a la réponse du site. Cette fondation ne fabrique jamais cette cause : elle ne connaît pas la réponse du site. Le compte local est hors de sa portée par construction | § 2.2 (`ItemRemovedAtSource`) ; producteur : `6-4` |
| **E18** | A chapter page contains no real text → sous le seuil de 100 caractères, **pas stocké comme complet**, rapporté comme un échec avec réessai | La fondation ne compte pas les caractères : c'est `2-2`, qui produit le texte, qui applique le seuil. Ce que la fondation garantit, c'est la branche qui accueille ce verdict : `ExpectedContentFound(0)` + politique `zeroIsBroken` sur `chapterContent` → `BrowseFailed(SourceLayoutChanged)` | § 2.2 `kZeroItemsPolicyByStage` ; `2-2` § 3.5 |
| **E19** | A search genuinely matches nothing → un message « no results » explicite, **visiblement distinct** d'un message d'échec | Branche 7 : `siteEmptySignal != null` → `BrowseEmpty`, quel que soit le compte. La distinction est **structurelle** : `BrowseEmpty` n'a pas de `reason`, n'a pas de `retriable`, et ne peut pas être rendu par le composant d'erreur | § 3.1 branche 7 ; § 3.2 |

### 6.3 Contraintes (C*)

| ID | Contrainte (PRD) | Comment elle est respectée |
|---|---|---|
| **C2** | Privacy — aucun compte, aucun serveur, aucune télémétrie | Aucun appel sortant dans cette fondation. Aucun identifiant d'appareil, aucun contenu de chapitre, aucune requête de lecteur ne franchit cette frontière |
| **C5** | User skill — le seul utilisateur technique ne sait pas écrire de code | La cause est typée et non traduite : le lecteur ne reçoit pas une trace d'exception, il reçoit un fait que l'écran met en mots en français et en anglais (B28) |
| **C6** | No server, no support, no telemetry → l'app n'a aucun moyen d'apprendre pourquoi elle a échoué ; les échecs doivent être reconnaissables **sur l'appareil** et signalés là | `SourceLayoutChanged.failedSelector` et `ParseFailed.path` portent la preuve. C'est ce qui permet la ligne `HTTP 200 · 0 élément attendu trouvé` de `source-unavailable.md` § 8, et donc la phrase que le lecteur dicte à son voisin (C12) |
| **C7** | Source reliability — les sites changent leurs pages sans prévenir ; **l'app qui ne renvoie silencieusement rien est le mode de panne principal à éviter** | La branche 6 est le cœur : un 200 sans éléments attendus ne peut pas produire de liste vide. `18-external-contracts.md` : *« Treat 'the source returned an empty list' as a suspected layout change before treating it as 'no results exist' »* |
| **C11** | Usage context — lecture à une main, sur un téléphone, souvent sans réseau | Aucune consequence : cette fondation ne produit aucune interface. La contrainte est satisfaite par `3-1` |
| **C12** | Privacy of failure reporting — un lecteur emprunteur doit pouvoir décrire l'échec **en mots** | La cause est un fait structuré, donc l'écran peut écrire une phrase complète et non un code. `source-unavailable.md` § 4.1 exige que `HTTP 429` **ne soit pas traduit** : la cause le rend disponible tel quel |

---

## 7. Pièges à éviter

- **⚠️ Ne pas écrire `lib/core/network/fetch_result.dart` depuis cette
  fondation.** Le comportement correct (dépendance, `state.json`
  `depends_on`) est : `http-client` le définit en vague 0, et cette fondation
  fait `import 'package:lumen_tale/core/network/fetch_result.dart';` sans y
  toucher. Le fondement est qu'un producteur qui écrit le type de son propre
  consommateur a une dépendance inversée : `failure-discriminator` est vague 2,
  `http-client` vague 0, donc le second doit exister avant le premier. Deux
  fichiers pour un seul type donneraient deux réponses à « qu'est-ce que le
  transport a fait ? », et c'est la même faute que la taxonomie en deux endroits.
- **⚠️ Ne pas demander au classifieur de juger un corps qu'il n'a pas.** Le
  comportement correct (`http-client` § 2.2) est que la source analyse la page
  elle-même — `parseDocument(response.body)` — et rend `ContentProbe`.
  `ReadAttempt.fetch` est le **discriminant** ; un `ReadAttempt` qui porterait un
  corps ferait de la fondation une seconde source de vérité sur le HTML du site,
  et le classifieur commencerait à décider de ce qu'il ne peut pas voir.
- **⚠️ Ne pas renvoyer `BrowseSucceeded(items: [])` quand une exception a été
  levée.** Le comportement correct (**B22**) est `BrowseFailed(NoConnection(host))`.
  Une liste vide est une **affirmation** — elle dit « le site n'a rien » — et une
  exception dit « on n'a pas su ». Renvoyer la première quand la seconde est
  arrivée est précisément le défaut que SC-6 existe pour attraper.
- **⚠️ Ne pas décider « vide » par l'absence de correspondance.** Le comportement
  correct (**B22**) est de décider par `ReadAttempt.siteEmptySignal` et par rien
  d'autre. Zéro résultat sans signal passe par la branche 9b et devient un
  `SourceLayoutChanged`, pas une page vide.
- **⚠️ Ne pas mettre une `String` dans `reason`.** Le comportement correct
  (**B24**, `architecture.md` § 5.2) est un `SourceFailure` typé. Un `reason`
  textuel est le « errorCode free-text field the platform interprets » que § 5.2
  interdit nommément, et il rend `isRetriable` indécidable.
- **⚠️ Ne pas laisser `retriable` libre sur `BrowseFailed`.** Le comportement
  correct (**B24**) est `retriable == reason.isRetriable`. Un écran qui décide
  seul réessaie sur une cause sans issue, et l'offre alors un bouton qui ne peut
  rien réparer.
- **⚠️ Ne pas laisser une exception traverser `classify`.** Le comportement
  correct (**B23**) est de la **retourner**. Une source qui plante ne doit pas
  empêcher l'autre source de s'afficher, et une exception qui remonte à l'appelant
  le transforme en écran vide.
- **⚠️ Ne pas laisser `BrowseEmpty.siteSuppliedSignal` nullable.** Le comportement
  correct (`architecture.md` § 2.2) est un `String` non nul : un vide sans
  signal du site n'est pas un troisième état à représenter, c'est une absence de
  discriminant qui doit remonter en branche 9b.
- **⚠️ Ne pas mettre `StorageFull` dans `SourceFailure`.** Le comportement
  correct (`architecture.md` § 5.2) est qu'il n'en fait pas partie : la taxonomie
  du § 5.2 est celle de `core/error` dans son ensemble, et `StorageFull` est une
  cause d'écriture, pas de lecture. Elle appartient à `5-3` et ne doit jamais
  apparaître dans un `BrowseFailed`.
- **⚠️ Ne pas ajouter un sélecteur CSS à cette fondation.** Le comportement
  correct (`architecture.md` § 2.2, `03-source-system.md` règle 12) est que les
  sélecteurs appartiennent aux sources. Une fondation qui connaît `.chapter-content`
  devient dépendante d'un site, et la fixture fabriquée cesse d'être un test
  générique.
- **⚠️ Ne pas mettre `fanmtl-broken-layout.html` dans `lib/`.** Le comportement
  correct (`10-testing.md` règle 5) est `test/fixtures/sources/fanmtl/`. Une
  fixture en production est une page de site copiée dans l'APK, ce que B29 et C4
  interdisent.
- **⚠️ Ne pas mettre une horloge, un cache ou un logger dans cette fondation.**
  Le comportement correct (**B23**, **B29**) est une fonction pure. Une cache
  ferait dépendre le verdict d'un état partagé entre deux sites, et un logger
  créerait le seul endroit du produit d'où une cause pourrait sortir.

**Trois questions, dont deux ouvertes. Elles ne sont pas des détails
d'implémentation, et les deux ouvertes ne sont pas tranchées ici.**

1. **`core/network` n'a aucune slice qui le possède — résolue, et la résolution
   change ce que cette fondation écrit.** `state.json` range `http-client` parmi
   les fondations, vague **0** : elle possède `lib/core/network/` en entier,
   **y compris `lib/core/network/fetch_result.dart`**. Cette fondation définit
   le vocabulaire qui **classe** — `BrowseOutcome`, `ReadAttempt`,
   `ContentProbe`, `OutcomeDiscriminator`, `SourceFailure` — et **importe** le
   discriminant du transport. Elle ne construit pas la couche de transport, et
   elle n'écrit plus le type qu'elle consomme. Voir § 2.2 et § 8.
2. **`architecture.md` § 2.2 dit « trois états », et § 5.1 montre quatre
   méthodes qui renvoient `NovelsPage` et non `BrowseOutcome<NovelsPage>`.** La
   prose de § 5.1 est explicite (« Every one of these returns `BrowseOutcome<T>`
   … That is the contract-level expression of B22 ») et B22 est SC-6 ; le bloc de
   code de § 5.1 n'est pas à jour. `2-1` suit la prose et enveloppe les quatre.
   **Question ouverte** : le bloc de code de `architecture.md` § 5.1 doit-il être
   corrigé ? Un amendement `state.js amend` l'inscrirait dans § 9 ; ce plan ne le
   fait pas et ne le doit pas.
3. **B22 écrit « never presents an empty list as an answer », et
   `architecture.md` § 2.2 accorde à une source sans signal « two states ».** La
   branche 9a produit donc `BrowseSucceeded(items: [])`, ce que la lettre de B22
   interdit et que § 2.2 autorise explicitement. Ce plan suit § 2.2, parce que
   B22 exige par ailleurs que le discriminant soit **le signal du site**, ce qui
   rend impossible de conclure « rien » sans lui. **Question ouverte** : B22
   doit-il distinguer « jamais de liste vide » de « jamais de liste vide *pour une
   source qui publie un signal* » ?

---

## 8. Dépendances

| Dépend de | Nature | Statut | Fallback si absent |
|---|---|---|---|
| `0-1` | data — la fixture `fanmtl-broken-layout.html` | `identified` | **BLOCK.** § 3.5 ne peut pas s'écrire. Le reste de la fondation est implémentable sans elle |
| `0-2` | data — la réponse mesurée à « FanMTL a-t-il un signal de vide ? » | `identified` | **BLOCK pour `2-1`, pas pour cette fondation.** La fondation implémente les trois états quoi qu'il advienne ; c'est `2-1` qui décide quel `ReadStage` peut atteindre `BrowseEmpty`. **Sans `0-2`, la branche 7 n'est atteignable pour aucune source et `2-1` n'a que deux états** — ce qui est un résultat correct et doit être dit à l'écran, pas un blocage |
| `http-client` | data — **`FetchResult` et ses trois cas**, c'est-à-dire le discriminant que `ReadAttempt` porte et que `classify` examine | `identified`, **vague 0** | **Aucun repli, et il ne doit pas y en avoir.** Le type est écrit **une fois**, à un seul endroit, par le vague 0 — c'est la raison pour laquelle cette fondation est vague 2 et le déclare dans `depends_on`. Si `http-client` n'existe pas encore, `classify` n'est pas implémentable ; mais **écrire `fetch_result.dart` ici ne lève pas le blocage**, cela l'aggrave : un producteur qui écrit le type de son consommateur a une dépendance inversée, donc un cycle, donc deux réponses à « qu'est-ce que le transport a fait ? » |
| `failure-discriminator` lui-même | — | ce plan | `13-error-handling.md` pour la hiérarchie d'exceptions, `architecture.md` § 5.2 pour la liste des causes |
| `package:html` | data — analyzer la fixture dans le test | installé | aucun |

**Dépendants** : `2-1` (l'adaptateur FanMTL, premier producteur de
`ContentProbe`), `3-1` (le catalogue, et SC-6), `6-4` (la vérification manuelle,
qui écrit `sources.lastErrorCode`), `6-1` (Royal Road, qui produit les mêmes
`ContentProbe`).

---

## 9. Checklist de tâches

### Phase 1 — Couche de données

- [ ] Créer `lib/core/error/source_failure.dart` : `SourceFailure` + les six causes, chacune avec son `isRetriable` (§ 2.2)
- [ ] **Ne pas créer** `lib/core/network/fetch_result.dart` : le fichier appartient à `http-client`, vague 0. Cette fondation écrit `import 'package:lumen_tale/core/network/fetch_result.dart';` et c'est tout (§ 2.2, § 7, § 8). Vérifier qu'il n'existe qu'**un seul** `FetchResult` dans `lib/`
- [ ] **Aucun schéma à ajouter.** `sources.lastErrorCode` et `queue_items.errorCode` existent déjà ; cette fondation n'écrit dans aucun (§ 3.6)

### Phase 2 — Logique métier

- [ ] Créer `lib/domain/sources/browse_outcome.dart` : `BrowseOutcome` + `BrowseSucceeded` / `BrowseFailed` / `BrowseEmpty` (§ 2.2)
- [ ] Créer `lib/domain/sources/read_attempt.dart` : `ContentProbe` + `ReadStage` + `ZeroItemsPolicy` + `kZeroItemsPolicyByStage` + `ReadAttempt` (§ 2.2)
- [ ] `OutcomeDiscriminator.classify` — les **neuf** branches de § 3.1, dans l'ordre de § 3.2
- [ ] Épingler `retriable == reason.isRetriable` (§ 3.4)
- [ ] Aucun state, aucun provider, aucun sélecteur, aucune horloge (§ 3.6)

### Phase 3 — Interface utilisateur

- [ ] **Aucun.** Cette fondation ne produit aucun widget, et `source-unavailable.md` — l'écran qui consomme ces quatre issues — appartient entièrement à `3-1`. Ne pas créer le composant d'erreur « par souci de complétude » : `design-system.md` § 2.7 le déclare, et `3-1` l'assemble avec les causes.

### Phase 4 — Intégration

- [ ] Vérifier qu'aucun des **quatre** fichiers n'importe `package:flutter` — `domain` doit rester du Dart pur (`02-architecture.md`)
- [ ] Vérifier que `core/error` **n'importe rien** de `lib/` (c'est un fichier de cette fondation)
- [ ] Aucun routage, aucune permission, aucune migration

### Phase 5 — Tests et polish

- [ ] Tests unitaires (§ 11.1), **les neuf branches**, dont les trois états distincts sur la même fixture (§ 3.5)
- [ ] Test de non-contamination entre deux sources (**B23**)
- [ ] Aucun test d'interface : il n'y a pas d'interface

### Vérifications finales

- [ ] `dart format .` — propre
- [ ] `flutter analyze` — **zéro** issue, zéro `info`
- [ ] `flutter test` — tout passe
- [ ] `coverage-check.js slice /workspaces/lumen_tale failure-discriminator` → **ne vérifie rien pour une fondation** (finding **F-003**) : la relecture humaine de § 6 est le contrôle réel

---

## 10. Critères d'acceptation

- [ ] **B22** — un `ReadAttempt` dont le transport a échoué produit `BrowseFailed`, jamais `BrowseSucceeded`, jamais `BrowseEmpty`, et **aucune exception ne sort de `classify`**.
- [ ] **B22** — `BrowseEmpty` n'est atteignable **que** par `siteEmptySignal != null`. Un test parcourt les six causes et les six combinaisons de compte/signal et affirme que `BrowseEmpty` apparaît dans **une seule** d'entre elles.
- [ ] **B22** — un `ExpectedContentFound(0)` sans signal et avec `zeroIsBroken` produit `SourceLayoutChanged` et **jamais** une liste vide.
- [ ] **B22** — un `ExpectedContentFound(0)` avec signal produit `BrowseEmpty`, et le `siteSuppliedSignal` restitué est **la chaîne du site**, pas un texte de l'app.
- [ ] **B22** — `siteEmptySignal != null` **avec** `count == 12` produit `BrowseEmpty`, pas `BrowseSucceeded(12)` (§ 3.2).
- [ ] **B22** — un statut ∉ [200, 300) produit `SourceUnavailable(status)`, y compris 404 et 503, et **jamais** `BrowseEmpty`.
- [ ] **B22** — `SourceLayoutChanged.failedSelector` est la chaîne du sélecteur passée dans `ReadAttempt.expectedSelector`, et non `'(non déclaré)'` dès que le champ est renseigné.
- [ ] **B23** — `classify` est une fonction pure : deux appels successifs avec deux `ReadAttempt` différents ne partagent aucun état, et l'ordre des appels n'influence aucun résultat.
- [ ] **B23** — aucun des **quatre** fichiers n'a de champ d'instance, de cache, ni de référence à un singleton.
- [ ] **B22 / § 8** — `grep -rn "sealed class FetchResult" lib/` ne renvoie qu'**une** ligne, dans `lib/core/network/fetch_result.dart`. Un second `FetchResult` — écrit ici, ou ailleurs — est un échec, même s'il est identique.
- [ ] **B24** — pour les six causes, `BrowseFailed.reason.isRetriable == BrowseFailed.retriable`, sans exception.
- [ ] **B24** — `SourceLayoutChanged`, `ParseFailed` et `ItemRemovedAtSource` sont `isRetriable == false`, donc aucun écran ne peut leur associer un bouton de réessai.
- [ ] **B24** — les neuf branches de § 3.1 retournent ; il n'existe aucun chemin qui traverse `classify` sans rendre d'issue. Une instruction `final outcome = classify(x); assert(outcome is BrowseSucceeded);` doit compiler sans cast nullable.
- [ ] **C6** — `SourceLayoutChanged` et `ParseFailed` portent la preuve (le sélecteur, le chemin) sans jamais porter une trace d'exception ni le contenu d'une page.
- [ ] **C5** — aucune valeur de `NoConnection.host`, `ItemRemovedAtSource.itemId` ou `ParseFailed.path` n'est un chemin absolu ni une URL complète ; un test l'affirme sur des valeurs représentatives.
- [ ] **C7** — `fanmtl-broken-layout.html` produit `SourceLayoutChanged` avec les **deux** sondes possibles (`ExpectedContentAbsent` et `ExpectedContentFound(0)`).
- [ ] **E4 / E8** — la fixture est bien formée, non vide, et ne contient pas la chaîne `No relevant content found` : les trois assertions sont dans le test, pas dans un commentaire.
- [ ] **E19** — `BrowseEmpty` et `BrowseFailed` n'ont **aucun** membre en commun : un `switch` exhaustif sur `BrowseOutcome<T>` les traite sans qu'un cas soit ambigu, et le compilateur le signale si un bras est ajouté.
- [ ] **B29 / C2** — `grep -rn "print(\|debugPrint(" lib/core/error lib/core/network lib/domain/sources` ne renvoie rien.

---

## 11. Plan de tests

### 11.1 Tests unitaires

Emplacement : `test/domain/sources/outcome_discriminator_test.dart`

| Groupe | Test (nom exact) | Scénario | IDs couverts |
|---|---|---|---|
| Les quatre issues | `une page intacte avec des résultats est un BrowseSucceeded` | `FetchSucceeded(200)`, `ExpectedContentFound(12)`, pas de signal | B22 |
| | `une page 200 dont le conteneur attendu est absent est un SourceLayoutChanged` | `FetchSucceeded(200)`, `ExpectedContentAbsent` | B22, E4, E8 |
| | `une page 200 qui porte le signal du site est un BrowseEmpty` | `FetchSucceeded(200)`, `ExpectedContentFound(0)`, `siteEmptySignal` renseigné | B22, E19 |
| | `une erreur de transport est NoConnection et rejouable` | `FetchTransportFailed(host)` | B22, E5, C6 |
| | `un 429 est RateLimited et rejouable` | `FetchRateLimited(retryAfter: 42s)` | B22, C7 |
| | `un 503 est SourceUnavailable et rejouable` | `FetchSucceeded(503)` | B22 |
| | `un 404 est SourceUnavailable, jamais BrowseEmpty` | `FetchSucceeded(404)` avec un signal forgé | B22 |
| | `un échec d'analyse est ParseFailed et non rejouable` | `FetchSucceeded(200)` + `ParseBroke` | B22, B24 |
| | `un 2xx sans sonde est ParseFailed, jamais une absence` | `FetchSucceeded(200)`, `content: null` | B22 |
| Zéro résultat | `zéro sur un chapitre est SourceLayoutChanged, jamais zéro chapitre` | `ExpectedContentFound(0)`, `chapterContent` | B22, E8, E18 |
| | `zéro sur une liste de chapitres est SourceLayoutChanged` | `ExpectedContentFound(0)`, `chapterList` | B22, E8 |
| | `zéro sur un catalogue est SourceLayoutChanged` | `ExpectedContentFound(0)`, `catalogue` | B22, E8 |
| | `zéro sur un index de genres est un BrowseSucceeded vide` | `ExpectedContentFound(0)`, `genreListing` | `browse-genre.md` § 4 |
| | `une source peut surcharger la politique de zéro par appel` | `zeroItemsPolicy: zeroIsGenuine` sur `catalogue` | B41 |
| Ordre des verdits | `un signal présent avec des résultats gagne sur le compte` | `ExpectedContentFound(12)` **et** signal | B22 |
| | `le compte gagne sur le zéro` | `ExpectedContentFound(12)`, pas de signal | B22 |
| Preuves | `la cause SourceLayoutChanged porte le sélecteur déclaré` | `expectedSelector: '.chapter-content'` | C6 |
| | `la preuve est conservée quand la page portait le signal du site` | `ExpectedContentAbsent` **et** signal | C6, C12 |
| `retriable` | `retriable est toujours la réponse propre à la cause` | les six causes, en boucle | B24 |
| | `aucune cause non rejouable n'est rendue rejouable` | `SourceLayoutChanged`, `ParseFailed`, `ItemRemovedAtSource` | B24 |
| Pureté | `classify ne lève jamais` | chaque entrée invalide de § 3.1 | B24 |
| | `deux sources ne partagent aucun état` | deux appels, ordre inversé, résultats inchangés | B23 |
| | `deux appels identiques rendent le même verdict` | déterminisme | B22 |

Emplacement complémentaire : `test/core/error/source_failure_test.dart`

| Groupe | Test (nom exact) | Scénario | IDs couverts |
|---|---|---|---|
| Causes | `les six causes sont distinctes et sealed` | `switch` exhaustif, aucune absorption | B22 |
| | `un hôte n'est jamais un chemin` | `NoConnection(host: 'www.fanmtl.com')` ne contient ni `/` ni `?` | C5 |
| | `un chemin parse n'est jamais absolu` | `ParseFailed(path: '/novel/ke383028_1.html')` | C5 |

### 11.2 Tests de composants

Aucun. Cette fondation ne produit aucun widget, et un test de widget sur une
fonction pure serait un test qui ne teste rien.

### 11.3 Tests d'intégration

| Flow | Scénario | IDs couverts |
|---|---|---|
| `0-1 → failure-discriminator` | la fixture fabriquée, lue et sondée, donne `SourceLayoutChanged` | B22, E4, E8, SC-6 |
| `failure-discriminator → 2-1` | `FetchResult` + `ContentProbe` réels de FanMTL, `ReadStage` par appel | B22, B41, B50 |
| `failure-discriminator → 3-1` | les quatre issues produisent les quatre rendus de `source-unavailable.md` | B22, B24, C12 |

**Le test de bout en bout de SC-6 appartient à `3-1`**, pas ici : SC-6 se
démontre en regardant l'écran `/browse/:sourceId/unavailable` avec la fixture en
face, et une fondation ne peut pas fournir un écran.

### 11.4 Tests E2E

Aucun pour cette fondation : **Q-008** (un téléphone réel) n'est pas résolu, et un
E2E qui n'a pas pu être exécuté n'est pas un test.

### 11.5 Vérifications manuelles

| Vérification | Écran / Composant | État |
|---|---|---|
| Overflows horizontaux | — | sans objet : pas d'interface |
| Éléments hors écran | — | sans objet |
| Navigation | — | sans objet |
| La fixture est-elle lisible par `package:html` | `test/fixtures/sources/fanmtl/fanmtl-broken-layout.html` | analysée, non vide, sans la chaîne du signal |

---

## Checklist de gate

- [x] Sources explicitement référencées (PRD, architecture, design, conventions, rules).
- [x] Chaque ID B*/E*/C* du périmètre apparaît en § 6 — **B22**, **B23**, **B24**, **E4**, **E5**, **E8**, **E9**, **E18**, **E19**, **C2**, **C5**, **C6**, **C7**, **C11**, **C12**.
- [x] Les contrats de données (§ 2) sont du **vrai Dart**, pas de la prose.
- [x] Les algorithmes (§ 3) sont en pseudocode avec **chaque** branche écrite — les neuf, y compris les trois qui ne peuvent pas se produire.
- [x] La checklist de tâches (§ 9) couvre les cinq phases, en signalant explicitement que la Phase 3 est vide et pourquoi.
- [x] Les critères d'acceptation (§ 10) sont vérifiables individuellement.
- [x] Le plan de tests (§ 11) couvre tous les IDs, et nomme le fichier de test.
- [ ] `coverage-check.js slice` **ne s'applique pas** à une fondation (**F-003**) : `state.json` ne range `failure-discriminator` que dans `foundations`, donc ses `rule_ids` ne sont jamais lus par la garde. La vérification de § 6 est manuelle.

**Statut** : `draft` → en attente de validation.